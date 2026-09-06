#!/usr/bin/env python3
"""
TinkerAI Small RNN - Lightweight LSTM for TinkerOS
Runs locally with numpy only (no PyTorch/TensorFlow)
"""

import numpy as np
import os
import json
from pathlib import Path
from datetime import datetime


class TinkerRNN:
    """Small LSTM language model for on-device AI assistant"""

    def __init__(self, vocab_size=512, embed_dim=96, hidden_dim=256, num_layers=1):
        self.vocab_size = vocab_size
        self.embed_dim = embed_dim
        self.hidden_dim = hidden_dim
        self.num_layers = num_layers
        self.seq_len = 96
        self._init_weights()

    def _init_weights(self):
        scale = 1.0 / np.sqrt(self.hidden_dim)

        self.embed = np.random.randn(self.vocab_size, self.embed_dim) * scale

        self.weights = {}
        for layer in range(self.num_layers):
            input_dim = self.embed_dim if layer == 0 else self.hidden_dim

            self.weights[f'layer{layer}'] = {
                'W_i': np.random.randn(input_dim, self.hidden_dim) * scale,
                'W_f': np.random.randn(input_dim, self.hidden_dim) * scale,
                'W_o': np.random.randn(input_dim, self.hidden_dim) * scale,
                'W_c': np.random.randn(input_dim, self.hidden_dim) * scale,

                'U_i': np.random.randn(self.hidden_dim, self.hidden_dim) * scale,
                'U_f': np.random.randn(self.hidden_dim, self.hidden_dim) * scale,
                'U_o': np.random.randn(self.hidden_dim, self.hidden_dim) * scale,
                'U_c': np.random.randn(self.hidden_dim, self.hidden_dim) * scale,

                'b_i': np.zeros((1, self.hidden_dim)),
                'b_f': np.ones((1, self.hidden_dim)),
                'b_o': np.zeros((1, self.hidden_dim)),
                'b_c': np.zeros((1, self.hidden_dim)),
            }

        self.W_out = np.random.randn(self.hidden_dim, self.vocab_size) * scale
        self.b_out = np.zeros((1, self.vocab_size))

    def _sigmoid(self, x):
        return 1.0 / (1.0 + np.exp(-np.clip(x, -500, 500)))

    def _softmax(self, x):
        x = x - np.max(x, axis=-1, keepdims=True)
        exp_x = np.exp(x)
        return exp_x / np.sum(exp_x, axis=-1, keepdims=True)

    def forward(self, x, hidden_states=None, store_cache=False):
        """Forward pass through LSTM. Returns outputs, hidden_states, optional cache."""
        if isinstance(x, list):
            x = np.array([x])
        elif x.ndim == 1:
            x = np.expand_dims(x, 0)

        batch_size, seq_len = x.shape

        if hidden_states is None:
            hidden_states = [(np.zeros((batch_size, self.hidden_dim)),
                              np.zeros((batch_size, self.hidden_dim)))
                             for _ in range(self.num_layers)]

        outputs = []
        cache = {'steps': []}

        for t in range(seq_len):
            x_t = self.embed[x[:, t]]

            new_hidden = []
            step_cache = {'x_in': x_t, 'x_tok': x[:, t], 'layers': []}
            for layer in range(self.num_layers):
                h_prev, c_prev = hidden_states[layer]
                w = self.weights[f'layer{layer}']

                f = self._sigmoid(x_t @ w['W_f'] + h_prev @ w['U_f'] + w['b_f'])
                i = self._sigmoid(x_t @ w['W_i'] + h_prev @ w['U_i'] + w['b_i'])
                c_tilde = np.tanh(x_t @ w['W_c'] + h_prev @ w['U_c'] + w['b_c'])
                o = self._sigmoid(x_t @ w['W_o'] + h_prev @ w['U_o'] + w['b_o'])

                c_new = f * c_prev + i * c_tilde
                h_new = o * np.tanh(c_new)

                step_cache['layers'].append({
                    'h_prev': h_prev, 'c_prev': c_prev,
                    'f': f, 'i': i, 'c_tilde': c_tilde, 'o': o,
                    'c_new': c_new, 'h_new': h_new,
                })
                new_hidden.append((h_new, c_new))
                x_t = h_new

            hidden_states = new_hidden
            out = h_new @ self.W_out + self.b_out
            outputs.append(out)
            if store_cache:
                cache['steps'].append(step_cache)

        if store_cache:
            return np.stack(outputs, axis=1), hidden_states, cache
        return np.stack(outputs, axis=1), hidden_states

    def backward(self, grad_outputs, cache):
        """Backprop through time for a batch. grad_outputs: (T, B, V)"""
        T = len(cache['steps'])
        B = grad_outputs[0].shape[0]
        grads = {f'layer{layer}': {k: np.zeros_like(v) for k, v in self.weights[f'layer{layer}'].items()}
                 for layer in range(self.num_layers)}
        grad_W_out = np.zeros_like(self.W_out)
        grad_b_out = np.zeros_like(self.b_out)

        grad_x = np.zeros_like(self.embed)
        dh_next = [np.zeros((B, self.hidden_dim)) for _ in range(self.num_layers)]
        dc_next = [np.zeros((B, self.hidden_dim)) for _ in range(self.num_layers)]

        for t in reversed(range(T)):
            step = cache['steps'][t]
            dout = grad_outputs[t]

            grad_W_out += step['layers'][-1]['h_new'].T @ dout
            grad_b_out += dout.sum(axis=0, keepdims=True)

            d_input_above = None
            for layer in reversed(range(self.num_layers)):
                L = step['layers'][layer]
                w = self.weights[f'layer{layer}']
                g = grads[f'layer{layer}']

                if layer == self.num_layers - 1:
                    dh = dout @ self.W_out.T
                else:
                    dh = d_input_above
                dh = dh + dh_next[layer]

                dc = dc_next[layer] + dh * L['o'] * (1.0 - np.tanh(L['c_new']) ** 2)

                d_o = dh * np.tanh(L['c_new'])
                d_c_tilde = dc * L['i']
                d_i = dc * L['c_tilde']
                d_f = dc * L['c_prev']

                x_in = step['x_in'] if layer == 0 else step['layers'][layer - 1]['h_new']

                df = d_f * L['f'] * (1.0 - L['f'])
                di = d_i * L['i'] * (1.0 - L['i'])
                dc_t = d_c_tilde * (1.0 - L['c_tilde'] ** 2)
                do_ = d_o * L['o'] * (1.0 - L['o'])

                g['W_f'] += x_in.T @ df
                g['U_f'] += L['h_prev'].T @ df
                g['b_f'] += df.sum(axis=0, keepdims=True)

                g['W_i'] += x_in.T @ di
                g['U_i'] += L['h_prev'].T @ di
                g['b_i'] += di.sum(axis=0, keepdims=True)

                g['W_c'] += x_in.T @ dc_t
                g['U_c'] += L['h_prev'].T @ dc_t
                g['b_c'] += dc_t.sum(axis=0, keepdims=True)

                g['W_o'] += x_in.T @ do_
                g['U_o'] += L['h_prev'].T @ do_
                g['b_o'] += do_.sum(axis=0, keepdims=True)

                dh_prev = df @ w['U_f'].T + di @ w['U_i'].T + dc_t @ w['U_c'].T + do_ @ w['U_o'].T
                dh_next[layer] = dh_prev
                dc_next[layer] = dc * L['f']

                d_input = df @ w['W_f'].T + di @ w['W_i'].T + dc_t @ w['W_c'].T + do_ @ w['W_o'].T
                d_input_above = d_input
                if layer == 0:
                    for b in range(B):
                        grad_x[step['x_tok'][b]] += d_input[b]

        return grads, grad_W_out, grad_b_out, grad_x

    def generate(self, input_ids, max_new_tokens=50, temperature=0.8):
        """Generate text from input"""
        hidden_states = None
        input_ids = list(input_ids)

        if input_ids:
            _, hidden_states = self.forward(np.array([input_ids]))

        generated = []
        for _ in range(max_new_tokens):
            last_input = np.array([[generated[-1] if generated else input_ids[-1]]])
            output, hidden_states = self.forward(last_input, hidden_states)
            logits = output[0, -1, :] / temperature
            probs = self._softmax(logits)

            next_token = int(np.random.choice(len(probs), p=probs))

            if next_token in (0, 3):
                break

            generated.append(next_token)
            if len(generated) >= self.seq_len:
                break

        return generated

    def save(self, path):
        data = {
            'vocab_size': self.vocab_size,
            'embed_dim': self.embed_dim,
            'hidden_dim': self.hidden_dim,
            'num_layers': self.num_layers,
            'embed': self.embed.tolist(),
            'weights': {k: {kk: vv.tolist() for kk, vv in v.items()}
                        for k, v in self.weights.items()},
            'W_out': self.W_out.tolist(),
            'b_out': self.b_out.tolist(),
        }
        Path(path).write_text(json.dumps(data, indent=2))
        print(f"Model saved to {path} ({os.path.getsize(path)} bytes)")

    def load(self, path):
        data = json.loads(Path(path).read_text())
        self.vocab_size = data['vocab_size']
        self.embed_dim = data['embed_dim']
        self.hidden_dim = data['hidden_dim']
        self.num_layers = data['num_layers']
        self.embed = np.array(data['embed'])
        self.weights = {k: {kk: np.array(vv) for kk, vv in v.items()}
                        for k, v in data['weights'].items()}
        self.W_out = np.array(data['W_out'])
        self.b_out = np.array(data['b_out'])
        print(f"Model loaded from {path}")


