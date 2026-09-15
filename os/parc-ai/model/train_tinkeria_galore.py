#!/usr/bin/env python3
"""
TinkerIA 3B Full Fine-Tuning — GaLore (CPU)
Uses gradient low-rank projection for memory-efficient full parameter training.
No LoRA. Full model updates with ~32GB RAM on CPU.
"""
import os, sys, json, time, math
os.environ['CUDA_VISIBLE_DEVICES'] = ''

import torch
from torch.utils.data import Dataset, DataLoader
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s %(message)s',
    handlers=[logging.FileHandler('/tmp/tinkeria_train.log'), logging.StreamHandler()])
log = logging.getLogger(__name__)

MODEL_DIR  = os.path.expanduser('~/models/phi-3.5-mini')
DATA_FILES = [
    '/home/tinkerspace/linux-kernel/os/parc-ai/model/training_data/wiki_training.jsonl',
    '/home/tinkerspace/linux-kernel/os/parc-ai/model/training_data/merged_all.jsonl',
]
OUT_DIR    = '/home/tinkerspace/linux-kernel/os/parc-ai/model/checkpoints/tinkeria_full'
MAX_LEN    = 256
BATCH      = 1
GRAD_ACCUM = 4
LR         = 1e-5
EPOCHS     = 2
SAVE_EVERY = 200
LOG_EVERY  = 5
GALORE_RANK = 128  # Low-rank projection dimension

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
        log.info(f"Total: {len(self.examples)} examples")

    def __len__(self): return len(self.examples)
    def __getitem__(self, idx):
        enc = self.tok(self.examples[idx], truncation=True, max_length=self.max_len,
                       padding='max_length', return_tensors='pt')
        ids = enc['input_ids'].squeeze()
        mask = enc['attention_mask'].squeeze()
        return {'input_ids': ids, 'attention_mask': mask, 'labels': ids.clone()}

def main():
    from transformers import AutoModelForCausalLM, AutoTokenizer
    from galore_adamw import GaLoreAdamW, GaLoreConfig

    log.info("=" * 60)
    log.info("TinkerIA 3B — Full Fine-Tuning with GaLore (CPU)")
    log.info("=" * 60)

    import psutil
    mem = psutil.virtual_memory()
    log.info(f"RAM: {mem.available/1e9:.1f}GB free / {mem.total/1e9:.1f}GB total")

    tok = AutoTokenizer.from_pretrained(MODEL_DIR, trust_remote_code=True)
    if tok.pad_token is None: tok.pad_token = tok.eos_token

    log.info("Loading base model (full parameters)...")
    model = AutoModelForCausalLM.from_pretrained(
        MODEL_DIR, torch_dtype=torch.float32, trust_remote_code=True,
        attn_implementation='eager', device_map=None
    )
    model.train()
    model = model.cpu()

    total = sum(p.numel() for p in model.parameters())
    trainable = sum(p.numel() for p in model.parameters() if p.requires_grad)
    log.info(f"Parameters: {trainable:,} / {total:,} (FULL fine-tuning)")
    log.info(f"Model size: {total * 4 / 1e9:.1f}GB (float32)")

    # GaLore optimizer with gradient low-rank projection
    # Projects gradients to rank-128 subspace per layer → saves ~90% optimizer memory
    config = GaLoreConfig(lr=LR, weight_decay=0.01, rank=GALORE_RANK, update_proj_gap=200)
    opt = GaLoreAdamW(model.parameters(), cfg=config)

    ds = TextDataset(DATA_FILES, tok, MAX_LEN)
    if len(ds) == 0:
        log.error("No data!"); return
    dl = DataLoader(ds, batch_size=BATCH, shuffle=True, num_workers=0)

    total_steps = len(dl) * EPOCHS // GRAD_ACCUM
    sched = torch.optim.lr_scheduler.OneCycleLR(opt, max_lr=LR, total_steps=total_steps,
                                                 pct_start=0.1, anneal_strategy='cos')

    os.makedirs(OUT_DIR, exist_ok=True)

    # Save on interrupt
    import signal
    def save_on_exit(sig, frame):
        log.info("Interrupted — saving checkpoint...")
        ckpt = os.path.join(OUT_DIR, 'latest')
        import shutil
        if os.path.exists(ckpt): shutil.rmtree(ckpt)
        os.makedirs(ckpt, exist_ok=True)
        model.save_pretrained(ckpt)
        tok.save_pretrained(ckpt)
        with open(os.path.join(OUT_DIR, 'checkpoint_meta.json'), 'w') as f:
            json.dump({'step': step, 'epoch': 0, 'loss': 0, 'interrupted': True}, f, indent=2)
        log.info(f"Saved at step {step}")
        sys.exit(0)
    signal.signal(signal.SIGINT, save_on_exit)
    signal.signal(signal.SIGTERM, save_on_exit)

    log.info(f"Training: {len(ds)} examples, {EPOCHS} epochs, effective batch {BATCH*GRAD_ACCUM}")
    log.info(f"Steps: {total_steps} | GaLore rank: {GALORE_RANK} | Max len: {MAX_LEN}")

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
                out = model(input_ids=batch['input_ids'], attention_mask=batch['attention_mask'], labels=batch['labels'])
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
                        mem_used = psutil.virtual_memory().used / 1e9
                        log.info(f"Step {step}/{total_steps} | loss={avg:.4f} | {speed:.2f} steps/s | ETA {eta:.0f}m | RAM {mem_used:.0f}GB")

                    if step % SAVE_EVERY == 0:
                        avg = epoch_loss / max(epoch_n, 1)
                        ckpt = os.path.join(OUT_DIR, 'latest')
                        
                        # Rolling checkpoint: delete old, save new
                        if os.path.exists(ckpt):
                            import shutil
                            shutil.rmtree(ckpt)
                        os.makedirs(ckpt, exist_ok=True)
                        model.save_pretrained(ckpt)
                        tok.save_pretrained(ckpt)
                        
                        # Save step metadata
                        with open(os.path.join(OUT_DIR, 'checkpoint_meta.json'), 'w') as f:
                            json.dump({'step': step, 'epoch': epoch, 'loss': avg,
                                      'best_loss': best_loss, 'total_steps': total_steps}, f, indent=2)
                        
                        # Keep best separately (small, just weights)
                        if avg < best_loss:
                            best_loss = avg
                            bd = os.path.join(OUT_DIR, 'best')
                            if os.path.exists(bd):
                                import shutil
                                shutil.rmtree(bd)
                            os.makedirs(bd, exist_ok=True)
                            model.save_pretrained(bd)
                            tok.save_pretrained(bd)
                        
                        log.info(f"Checkpoint saved: step {step}, loss={avg:.4f}, best={best_loss:.4f}")
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
    model.save_pretrained(final)
    tok.save_pretrained(final)
    with open(os.path.join(OUT_DIR, 'config.json'), 'w') as f:
        json.dump({'base_model': MODEL_DIR, 'galore_rank': GALORE_RANK, 'epochs': EPOCHS,
                   'lr': LR, 'steps': step, 'best_loss': best_loss,
                   'trainable_params': trainable, 'total_params': total,
                   'data': DATA_FILES}, f, indent=2)
    log.info(f"\nDONE! {step} steps, best_loss={best_loss:.4f}")
    log.info(f"Full model saved to: {OUT_DIR}/final")

if __name__ == '__main__':
    main()
