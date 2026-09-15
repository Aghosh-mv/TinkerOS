#!/usr/bin/env python3
"""
TinkerIA 3B Model Training — CPU Mode
Full fine-tuning with BAdam optimizer on ParcOS training data.
Runs on CPU since GPU is occupied by other training jobs.
"""
import os, sys, json, time, math, random
import torch
import torch.nn as nn
from torch.utils.data import Dataset, DataLoader
from pathlib import Path
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s %(message)s',
    handlers=[logging.FileHandler('/tmp/tinkeria_train.log'), logging.StreamHandler()])
log = logging.getLogger(__name__)

# ── Config ──────────────────────────────────────────────────────────────
MODEL_DIR   = os.path.expanduser('~/models/phi-3.5-mini')
DATA_FILE   = '/home/tinkerspace/linux-kernel/os/parc-ai/model/training_data/wiki_training.jsonl'
DATA_FILE2  = '/home/tinkerspace/linux-kernel/os/parc-ai/model/training_data/merged_all.jsonl'
OUT_DIR     = '/home/tinkerspace/linux-kernel/os/parc-ai/model/checkpoints/tinkeria_3b'
MAX_LEN     = 128       # Reduced for CPU speed + memory
BATCH       = 1
GRAD_ACCUM  = 2         # effective batch = 2 (minimum for gradient checkpointing)
LR          = 5e-5
EPOCHS      = 2
SAVE_EVERY  = 50
LOG_EVERY   = 2

# ── BAdam Optimizer ─────────────────────────────────────────────────────
class BAdam(torch.optim.Optimizer):
    """Block Adam — per-block LR scheduling."""
    def __init__(self, params, lr=2e-5, betas=(0.9, 0.999), eps=1e-8, wd=0.01):
        defaults = dict(lr=lr, betas=betas, eps=eps, weight_decay=wd)
        super().__init__(params, defaults)

    @torch.no_grad()
    def step(self, closure=None):
        loss = closure() if closure else None
        for g in self.param_groups:
            for p in g['params']:
                if p.grad is None: continue
                grad = p.grad
                if grad.is_sparse: raise RuntimeError("BAdam: no sparse")
                s = self.state[p]
                if not s:
                    s['step'] = 0
                    s['exp_avg'] = torch.zeros_like(p)
                    s['exp_avg_sq'] = torch.zeros_like(p)
                exp, sq = s['exp_avg'], s['exp_avg_sq']
                b1, b2 = g['betas']
                s['step'] += 1
                if g['weight_decay'] != 0:
                    grad = grad.add(p, alpha=g['weight_decay'])
                exp.mul_(b1).add_(grad, alpha=1-b1)
                sq.mul_(b2).addcmul_(grad, grad, value=1-b2)
                bc1 = 1 - b1**s['step']
                bc2 = 1 - b2**s['step']
                denom = (sq.sqrt() / math.sqrt(bc2)).add_(g['eps'])
                p.addcdiv_(exp, denom, value=-g['lr']/bc1)
        return loss

# ── Dataset ─────────────────────────────────────────────────────────────
class TextDataset(Dataset):
    def __init__(self, files, tokenizer, max_len):
        self.examples = []
        self.tok = tokenizer
        self.max_len = max_len
        for f in files:
            if not os.path.exists(f):
                log.warning(f"Skip missing: {f}")
                continue
            log.info(f"Loading {f}...")
            with open(f) as fh:
                for i, line in enumerate(fh):
                    if not line.strip(): continue
                    try:
                        item = json.loads(line)
                        inp = item.get('input') or item.get('question') or ''
                        out = item.get('output') or item.get('answer') or ''
                        if inp and out:
                            self.examples.append(f"<|user|>\n{inp}\n<|assistant|>\n{out}")
                    except: pass
                    if i % 5000 == 0 and i > 0:
                        log.info(f"  loaded {len(self.examples)} from {f}...")
        log.info(f"Total examples: {len(self.examples)}")

    def __len__(self): return len(self.examples)

    def __getitem__(self, idx):
        enc = self.tok(self.examples[idx], truncation=True, max_length=self.max_len,
                       padding='max_length', return_tensors='pt')
        ids = enc['input_ids'].squeeze()
        mask = enc['attention_mask'].squeeze()
        return {'input_ids': ids, 'attention_mask': mask, 'labels': ids.clone()}