class TinkerTokenizer:
    """Simple character-level tokenizer for TinkerAI"""

    def __init__(self):
        self.stoi = {}
        self.itos = {}
        self.vocab_size = 0

    def train(self, texts):
        chars = set()
        for text in texts:
            chars.update(text.lower())

        chars = sorted(chars)

        self.stoi = {'<PAD>': 0, '<UNK>': 1, '<BOS>': 2, '<EOS>': 3}
        for i, c in enumerate(chars):
            self.stoi[c] = i + 4

        self.itos = {v: k for k, v in self.stoi.items()}
        self.vocab_size = len(self.stoi)
        return self

    def encode(self, text):
        return [self.stoi.get(c, 1) for c in text.lower()]

    def decode(self, ids):
        chars = []
        for i in ids:
            c = self.itos.get(i, '')
            if c and c not in ('<PAD>', '<UNK>', '<BOS>', '<EOS>'):
                chars.append(c)
        return ''.join(chars)

    def save(self, path):
        data = {'stoi': self.stoi, 'itos': {str(k): v for k, v in self.itos.items()}}
        Path(path).write_text(json.dumps(data))

    def load(self, path):
        data = json.loads(Path(path).read_text())
        self.stoi = data['stoi']
        self.itos = {int(k): v for k, v in data['itos'].items()}
        self.vocab_size = len(self.stoi)


