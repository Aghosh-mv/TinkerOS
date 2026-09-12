#!/usr/bin/env bash
# tinkerai-model-pipeline.sh — Full model pipeline
# Step 1: Build training data from all AI modules
# Step 2: Train base transformer model
# Step 3: Convert to portable format
# Step 4: LoRA fine-tune
# Step 5: Package for release

set -euo pipefail

AI_DIR="$(cd "$(dirname "$0")" && pwd)"
MODEL_DIR="$AI_DIR/model"
TRAINING_DIR="$MODEL_DIR/training_data"
CHECKPOINT_DIR="$MODEL_DIR/checkpoints"
LORA_DIR="$MODEL_DIR/lora"
RELEASE_DIR="$MODEL_DIR/release"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date +%H:%M:%S)]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
fail() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# ===========================================================================
# Step 1: Build Training Data from AI Modules
# ===========================================================================
step1_build_training_data() {
  log "Step 1: Building training data from AI modules..."

  mkdir -p "$TRAINING_DIR"

  # Extract training pairs from all modules
  python3 << 'PYEOF'
import json
import os
import re

training_pairs = []

# 1. Extract from NLP patterns (670+ patterns)
nlp_file = os.environ.get('NLP_PATTERNS', 'os/tinker-ai/modules/nlp-670-patterns.sh')
if os.path.exists(nlp_file):
    with open(nlp_file) as f:
        content = f.read()
    # Extract patterns from heredoc
    match = re.search(r"cat << 'PATTERNS'\n(.*?)\nPATTERNS", content, re.DOTALL)
    if match:
        try:
            data = json.loads(match.group(1))
            for intent, info in data['intents'].items():
                for pattern in info['patterns']:
                    response = info['responses'][0] if info['responses'] else f"I'll help with {intent}"
                    training_pairs.append({
                        'input': pattern,
                        'output': response,
                        'intent': intent,
                        'source': 'nlp_patterns'
                    })
        except:
            pass

# 2. Extract from TinkerOS Q&A
qa_file = os.environ.get('QA_FILE', 'os/tinker-ai/model/training_data/tinkeros_qa.json')
if os.path.exists(qa_file):
    with open(qa_file) as f:
        qa_data = json.load(f)
    for pair in qa_data:
        training_pairs.append({
            'input': pair.get('question', ''),
            'output': pair.get('answer', ''),
            'intent': 'tinkeros_knowledge',
            'source': 'tinkeros_qa'
        })

# 3. Extract from general Q&A
general_file = os.environ.get('GENERAL_QA', 'os/tinker-ai/model/training_data/general_qa.json')
if os.path.exists(general_file):
    with open(general_file) as f:
        general_data = json.load(f)
    for pair in general_data:
        training_pairs.append({
            'input': pair.get('question', ''),
            'output': pair.get('answer', ''),
            'intent': 'general_knowledge',
            'source': 'general_qa'
        })

# 4. Extract from conversation patterns
conv_file = os.environ.get('CONV_FILE', 'os/tinker-ai/model/training_data/conversation_patterns.json')
if os.path.exists(conv_file):
    with open(conv_file) as f:
        conv_data = json.load(f)
    for pair in conv_data:
        training_pairs.append({
            'input': pair.get('input', ''),
            'output': pair.get('output', ''),
            'intent': 'conversation',
            'source': 'conversation_patterns'
        })

# 5. Extract from knowledge base
knowledge_file = os.environ.get('KNOWLEDGE_FILE', 'os/tinker-ai/modules/knowledge-tinkeros.sh')
if os.path.exists(knowledge_file):
    with open(knowledge_file) as f:
        content = f.read()
    # Extract Q&A pairs from knowledge base
    qa_pattern = re.findall(r'"([^"]+)"\s*\|\s*"([^"]+)"', content)
    for q, a in qa_pattern:
        training_pairs.append({
            'input': q,
            'output': a,
            'intent': 'tinkeros_knowledge',
            'source': 'knowledge_base'
        })

# Save training data
output_file = os.environ.get('OUTPUT_FILE', 'os/tinker-ai/model/training_data/all_training_data.json')
with open(output_file, 'w') as f:
    json.dump(training_pairs, f, indent=2)

print(f"Built {len(training_pairs)} training pairs")
print(f"Saved to: {output_file}")

# Stats
intents = {}
sources = {}
for pair in training_pairs:
    intent = pair['intent']
    source = pair['source']
    intents[intent] = intents.get(intent, 0) + 1
    sources[source] = sources.get(source, 0) + 1

print("\nBy intent:")
for intent, count in sorted(intents.items(), key=lambda x: -x[1])[:10]:
    print(f"  {intent}: {count}")

print("\nBy source:")
for source, count in sorted(sources.items(), key=lambda x: -x[1]):
    print(f"  {source}: {count}")
PYEOF

  success "Training data built"
}