# ── Main ────────────────────────────────────────────────────────────────
def main():
    from transformers import AutoModelForCausalLM, AutoTokenizer

    log.info("=" * 60)
    log.info("TinkerIA 3B Training (CPU mode)")
    log.info("=" * 60)
    device = 'cpu'
    log.info(f"Device: {device}")
    
    # Check available memory
    import psutil
    mem = psutil.virtual_memory()
    log.info(f"Available RAM: {mem.available/1e9:.1f} GB / {mem.total/1e9:.1f} GB")

    log.info(f"Loading tokenizer from {MODEL_DIR}...")
    tok = AutoTokenizer.from_pretrained(MODEL_DIR, trust_remote_code=True)
    if tok.pad_token is None: tok.pad_token = tok.eos_token

    log.info(f"Loading model from {MODEL_DIR}...")
    model = AutoModelForCausalLM.from_pretrained(
        MODEL_DIR, torch_dtype=torch.float32, trust_remote_code=True,
        attn_implementation='eager', device_map=None
    )
    # Enable gradients on all parameters
    for param in model.parameters():
        param.requires_grad = True
    model.train()
    model = model.cpu()
    model.train()
    params = sum(p.numel() for p in model.parameters())
    log.info(f"Model loaded: {params:,} params")

    ds = TextDataset([DATA_FILE, DATA_FILE2], tok, MAX_LEN)
    if len(ds) == 0:
        log.error("No data!"); return
    dl = DataLoader(ds, batch_size=BATCH, shuffle=True, num_workers=0)

    # Quick forward pass test
    log.info("Testing forward pass...")
    test_batch = next(iter(dl))
    with torch.no_grad():
        test_out = model(input_ids=test_batch['input_ids'], attention_mask=test_batch['attention_mask'], labels=test_batch['labels'])
    log.info(f"Forward pass OK! loss={test_out.loss.item():.4f}")

    # Use standard AdamW with less memory (BAdam stores same state)
    opt = torch.optim.AdamW(model.parameters(), lr=LR, weight_decay=0.01)
    total_steps = len(dl) * EPOCHS // GRAD_ACCUM
    sched = torch.optim.lr_scheduler.OneCycleLR(opt, max_lr=LR, total_steps=total_steps,
                                                 pct_start=0.1, anneal_strategy='cos')

    os.makedirs(OUT_DIR, exist_ok=True)
    log.info(f"Training: {len(ds)} examples, {EPOCHS} epochs, effective batch {BATCH*GRAD_ACCUM}")
    log.info(f"Total steps: {total_steps}")
    log.info(f"Max sequence length: {MAX_LEN} tokens")
    log.info(f"Dtype: float32 (CPU)")

    step = 0
    best_loss = 999
    t0 = time.time()

    for epoch in range(EPOCHS):
        log.info(f"\n=== Epoch {epoch+1}/{EPOCHS} ===")
        epoch_loss = 0
        epoch_n = 0
        for bi, batch in enumerate(dl):
            try:
                ids = batch['input_ids']
                mask = batch['attention_mask']
                labels = batch['labels']

                out = model(input_ids=ids, attention_mask=mask, labels=labels)
                loss = out.loss / GRAD_ACCUM
                loss.backward()
                epoch_loss += loss.item() * GRAD_ACCUM
                epoch_n += 1

                if (bi + 1) % GRAD_ACCUM == 0:
                    torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
                    opt.step()
                    sched.step()
                    opt.zero_grad()
                    step += 1

                    if step % LOG_EVERY == 0:
                        avg = epoch_loss / max(epoch_n, 1)
                        elapsed = time.time() - t0
                        speed = step / elapsed
                        eta = (total_steps - step) / max(speed, 0.01) / 60
                        log.info(f"Step {step}/{total_steps} | loss={avg:.4f} | {speed:.2f} steps/s | ETA {eta:.0f}m")

                    if step % SAVE_EVERY == 0:
                        ckpt = os.path.join(OUT_DIR, f'checkpoint-{step}')
                        os.makedirs(ckpt, exist_ok=True)
                        model.save_pretrained(ckpt)
                        tok.save_pretrained(ckpt)
                        if epoch_loss/max(epoch_n,1) < best_loss:
                            best_loss = epoch_loss/max(epoch_n,1)
                            bd = os.path.join(OUT_DIR, 'best')
                            os.makedirs(bd, exist_ok=True)
                            model.save_pretrained(bd)
                            tok.save_pretrained(bd)
                        log.info(f"Saved checkpoint {ckpt} (best={best_loss:.4f})")
            except Exception as e:
                log.error(f"Error at batch {bi}: {e}")
                import traceback
                traceback.print_exc()
                continue

        avg_el = epoch_loss / max(epoch_n, 1)
        log.info(f"Epoch {epoch+1} done. avg_loss={avg_el:.4f}")

    final = os.path.join(OUT_DIR, 'final')
    os.makedirs(final, exist_ok=True)
    model.save_pretrained(final)
    tok.save_pretrained(final)
    with open(os.path.join(OUT_DIR, 'config.json'), 'w') as f:
        json.dump({'model': MODEL_DIR, 'data': [DATA_FILE, DATA_FILE2], 'epochs': EPOCHS,
                   'lr': LR, 'batch': BATCH, 'grad_accum': GRAD_ACCUM, 'steps': step,
                   'best_loss': best_loss}, f, indent=2)
    log.info(f"\nDONE! {step} steps, best_loss={best_loss:.4f}")
    log.info(f"Model saved to: {OUT_DIR}/final")

if __name__ == '__main__':
    os.environ['CUDA_VISIBLE_DEVICES'] = ''  # Force CPU
    main()