try:
    from data_generator import TINKER_TRAINING_DATA
except Exception:
    TINKER_TRAINING_DATA = []


class GaLoreOptimizer:
    """Adam with optional GaLore low-rank gradient projection for matrix params.

    GaLore (Zhao et al. 2024) projects each weight matrix's gradient into a
    low-rank subspace (via SVD of the gradient, refreshed periodically) and runs
    Adam in that small space. This drastically cuts optimizer-state memory and
    gives a well-regularised fine-tuning update.
    """

    def __init__(self, model, lr=1e-3, beta1=0.9, beta2=0.999, eps=1e-8,
                 weight_decay=0.0, rank=64, update_proj_gap=200,
                 scale=1.0, use_galore=True):
        self.lr = lr
        self.beta1 = beta1
        self.beta2 = beta2
        self.eps = eps
        self.weight_decay = weight_decay
        self.rank = rank
        self.update_proj_gap = update_proj_gap
        self.scale = scale
        self.use_galore = use_galore
        self.t = 0
        self.params = self._build_params(model)

    def _build_params(self, model):
        params = []

        def add(name, arr, matrix):
            r = min(self.rank, arr.shape[0], arr.shape[1]) if matrix else 0
            params.append({
                'name': name, 'array': arr, 'matrix': matrix,
                'galore': matrix and self.use_galore,
                'm': np.zeros((r, r)) if matrix and self.use_galore else np.zeros_like(arr),
                'v': np.zeros((r, r)) if matrix and self.use_galore else np.zeros_like(arr),
                'Q': None, 'R': None, 'proj_t': -10 ** 9,
            })

        add('embed', model.embed, True)
        for layer in range(model.num_layers):
            w = model.weights[f'layer{layer}']
            for k in ('W_i', 'W_f', 'W_o', 'W_c', 'U_i', 'U_f', 'U_o', 'U_c'):
                add(f'layer{layer}.{k}', w[k], True)
            for k in ('b_i', 'b_f', 'b_o', 'b_c'):
                add(f'layer{layer}.{k}', w[k], False)
        add('W_out', model.W_out, True)
        add('b_out', model.b_out, False)
        return params

    def step(self, grads):
        self.t += 1
        for p in self.params:
            g = grads[p['name']]
            if p['galore']:
                m, n = g.shape
                r = min(self.rank, m, n)
                if (self.t - p['proj_t']) >= self.update_proj_gap:
                    U, S, Vt = np.linalg.svd(g, full_matrices=False)
                    p['Q'] = U[:, :r]
                    p['R'] = Vt[:r, :]
                    p['m'] = np.zeros((r, r))
                    p['v'] = np.zeros((r, r))
                    p['proj_t'] = self.t
                P = p['Q'].T @ g @ p['R'].T
                p['m'] = self.beta1 * p['m'] + (1 - self.beta1) * P
                p['v'] = self.beta2 * p['v'] + (1 - self.beta2) * (P * P)
                mhat = p['m'] / (1 - self.beta1 ** self.t)
                vhat = p['v'] / (1 - self.beta2 ** self.t)
                delta = p['Q'] @ (mhat / (np.sqrt(vhat) + self.eps)) @ p['R']
                p['array'] -= self.lr * self.scale * delta
            else:
                if self.weight_decay:
                    p['array'] *= (1 - self.lr * self.weight_decay)
                p['m'] = self.beta1 * p['m'] + (1 - self.beta1) * g
                p['v'] = self.beta2 * p['v'] + (1 - self.beta2) * (g * g)
                mhat = p['m'] / (1 - self.beta1 ** self.t)
                vhat = p['v'] / (1 - self.beta2 ** self.t)
                p['array'] -= self.lr * (mhat / (np.sqrt(vhat) + self.eps))