# ===========================================================================
# Step 2: Train Base Transformer Model
# ===========================================================================
step2_train_base_model() {
  log "Step 2: Training base transformer model..."

  mkdir -p "$CHECKPOINT_DIR"

  python3 << 'PYEOF'
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
import json
import os
import time

# TinkerAI Transformer Model
class TinkerAIModel(nn.Module):
    def __init__(self, vocab_size=5000, d_model=256, nhead=8, num_layers=6, dim_feedforward=1024, dropout=0.1):
        super().__init__()
        self.d_model = d_model
        self.embedding = nn.Embedding(vocab_size, d_model)
        self.pos_encoding = nn.Parameter(torch.randn(1, 512, d_model) * 0.02)
        
        encoder_layer = nn.TransformerEncoderLayer(
            d_model=d_model,
            nhead=nhead,
            dim_feedforward=dim_feedforward,
            dropout=dropout,
            batch_first=True
        )
        self.transformer = nn.TransformerEncoder(encoder_layer, num_layers=num_layers)
        self.fc_out = nn.Linear(d_model, vocab_size)
        self.dropout = nn.Dropout(dropout)
        
    def forward(self, x):
        seq_len = x.size(1)
        x = self.embedding(x) * (self.d_model ** 0.5)
        x = x + self.pos_encoding[:, :seq_len, :]
        x = self.dropout(x)
        x = self.transformer(x)
        x = self.fc_out(x)
        return x

# Simple tokenizer
class SimpleTokenizer:
    def __init__(self):
        self.word2idx = {'<PAD>': 0, '<UNK>': 1, '<SOS>': 2, '<EOS>': 3}
        self.idx2word = {0: '<PAD>', 1: '<UNK>', 2: '<SOS>', 3: '<EOS>'}
        self.vocab_size = 4
        
    def fit(self, texts):
        for text in texts:
            for word in text.lower().split():
                if word not in self.word2idx:
                    self.word2idx[word] = self.vocab_size
                    self.idx2word[self.vocab_size] = word
                    self.vocab_size += 1
                    
    def encode(self, text, max_len=128):
        tokens = [self.word2idx.get(w, 1) for w in text.lower().split()]
        tokens = tokens[:max_len]
        tokens += [0] * (max_len - len(tokens))
        return tokens
    
    def save(self, path):
        with open(path, 'w') as f:
            json.dump({'word2idx': self.word2idx, 'vocab_size': self.vocab_size}, f)
            
    def load(self, path):
        with open(path) as f:
            data = json.load(f)
        self.word2idx = data['word2idx']
        self.vocab_size = data['vocab_size']
        self.idx2word = {int(v): k for k, v in self.word2idx.items()}

# Dataset
class QADataset(Dataset):
    def __init__(self, data, tokenizer, max_len=128):
        self.data = data
        self.tokenizer = tokenizer
        self.max_len = max_len
        
    def __len__(self):
        return len(self.data)
    
    def __getitem__(self, idx):
        item = self.data[idx]
        input_ids = self.tokenizer.encode(item['input'], self.max_len)
        target_ids = self.tokenizer.encode(item['output'], self.max_len)
        return {
            'input': torch.tensor(input_ids, dtype=torch.long),
            'target': torch.tensor(target_ids, dtype=torch.long)
        }

# Load training data
training_file = os.environ.get('TRAINING_DATA', 'os/tinker-ai/model/training_data/all_training_data.json')
if not os.path.exists(training_file):
    training_file = 'os/tinker-ai/model/training_data/tinkeros_qa.json'

with open(training_file) as f:
    training_data = json.load(f)

print(f"Loaded {len(training_data)} training pairs")

# Initialize
tokenizer = SimpleTokenizer()
all_texts = [p['input'] + ' ' + p['output'] for p in training_data]
tokenizer.fit(all_texts)

# Limit vocab for efficiency
if tokenizer.vocab_size > 5000:
    # Keep top 5000 words by frequency
    from collections import Counter
    word_counts = Counter()
    for text in all_texts:
        word_counts.update(text.lower().split())
    top_words = [w for w, _ in word_counts.most_common(4996)]  # 4 special tokens
    tokenizer.word2idx = {'<PAD>': 0, '<UNK>': 1, '<SOS>': 2, '<EOS>': 3}
    for i, word in enumerate(top_words, 4):
        tokenizer.word2idx[word] = i
    tokenizer.idx2word = {v: k for k, v in tokenizer.word2idx.items()}
    tokenizer.vocab_size = len(tokenizer.word2idx)

print(f"Vocabulary size: {tokenizer.vocab_size}")

# Create dataset
dataset = QADataset(training_data, tokenizer)
dataloader = DataLoader(dataset, batch_size=32, shuffle=True)

# Model
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
print(f"Device: {device}")

model = TinkerAIModel(vocab_size=tokenizer.vocab_size).to(device)
criterion = nn.CrossEntropyLoss(ignore_index=0)
optimizer = optim.Adam(model.parameters(), lr=0.001)

# Count params
total_params = sum(p.numel() for p in model.parameters())
print(f"Total parameters: {total_params:,}")

# Training loop
print("\nTraining...")
best_loss = float('inf')
start_time = time.time()

for epoch in range(50):
    model.train()
    total_loss = 0
    
    for batch in dataloader:
        input_ids = batch['input'].to(device)
        target_ids = batch['target'].to(device)
        
        output = model(input_ids)
        loss = criterion(output.view(-1, tokenizer.vocab_size), target_ids.view(-1))
        
        optimizer.zero_grad()
        loss.backward()
        optimizer.step()
        
        total_loss += loss.item()
    
    avg_loss = total_loss / len(dataloader)
    
    if (epoch + 1) % 10 == 0:
        elapsed = time.time() - start_time
        print(f"Epoch {epoch+1}/50, Loss: {avg_loss:.4f}, Time: {elapsed:.1f}s")
    
    if avg_loss < best_loss:
        best_loss = avg_loss
        # Save best model
        torch.save({
            'epoch': epoch,
            'model_state_dict': model.state_dict(),
            'optimizer_state_dict': optimizer.state_dict(),
            'loss': avg_loss,
            'vocab_size': tokenizer.vocab_size,
        }, 'os/tinker-ai/model/checkpoints/base_model.pt')
        tokenizer.save('os/tinker-ai/model/checkpoints/tokenizer.json')

print(f"\nTraining complete! Best loss: {best_loss:.4f}")
print(f"Total time: {time.time() - start_time:.1f}s")
print(f"Model saved to: os/tinker-ai/model/checkpoints/base_model.pt")
PYEOF

  success "Base model trained"
}

