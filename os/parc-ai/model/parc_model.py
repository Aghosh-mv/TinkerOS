#!/usr/bin/env python3
"""
TinkerAI Neural Network — Small Transformer Language Model
Inspired by GPT/BERT architecture but much smaller (~5-10M parameters)
Can answer questions, generate text, and have conversations.
"""

import torch
import torch.nn as nn
import torch.nn.functional as F
import math

class MultiHeadAttention(nn.Module):
    """Multi-head self-attention — the core of transformer models"""
    def __init__(self, d_model, n_heads, dropout=0.1):
        super().__init__()
        self.n_heads = n_heads
        self.d_k = d_model // n_heads
        self.q = nn.Linear(d_model, d_model)
        self.k = nn.Linear(d_model, d_model)
        self.v = nn.Linear(d_model, d_model)
        self.out = nn.Linear(d_model, d_model)
        self.dropout = nn.Dropout(dropout)
    
    def forward(self, x, mask=None):
        B, L, D = x.shape
        Q = self.q(x).view(B, L, self.n_heads, self.d_k).transpose(1, 2)
        K = self.k(x).view(B, L, self.n_heads, self.d_k).transpose(1, 2)
        V = self.v(x).view(B, L, self.n_heads, self.d_k).transpose(1, 2)
        
        scores = torch.matmul(Q, K.transpose(-2, -1)) / math.sqrt(self.d_k)
        if mask is not None:
            scores = scores.masked_fill(mask == 0, -1e9)
        attn = F.softmax(scores, dim=-1)
        attn = self.dropout(attn)
        
        out = torch.matmul(attn, V)
        out = out.transpose(1, 2).contiguous().view(B, L, D)
        return self.out(out)


class FeedForward(nn.Module):
    """Feed-forward network — processes attention output"""
    def __init__(self, d_model, d_ff, dropout=0.1):
        super().__init__()
        self.linear1 = nn.Linear(d_model, d_ff)
        self.linear2 = nn.Linear(d_ff, d_model)
        self.dropout = nn.Dropout(dropout)
    
    def forward(self, x):
        return self.linear2(self.dropout(F.gelu(self.linear1(x))))


class TransformerBlock(nn.Module):
    """Single transformer block: attention + feed-forward"""
    def __init__(self, d_model, n_heads, d_ff, dropout=0.1):
        super().__init__()
        self.attention = MultiHeadAttention(d_model, n_heads, dropout)
        self.ff = FeedForward(d_model, d_ff, dropout)
        self.norm1 = nn.LayerNorm(d_model)
        self.norm2 = nn.LayerNorm(d_model)
        self.dropout = nn.Dropout(dropout)
    
    def forward(self, x, mask=None):
        x = x + self.dropout(self.attention(self.norm1(x), mask))
        x = x + self.dropout(self.ff(self.norm2(x)))
        return x