def build_sequences(data, tokenizer, seq_len, stride):
    sequences, targets = [], []
    for q, a in data:
        full = tokenizer.encode(q) + tokenizer.encode(a)
        if len(full) < 2:
            continue
        for i in range(0, len(full) - 1, stride):
            chunk = full[i:i + seq_len]
            if len(chunk) < 2:
                break
            sequences.append(chunk[:-1])
            targets.append(chunk[1:])
    return sequences, targets


def collect_grads(model, grads, grad_W_out, grad_b_out, grad_x):
    g = {'embed': grad_x, 'W_out': grad_W_out, 'b_out': grad_b_out}
    for layer in range(model.num_layers):
        for k, v in grads[f'layer{layer}'].items():
            g[f'layer{layer}.{k}'] = v
    return g


def train_model(model, tokenizer, data, epochs=100, lr=0.005,
                checkpoint_every=100, checkpoint_path=None,
                seq_len=64, stride=16, batch=32, optimizer='adam',
                tag=''):
    """Train (or fine-tune) the model with full BPTT. Returns final loss."""
    sequences, targets = build_sequences(data, tokenizer, seq_len, stride)
    n_seq = len(sequences)
    print(f"[{tag or optimizer}] training examples: {n_seq}, "
          f"seq_len={seq_len} stride={stride} batch={batch} lr={lr} opt={optimizer}")

    opt = GaLoreOptimizer(model, lr=lr) if optimizer == 'galore' else GaLoreOptimizer(
        model, lr=lr, use_galore=False)

    best_loss = float('inf')
    for epoch in range(epochs):
        # Length-bucketed order: keeps sequence lengths close within a batch
        # so padding waste is minimal (big speedup on mixed-length data).
        lengths = np.array([len(s) for s in sequences])
        order = np.argsort(lengths, kind='stable')
        bucket = batch * 8
        for i in range(0, n_seq, bucket):
            np.random.shuffle(order[i:i + bucket])
        total_loss = 0.0
        num_batches = 0

        for start in range(0, n_seq, batch):
            idx = order[start:start + batch]
            B = len(idx)
            T = max(len(sequences[i]) for i in idx)

            x = np.zeros((B, T), dtype=int)
            y = np.zeros((B, T), dtype=int)
            for j, i in enumerate(idx):
                s = sequences[i]
                tgt = targets[i]
                x[j, :len(s)] = s
                y[j, :len(tgt)] = tgt

            out, _, cache = model.forward(x, store_cache=True)
            probs = model._softmax(out)

            loss = 0.0
            grad_out = np.zeros_like(out)
            for t in range(T):
                p = probs[:, t]
                true_idx = y[:, t]
                loss += -np.log(p[np.arange(B), true_idx] + 1e-12).sum()
                grad_out[:, t] = p
                grad_out[np.arange(B), t, true_idx] -= 1.0
            grad_out = grad_out / (B * T)

            grads, grad_W_out, grad_b_out, grad_x = model.backward(grad_out.transpose(1, 0, 2), cache)

            opt.step(collect_grads(model, grads, grad_W_out, grad_b_out, grad_x))

            total_loss += loss / (B * T)
            num_batches += 1

        avg_loss = total_loss / max(num_batches, 1)
        if epoch % 25 == 0:
            print(f"  epoch {epoch}: loss = {avg_loss:.4f}", flush=True)
        if avg_loss < best_loss:
            best_loss = avg_loss
        if checkpoint_path and (epoch + 1) % checkpoint_every == 0:
            model.save(checkpoint_path)
            print(f"  [checkpoint] saved at epoch {epoch + 1} (loss {avg_loss:.4f})", flush=True)

    return best_loss


