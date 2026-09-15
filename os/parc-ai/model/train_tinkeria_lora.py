#!/usr/bin/env python3
"""
TinkerIA 3B Training — LoRA Mode (CPU-safe)
Uses LoRA adapters to fine-tune Phi-3.5-mini within 16GB RAM.
The full base model stays frozen; only adapter layers train.
This is NOT LoRA-as-lazy — it's the practical approach for a 3B model on shared RAM.
"""
import os, sys, json, time, math
os.environ['CUDA_VISIBLE_DEVICES'] = ''

import torch
from torch.utils.data import Dataset, DataLoader
from pathlib import Path
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s %(message)s',
    handlers=[logging.FileHandler('/tmp/tinkeria_train.log'), logging.StreamHandler()])
log = logging.getLogger(__name__)

MODEL_DIR  = os.path.expanduser('~/models/phi-3.5-mini')
DATA_FILES = [
    '/home/tinkerspace/linux-kernel/os/parc-ai/model/training_data/wiki_training.jsonl',
    '/home/tinkerspace/linux-kernel/os/parc-ai/model/training_data/merged_all.jsonl',
]
OUT_DIR    = '/home/tinkerspace/linux-kernel/os/parc-ai/model/checkpoints/tinkeria_lora'
MAX_LEN    = 256
BATCH      = 1
GRAD_ACCUM = 4
LR         = 3e-4
EPOCHS     = 2
SAVE_EVERY = 100
LOG_EVERY  = 5
LORA_R     = 16
LORA_ALPHA = 32

# ── LoRA layer ──────────────────────────────────────────────────────────
class LoRALinear(torch.nn.Module):
    def __init__(self, orig, r=16, alpha=32):
        super().__init__()
        self.orig = orig
        self.orig.weight.requires_grad = False
        d_in = orig.in_features
        d_out = orig.out_features
        self.lora_A = torch.nn.Parameter(torch.randn(d_in, r) * 0.01)
        self.lora_B = torch.nn.Parameter(torch.zeros(r, d_out))
        self.scaling = alpha / r

    def forward(self, x):
        return self.orig(x) + (x @ self.lora_A @ self.lora_B) * self.scaling

# ── Dataset ─────────────────────────────────────────────────────────────
class TextDataset(Dataset):
    def __init__(self, files, tokenizer, max_len):
        self.examples = []
        self.tok = tokenizer
        self.max_len = max_len
        for f in files:
            if not os.path.exists(f): continue
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
                        log.info(f"  {len(self.examples)} loaded...")
        log.info(f"Total: {len(self.examples)} examples")

    def __len__(self): return len(self.examples)
    def __getitem__(self, idx):
        enc = self.tok(self.examples[idx], truncation=True, max_length=self.max_len,
                       padding='max_length', return_tensors='pt')
        ids = enc['input_ids'].squeeze()
        mask = enc['attention_mask'].squeeze()
        return {'input_ids': ids, 'attention_mask': mask, 'labels': ids.clone()}

def inject_lora(model, r=LORA_R, alpha=LORA_ALPHA):
    count = 0
    for name, module in model.named_modules():
        if isinstance(module, torch.nn.Linear) and module.out_features >= 64:
            parent_name = '.'.join(name.split('.')[:-1])
            attr_name = name.split('.')[-1]
            parent = model
            for p in parent_name.split('.'):
                if p: parent = getattr(parent, p)
            setattr(parent, attr_name, LoRALinear(module, r, alpha))
            count += 1
    return count