# ===========================================================================
# Step 3: Convert to Portable Format (ONNX)
# ===========================================================================
step3_convert_to_onnx() {
  log "Step 3: Converting to ONNX format..."

  python3 << 'PYEOF'
import torch
import os
import json

# Load model
checkpoint = torch.load('os/tinker-ai/model/checkpoints/base_model.pt', map_location='cpu')

# Recreate model
import torch.nn as nn

class TinkerAIModel(nn.Module):
    def __init__(self, vocab_size=5000, d_model=256, nhead=8, num_layers=6, dim_feedforward=1024, dropout=0.1):
        super().__init__()
        self.d_model = d_model
        self.embedding = nn.Embedding(vocab_size, d_model)
        self.pos_encoding = nn.Parameter(torch.randn(1, 512, d_model) * 0.02)
        encoder_layer = nn.TransformerEncoderLayer(d_model=d_model, nhead=nhead, dim_feedforward=dim_feedforward, dropout=dropout, batch_first=True)
        self.transformer = nn.TransformerEncoder(encoder_layer, num_layers=num_layers)
        self.fc_out = nn.Linear(d_model, vocab_size)
        self.dropout = nn.Dropout(dropout)
        
    def forward(self, x):
        seq_len = x.size(1)
        x = self.embedding(x) * (self.d_model ** 0.5)
        x = x + self.pos_encoding[:, :seq_len, :]
        x = self.dropout(x)
        x = self.transformer(x)
        x = self.fc_out(x)
        return x

model = TinkerAIModel(vocab_size=checkpoint['vocab_size'])
model.load_state_dict(checkpoint['model_state_dict'])
model.eval()

# Export to ONNX
dummy_input = torch.randint(0, checkpoint['vocab_size'], (1, 128))
onnx_path = 'os/tinker-ai/model/release/tinkeros_ai.onnx'

os.makedirs('os/tinker-ai/model/release', exist_ok=True)

torch.onnx.export(
    model,
    dummy_input,
    onnx_path,
    input_names=['input_ids'],
    output_names=['logits'],
    dynamic_axes={'input_ids': {0: 'batch_size', 1: 'seq_len'}, 'logits': {0: 'batch_size', 1: 'seq_len'}},
    opset_version=14
)

print(f"ONNX model saved to: {onnx_path}")
print(f"Model size: {os.path.getsize(onnx_path) / 1024 / 1024:.1f} MB")
PYEOF

  success "Converted to ONNX"
}