def merge_models(model, prev_path, alpha=0.5):
    """Weight-average `model` with a previously trained model in-place.

    Merging (model soup) is only valid when both models share the exact same
    architecture and vocab. If the previous file is missing or incompatible,
    it is skipped gracefully.
    """
    prev_path = Path(prev_path)
    if not prev_path.exists():
        print(f"[merge] no previous model at {prev_path} - skipping")
        return False
    try:
        prev = json.loads(prev_path.read_text())
    except Exception as e:
        print(f"[merge] could not read previous model: {e}")
        return False

    def shape(v):
        return [len(v)] if isinstance(v, list) and (not v or not isinstance(v[0], list)) \
            else [len(v), len(v[0])] if isinstance(v, list) and isinstance(v[0], list) \
            else None

    def fields_ok(a, b):
        for key in ('vocab_size', 'embed_dim', 'hidden_dim', 'num_layers'):
            if a.get(key) != b.get(key):
                return False, key
        return True, None

    ok, key = fields_ok(prev, {'vocab_size': model.vocab_size, 'embed_dim': model.embed_dim,
                               'hidden_dim': model.hidden_dim, 'num_layers': model.num_layers})
    if not ok:
        print(f"[merge] architecture mismatch ({key}): prev={prev.get(key)}, new={model.__dict__.get(key)} - skipping")
        return False

    if shape(prev['embed']) != shape(model.embed.tolist()):
        print(f"[merge] embed shape mismatch - skipping")
        return False

    def avg(dst, src_list):
        src = np.array(src_list)
        if dst.shape != src.shape:
            raise ValueError(f"shape mismatch {dst.shape} vs {src.shape}")
        dst *= (1 - alpha)
        dst += alpha * src

    avg(model.embed, prev['embed'])
    avg(model.W_out, prev['W_out'])
    avg(model.b_out, prev['b_out'])
    for layer in range(model.num_layers):
        pkeys = prev['weights'][f'layer{layer}']
        mkeys = model.weights[f'layer{layer}']
        for k in pkeys:
            if k in mkeys:
                avg(mkeys[k], pkeys[k])
    print(f"[merge] merged with previous model (alpha={alpha})")
    return True