class TinkerModel(nn.Module):
    """
    TinkerAI Transformer Language Model
    
    Architecture (like GPT but smaller):
    - Token embeddings + positional encoding
    - Multiple transformer blocks (attention + feed-forward)
    - Language model head (predicts next token)
    
    Can be used for:
    - Text generation (answering questions)
    - Text classification (understanding intent)
    - Embeddings (understanding meaning)
    """
    
    def __init__(self, vocab_size, d_model=256, n_heads=8, n_layers=6, 
                 d_ff=1024, max_len=512, dropout=0.1, num_classes=0):
        super().__init__()
        self.d_model = d_model
        self.max_len = max_len
        
        # Token and position embeddings
        self.token_embed = nn.Embedding(vocab_size, d_model)
        self.pos_embed = nn.Embedding(max_len, d_model)
        self.dropout = nn.Dropout(dropout)
        
        # Transformer blocks
        self.blocks = nn.ModuleList([
            TransformerBlock(d_model, n_heads, d_ff, dropout)
            for _ in range(n_layers)
        ])
        
        self.norm = nn.LayerNorm(d_model)
        
        # Language model head (predict next token)
        self.lm_head = nn.Linear(d_model, vocab_size)
        
        # Optional classification head
        self.num_classes = num_classes
        if num_classes > 0:
            self.classifier = nn.Linear(d_model, num_classes)
        
        # Initialize weights
        self._init_weights()
    
    def _init_weights(self):
        for p in self.parameters():
            if p.dim() > 1:
                nn.init.xavier_uniform_(p)
    
    def forward(self, input_ids, targets=None, labels=None):
        B, L = input_ids.shape
        positions = torch.arange(0, L, device=input_ids.device).unsqueeze(0).expand(B, -1)
        
        x = self.token_embed(input_ids) + self.pos_embed(positions)
        x = self.dropout(x)
        
        # Causal mask (can't look ahead)
        mask = torch.tril(torch.ones(L, L, device=input_ids.device)).unsqueeze(0).unsqueeze(0)
        
        for block in self.blocks:
            x = block(x, mask)
        
        x = self.norm(x)
        
        # Language modeling loss
        logits = self.lm_head(x)
        loss = None
        if targets is not None:
            loss = F.cross_entropy(logits.view(-1, logits.size(-1)), targets.view(-1))
        
        # Classification (if needed)
        cls_logits = None
        cls_loss = None
        if self.num_classes > 0 and labels is not None:
            # Use [CLS] token (first position) representation
            cls_logits = self.classifier(x[:, 0])
            cls_loss = F.cross_entropy(cls_logits, labels)
            if loss is not None:
                loss = loss + cls_loss
        
        return logits, loss
    
    @torch.no_grad()
    def generate(self, input_ids, max_new_tokens=100, temperature=0.8, top_k=40):
        """Generate text token by token"""
        self.eval()
        for _ in range(max_new_tokens):
            # Crop to max_len
            idx_cond = input_ids[:, -self.max_len:]
            logits, _ = self(idx_cond)
            logits = logits[:, -1, :] / temperature
            
            # Top-k filtering
            if top_k > 0:
                v, _ = torch.topk(logits, min(top_k, logits.size(-1)))
                logits[logits < v[:, [-1]]] = -float('inf')
            
            probs = F.softmax(logits, dim=-1)
            idx_next = torch.multinomial(probs, num_samples=1)
            input_ids = torch.cat([input_ids, idx_next], dim=1)
        
        return input_ids
    
    def count_parameters(self):
        return sum(p.numel() for p in self.parameters() if p.requires_grad)
    
    def save(self, path):
        torch.save({
            'model_state': self.state_dict(),
            'config': {
                'vocab_size': self.token_embed.num_embeddings,
                'd_model': self.d_model,
                'n_heads': self.blocks[0].attention.n_heads,
                'n_layers': len(self.blocks),
                'd_ff': self.blocks[0].ff.linear1.out_features,
                'max_len': self.max_len,
                'num_classes': self.num_classes,
            }
        }, path)
    
    @classmethod
    def load(cls, path):
        data = torch.load(path, weights_only=False)
        config = data['config']
        model = cls(**config)
        model.load_state_dict(data['model_state'])
        return model


class TinkerClassifier(nn.Module):
    """
    Intent classifier — figures out what the user wants
    Uses the transformer backbone for understanding
    """
    def __init__(self, base_model, num_intents):
        super().__init__()
        self.base = base_model
        d_model = base_model.d_model
        self.intent_head = nn.Sequential(
            nn.Linear(d_model, d_model // 2),
            nn.GELU(),
            nn.Dropout(0.1),
            nn.Linear(d_model // 2, num_intents)
        )
    
    def forward(self, input_ids):
        B, L = input_ids.shape
        positions = torch.arange(0, L, device=input_ids.device).unsqueeze(0).expand(B, -1)
        x = self.base.token_embed(input_ids) + self.base.pos_embed(positions)
        mask = torch.tril(torch.ones(L, L, device=input_ids.device)).unsqueeze(0).unsqueeze(0)
        for block in self.base.blocks:
            x = block(x, mask)
        x = self.base.norm(x)
        # Pool: mean of all tokens
        pooled = x.mean(dim=1)
        return self.intent_head(pooled)


if __name__ == "__main__":
    # Test model creation
    model = TinkerModel(vocab_size=10000, d_model=256, n_heads=8, n_layers=6, d_ff=1024)
    print(f"Model created: {model.count_parameters():,} parameters")
    
    # Test forward pass
    x = torch.randint(0, 10000, (2, 128))
    logits, loss = model(x, targets=x)
    print(f"Forward pass: logits shape={logits.shape}, loss={loss.item():.4f}")
    
    # Test generation
    prompt = torch.randint(0, 10000, (1, 10))
    generated = model.generate(prompt, max_new_tokens=20)
    print(f"Generated: {generated.shape}")