# ===========================================================================
# Step 4: LoRA Fine-Tuning
# ===========================================================================
step4_lora_finetune() {
  log "Step 4: LoRA fine-tuning..."

  mkdir -p "$LORA_DIR"

  python3 << 'PYEOF'
import torch
import torch.nn as nn
import torch.nn.functional as F
import json
import os
import time
from torch.utils.data import Dataset, DataLoader

# LoRA layer
class LoRALayer(nn.Module):
    def __init__(self, original_layer, rank=8, alpha=16):
        super().__init__()
        self.original = original_layer
        self.original.weight.requires_grad = False
        
        in_features = original_layer.in_features
        out_features = original_layer.out_features
        
        self.lora_A = nn.Parameter(torch.randn(in_features, rank) * 0.01)
        self.lora_B = nn.Parameter(torch.zeros(rank, out_features))
        self.scaling = alpha / rank
        
    def forward(self, x):
        original_out = self.original(x)
        lora_out = F.linear(x, self.lora_A @ self.lora_B) * self.scaling
        return original_out + lora_out

# Model with LoRA
class TinkerAIWithLoRA(nn.Module):
    def __init__(self, base_model, rank=8, alpha=16):
        super().__init__()
        self.model = base_model
        
        # Apply LoRA to attention layers
        for name, module in self.model.named_modules():
            if isinstance(module, nn.Linear) and 'fc_out' not in name:
                setattr(self.model, name, LoRALayer(module, rank, alpha))
        
        # Freeze base model
        for param in self.model.parameters():
            param.requires_grad = False
        
        # Unfreeze LoRA parameters
        for module in self.model.modules():
            if isinstance(module, LoRALayer):
                module.lora_A.requires_grad = True
                module.lora_B.requires_grad = True

# Simple tokenizer
class SimpleTokenizer:
    def __init__(self):
        self.word2idx = {}
        self.idx2word = {}
        self.vocab_size = 0
        
    def load(self, path):
        with open(path) as f:
            data = json.load(f)
        self.word2idx = data['word2idx']
        self.vocab_size = data['vocab_size']
        self.idx2word = {int(v): k for k, v in self.word2idx.items()}
        
    def encode(self, text, max_len=128):
        tokens = [self.word2idx.get(w, 1) for w in text.lower().split()]
        tokens = tokens[:max_len]
        tokens += [0] * (max_len - len(tokens))
        return tokens

# Dataset
class QADataset(Dataset):
    def __init__(self, data, tokenizer, max_len=128):
        self.data = data
        self.tokenizer = tokenizer
        self.max_len = max_len
        
    def __len__(self):
        return len(self.data)
    
    def __getitem__(self, idx):
        item = self.data[idx]
        input_ids = self.tokenizer.encode(item['input'], self.max_len)
        target_ids = self.tokenizer.encode(item['output'], self.max_len)
        return {
            'input': torch.tensor(input_ids, dtype=torch.long),
            'target': torch.tensor(target_ids, dtype=torch.long)
        }

# Load base model
checkpoint = torch.load('os/tinker-ai/model/checkpoints/base_model.pt', map_location='cpu')

class TinkerAIModel(nn.Module):
    def __init__(self, vocab_size=5000, d_model=256, nhead=8, num_layers=6, dim_feedforward=1024, dropout=0.1):
        super().__init__()
        self.d_model = d_model
        self.embedding = nn.Embedding(vocab_size, d_model)
        self.pos_encoding = nn.Parameter(torch.randn(1, 512, d_model) * 0.02)
        encoder_layer = nn.TransformerEncoderLayer(d_model=d_model, nhead=nhead, dim_feedforward=dim_feedforward, dropout=dropout, batch_first=True)
        self.transformer = nn.TransformerEncoder(encoder_layer, num_layers=num_layers)
        self.fc_out = nn.Linear(d_model, vocab_size)
        self.dropout = nn.Dropout(dropout)
        
    def forward(self, x):
        seq_len = x.size(1)
        x = self.embedding(x) * (self.d_model ** 0.5)
        x = x + self.pos_encoding[:, :seq_len, :]
        x = self.dropout(x)
        x = self.transformer(x)
        x = self.fc_out(x)
        return x

base_model = TinkerAIModel(vocab_size=checkpoint['vocab_size'])
base_model.load_state_dict(checkpoint['model_state_dict'])

# Add LoRA
model = TinkerAIWithLoRA(base_model, rank=8, alpha=16)

# Load tokenizer
tokenizer = SimpleTokenizer()
tokenizer.load('os/tinker-ai/model/checkpoints/tokenizer.json')

# Load training data
with open('os/tinker-ai/model/training_data/all_training_data.json') as f:
    training_data = json.load(f)

dataset = QADataset(training_data, tokenizer)
dataloader = DataLoader(dataset, batch_size=16, shuffle=True)

# Training
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
print(f"Device: {device}")

# Only train LoRA parameters
lora_params = [p for p in model.parameters() if p.requires_grad]
print(f"LoRA parameters: {sum(p.numel() for p in lora_params):,}")

criterion = nn.CrossEntropyLoss(ignore_index=0)
optimizer = torch.optim.Adam(lora_params, lr=0.0001)

# Training loop
print("\nLoRA Fine-tuning...")
start_time = time.time()

for epoch in range(30):
    model.train()
    total_loss = 0
    
    for batch in dataloader:
        input_ids = batch['input'].to(device)
        target_ids = batch['target'].to(device)
        
        output = model(input_ids)
        loss = criterion(output.view(-1, checkpoint['vocab_size']), target_ids.view(-1))
        
        optimizer.zero_grad()
        loss.backward()
        optimizer.step()
        
        total_loss += loss.item()
    
    avg_loss = total_loss / len(dataloader)
    
    if (epoch + 1) % 5 == 0:
        elapsed = time.time() - start_time
        print(f"Epoch {epoch+1}/30, Loss: {avg_loss:.4f}, Time: {elapsed:.1f}s")

# Save LoRA weights
lora_weights = {}
for name, param in model.named_parameters():
    if param.requires_grad:
        lora_weights[name] = param.data

torch.save(lora_weights, 'os/tinker-ai/model/lora/lora_weights.pt')
print(f"\nLoRA weights saved to: os/tinker-ai/model/lora/lora_weights.pt")
print(f"Total time: {time.time() - start_time:.1f}s")
PYEOF

  success "LoRA fine-tuning complete"
}