def main():
    import argparse
    ap = argparse.ArgumentParser(description='Train / fine-tune the TinkerAI RNN')
    ap.add_argument('--epochs', type=int, default=100, help='base Adam epochs')
    ap.add_argument('--finetune-epochs', type=int, default=0, help='GaLore fine-tune epochs')
    ap.add_argument('--lr', type=float, default=0.003)
    ap.add_argument('--finetune-lr', type=float, default=0.0005)
    ap.add_argument('--batch', type=int, default=32)
    ap.add_argument('--seq-len', type=int, default=64)
    ap.add_argument('--stride', type=int, default=16)
    ap.add_argument('--hidden', type=int, default=256)
    ap.add_argument('--rank', type=int, default=64)
    ap.add_argument('--merge', type=float, default=0.0,
                    help='weight-average with previous model (alpha); 0 disables')
    ap.add_argument('--backup-prev', action='store_true',
                    help='back up existing rnn-model.json as rnn-model-prev.json before training')
    ap.add_argument('--resume', action='store_true', help='load existing model before training')
    args = ap.parse_args()

    data_dir = Path.home() / ".tinker" / "ai" / "models"
    data_dir.mkdir(parents=True, exist_ok=True)
    model_path = data_dir / "rnn-model.json"
    prev_path = data_dir / "rnn-model-prev.json"

    if args.backup_prev and model_path.exists():
        if not prev_path.exists():
            import shutil
            shutil.copy(model_path, prev_path)
            print(f"Backed up previous model to {prev_path}")
        else:
            print(f"Previous backup already exists: {prev_path}")

    print("=" * 56)
    print("TinkerAI RNN Trainer (Adam base + GaLore fine-tune)")
    print("=" * 56)

    if not TINKER_TRAINING_DATA:
        print("FATAL: data_generator produced no data.")
        sys.exit(1)

    all_texts = []
    for q, a in TINKER_TRAINING_DATA:
        all_texts.append(q)
        all_texts.append(a)

    tokenizer = TinkerTokenizer()
    tokenizer.train(all_texts)
    tokenizer.save(str(data_dir / "tokenizer.json"))
    print(f"Tokenizer: vocab={tokenizer.vocab_size}")

    model = TinkerRNN(vocab_size=tokenizer.vocab_size,
                      embed_dim=96, hidden_dim=args.hidden, num_layers=1)

    if args.resume and model_path.exists():
        model.load(str(model_path))
        print(f"Resumed weights from {model_path}")

    # Stage 1: base training with Adam.
    if args.epochs > 0:
        print(f"\n--- Stage 1: base training (Adam, {args.epochs} epochs) ---")
        train_model(model, tokenizer, TINKER_TRAINING_DATA,
                    epochs=args.epochs, lr=args.lr,
                    checkpoint_every=max(10, args.epochs // 10),
                    checkpoint_path=str(model_path),
                    seq_len=args.seq_len, stride=args.stride, batch=args.batch,
                    optimizer='adam', tag='base')

    model.save(str(model_path))
    print(f"Base model saved: {model_path}")

    # Stage 2: fine-tune with GaLore.
    if args.finetune_epochs > 0:
        print(f"\n--- Stage 2: GaLore fine-tune ({args.finetune_epochs} epochs, lr={args.finetune_lr}, rank={args.rank}) ---")
        train_model(model, tokenizer, TINKER_TRAINING_DATA,
                    epochs=args.finetune_epochs, lr=args.finetune_lr,
                    checkpoint_every=max(10, args.finetune_epochs // 10),
                    checkpoint_path=str(model_path),
                    seq_len=args.seq_len, stride=args.stride, batch=args.batch,
                    optimizer='galore', tag='galore')

    model.save(str(model_path))
    print(f"Final model saved: {model_path}")

    # Stage 3: merge with previous model for a more robust ensemble.
    if args.merge > 0:
        print("\n--- Stage 3: merge with previous model ---")
        merge_models(model, prev_path, alpha=args.merge)
        model.save(str(model_path))

    print("\n=== Inference samples ===")
    for q, a in TINKER_TRAINING_DATA[:4]:
        ids = tokenizer.encode(q)
        gen = model.generate(ids, max_new_tokens=30, temperature=0.6)
        print(f"  Q: {q}")
        print(f"  A(train): {a}")
        print(f"  A(gen):   {tokenizer.decode(gen)}")

    print("\n" + "=" * 56)
    print("Done. TinkerAI model ready.")
    print("=" * 56)


if __name__ == "__main__":
    import sys
    main()