def main():
    from transformers import AutoModelForCausalLM, AutoTokenizer

    log.info("=" * 60)
    log.info("TinkerIA 3B — LoRA Fine-Tuning (CPU)")
    log.info("=" * 60)

    import psutil
    mem = psutil.virtual_memory()
    log.info(f"RAM: {mem.available/1e9:.1f}GB free / {mem.total/1e9:.1f}GB total")

    tok = AutoTokenizer.from_pretrained(MODEL_DIR, trust_remote_code=True)
    if tok.pad_token is None: tok.pad_token = tok.eos_token

    log.info("Loading base model...")
    model = AutoModelForCausalLM.from_pretrained(
        MODEL_DIR, torch_dtype=torch.float32, trust_remote_code=True,
        attn_implementation='eager', device_map=None
    )
    model.eval()
    model = model.cpu()

    lora_count = inject_lora(model)
    log.info(f"Injected LoRA into {lora_count} linear layers (r={LORA_R}, alpha={LORA_ALPHA})")

    # Only LoRA params are trainable
    trainable = sum(p.numel() for p in model.parameters() if p.requires_grad)
    total = sum(p.numel() for p in model.parameters())
    log.info(f"Trainable: {trainable:,} / {total:,} ({100*trainable/total:.2f}%)")

    ds = TextDataset(DATA_FILES, tok, MAX_LEN)
    if len(ds) == 0:
        log.error("No data!"); return
    dl = DataLoader(ds, batch_size=BATCH, shuffle=True, num_workers=0)

    opt = torch.optim.AdamW(filter(lambda p: p.requires_grad, model.parameters()),
                           lr=LR, weight_decay=0.01)
    total_steps = len(dl) * EPOCHS // GRAD_ACCUM
    sched = torch.optim.lr_scheduler.OneCycleLR(opt, max_lr=LR, total_steps=total_steps,
                                                 pct_start=0.1, anneal_strategy='cos')

    os.makedirs(OUT_DIR, exist_ok=True)
    log.info(f"Training: {len(ds)} examples, {EPOCHS} epochs, effective batch {BATCH*GRAD_ACCUM}")
    log.info(f"Steps: {total_steps} | LORA_R: {LORA_R} | Max len: {MAX_LEN}")

    # Test forward
    log.info("Testing forward pass...")
    test = next(iter(dl))
    with torch.no_grad():
        out = model(input_ids=test['input_ids'], attention_mask=test['attention_mask'], labels=test['labels'])
    log.info(f"Forward pass OK! loss={out.loss.item():.4f}")

    step = 0
    best_loss = 999
    t0 = time.time()

    for epoch in range(EPOCHS):
        log.info(f"\n=== Epoch {epoch+1}/{EPOCHS} ===")
        epoch_loss = 0
        epoch_n = 0
        for bi, batch in enumerate(dl):
            try:
                model.train()
                out = model(input_ids=batch['input_ids'], attention_mask=batch['attention_mask'], labels=batch['labels'])
                loss = out.loss / GRAD_ACCUM
                loss.backward()
                epoch_loss += loss.item() * GRAD_ACCUM
                epoch_n += 1

                if (bi + 1) % GRAD_ACCUM == 0:
                    torch.nn.utils.clip_grad_norm_(
                        [p for p in model.parameters() if p.requires_grad], 1.0)
                    opt.step()
                    sched.step()
                    opt.zero_grad()
                    step += 1

                    if step % LOG_EVERY == 0:
                        avg = epoch_loss / max(epoch_n, 1)
                        elapsed = time.time() - t0
                        speed = step / elapsed
                        eta = (total_steps - step) / max(speed, 0.01) / 60
                        mem_used = psutil.virtual_memory().used / 1e9
                        log.info(f"Step {step}/{total_steps} | loss={avg:.4f} | {speed:.2f} steps/s | ETA {eta:.0f}m | RAM {mem_used:.0f}GB")

                    if step % SAVE_EVERY == 0:
                        ckpt = os.path.join(OUT_DIR, f'checkpoint-{step}')
                        os.makedirs(ckpt, exist_ok=True)
                        # Save only LoRA weights
                        lora_state = {k: v for k, v in model.state_dict().items() if 'lora' in k}
                        torch.save(lora_state, os.path.join(ckpt, 'lora_weights.pt'))
                        # Save config
                        with open(os.path.join(ckpt, 'config.json'), 'w') as f:
                            json.dump({'step': step, 'epoch': epoch, 'loss': avg,
                                      'lora_r': LORA_R, 'lora_alpha': LORA_ALPHA,
                                      'lora_count': lora_count}, f, indent=2)
                        if avg < best_loss:
                            best_loss = avg
                            bd = os.path.join(OUT_DIR, 'best')
                            os.makedirs(bd, exist_ok=True)
                            lora_state = {k: v for k, v in model.state_dict().items() if 'lora' in k}
                            torch.save(lora_state, os.path.join(bd, 'lora_weights.pt'))
                        log.info(f"Saved {ckpt} (best={best_loss:.4f})")
            except Exception as e:
                log.error(f"Error at batch {bi}: {e}")
                import traceback
                traceback.print_exc()
                continue

        avg_el = epoch_loss / max(epoch_n, 1)
        log.info(f"Epoch {epoch+1} done. avg_loss={avg_el:.4f}")

    # Save final
    final = os.path.join(OUT_DIR, 'final')
    os.makedirs(final, exist_ok=True)
    lora_state = {k: v for k, v in model.state_dict().items() if 'lora' in k}
    torch.save(lora_state, os.path.join(final, 'lora_weights.pt'))
    tok.save_pretrained(final)
    with open(os.path.join(OUT_DIR, 'config.json'), 'w') as f:
        json.dump({'base_model': MODEL_DIR, 'lora_r': LORA_R, 'lora_alpha': LORA_ALPHA,
                   'lora_count': lora_count, 'epochs': EPOCHS, 'lr': LR,
                   'steps': step, 'best_loss': best_loss, 'data': DATA_FILES}, f, indent=2)
    log.info(f"\nDONE! {step} steps, best_loss={best_loss:.4f}")
    log.info(f"LoRA weights saved to: {OUT_DIR}/final")

if __name__ == '__main__':
    main()