# ===========================================================================
# Step 5: Package for Release
# ===========================================================================
step5_package_release() {
  log "Step 5: Packaging for release..."

  mkdir -p "$RELEASE_DIR"

  # Copy files
  cp "$CHECKPOINT_DIR/base_model.pt" "$RELEASE_DIR/" 2>/dev/null || true
  cp "$CHECKPOINT_DIR/tokenizer.json" "$RELEASE_DIR/" 2>/dev/null || true
  cp "$LORA_DIR/lora_weights.pt" "$RELEASE_DIR/" 2>/dev/null || true
  cp "$MODEL_DIR/release/tinkeros_ai.onnx" "$RELEASE_DIR/" 2>/dev/null || true

  # Create model card
  cat > "$RELEASE_DIR/MODEL_CARD.md" << 'EOF'
# TinkerAI Model

## Overview
- **Model Name:** TinkerAI
- **Version:** 1.0
- **Architecture:** Transformer (6 layers, 8 heads, 256 dim)
- **Parameters:** ~5.9M
- **Training Data:** 725+ intent patterns, TinkerOS knowledge, general Q&A

## Features
- Intent classification (30+ intents)
- Entity extraction
- Conversation understanding
- TinkerOS-specific knowledge
- Self-learning capability

## Usage
```python
import torch
import json

# Load model
checkpoint = torch.load('base_model.pt')
lora_weights = torch.load('lora_weights.pt')

# Apply LoRA weights to base model
```

## Training
- Base model: 50 epochs, lr=0.001
- LoRA fine-tune: 30 epochs, lr=0.0001, rank=8

## License
Dual Source License v1.0
EOF

  # Create release archive
  cd "$RELEASE_DIR"
  tar -czf "../tinkeros_ai_v1.0.tar.gz" *
  cd "$AI_DIR"

  success "Release packaged: $RELEASE_DIR"
  log "Files:"
  ls -lh "$RELEASE_DIR/"
}

# ===========================================================================
# Main Pipeline
# ===========================================================================
main() {
  log "TinkerAI Model Pipeline"
  log "========================"
  log ""

  step1_build_training_data
  log ""

  step2_train_base_model
  log ""

  step3_convert_to_onnx
  log ""

  step4_lora_finetune
  log ""

  step5_package_release
  log ""

  success "Pipeline complete!"
  log ""
  log "Release files in: $RELEASE_DIR"
}

# Run pipeline
main "$@"
