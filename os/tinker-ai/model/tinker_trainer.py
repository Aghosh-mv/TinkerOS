#!/usr/bin/env python3
"""
TinkerAI Training Pipeline — trains the neural network on Q&A data
Supports: pretraining on text, fine-tuning on Q&A pairs, intent classification
"""

import os
import sys
import json
import torch
import torch.nn as nn
from torch.utils.data import Dataset, DataLoader
from torch.optim import AdamW
from torch.optim.lr_scheduler import CosineAnnealingLR
import time

# Add parent to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tinker_model import TinkerModel
from tinker_tokenizer import TinkerTokenizer, QAPair


class QADataset(Dataset):
    """Dataset for question-answer pairs"""
    
    def __init__(self, qa_pairs, tokenizer, max_len=256):
        self.pairs = qa_pairs
        self.tokenizer = tokenizer
        self.max_len = max_len
    
    def __len__(self):
        return len(self.pairs)
    
    def __getitem__(self, idx):
        pair = self.pairs[idx]
        prompt = f"<Q> {pair.question} <A> {pair.answer}"
        ids = self.tokenizer.encode(prompt, max_len=self.max_len, add_special=False)
        
        input_ids = torch.tensor(ids[:-1], dtype=torch.long)
        targets = torch.tensor(ids[1:], dtype=torch.long)
        
        return input_ids, targets


class TextDataset(Dataset):
    """Dataset for raw text (pretraining)"""
    
    def __init__(self, texts, tokenizer, max_len=256, chunk_size=128):
        self.chunks = []
        for text in texts:
            ids = tokenizer.encode(text, add_special=True)
            for i in range(0, len(ids) - chunk_size, chunk_size // 2):
                self.chunks.append(ids[i:i + chunk_size])
        self.tokenizer = tokenizer
    
    def __len__(self):
        return len(self.chunks)
    
    def __getitem__(self, idx):
        ids = self.chunks[idx]
        input_ids = torch.tensor(ids[:-1], dtype=torch.long)
        targets = torch.tensor(ids[1:], dtype=torch.long)
        return input_ids, targets


class TinkerTrainer:
    """Training pipeline for TinkerAI"""
    
    def __init__(self, model_dir=None):
        self.model_dir = model_dir or os.path.join(os.path.dirname(__file__), 'checkpoints')
        os.makedirs(self.model_dir, exist_ok=True)
        
        self.device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
        self.tokenizer = TinkerTokenizer(vocab_size=8000)
        self.model = None
        self.history = []
    
    def load_training_data(self, data_dir):
        """Load Q&A pairs and text data from directory"""
        qa_pairs = []
        texts = []
        
        # Load Q&A files
        for fname in os.listdir(data_dir):
            fpath = os.path.join(data_dir, fname)
            if fname.endswith('.json'):
                with open(fpath) as f:
                    data = json.load(f)
                    if isinstance(data, list):
                        for item in data:
                            if 'question' in item and 'answer' in item:
                                qa_pairs.append(QAPair(
                                    item['question'],
                                    item['answer'],
                                    item.get('intent', 'general')
                                ))
            elif fname.endswith('.txt') or fname.endswith('.md'):
                with open(fpath) as f:
                    texts.append(f.read())
        
        print(f"Loaded {len(qa_pairs)} Q&A pairs and {len(texts)} text files")
        return qa_pairs, texts
    
    def train(self, qa_pairs, texts=None, epochs=20, lr=3e-4, batch_size=8, max_len=256):
        """Full training pipeline"""
        
        print(f"\n{'='*60}")
        print(f"  TinkerAI Training Pipeline")
        print(f"  Device: {self.device}")
        print(f"  Q&A pairs: {len(qa_pairs)}")
        print(f"  Epochs: {epochs}")
        print(f"{'='*60}\n")
        
        # Step 1: Train tokenizer
        print("[1/4] Training tokenizer...")
        all_texts = [f"<Q> {p.question} <A> {p.answer}" for p in qa_pairs]
        if texts:
            all_texts.extend(texts)
        self.tokenizer.train(all_texts)
        
        # Step 2: Create model
        print("[2/4] Creating model...")
        vocab_size = len(self.tokenizer.token_to_id)
        self.model = TinkerModel(
            vocab_size=vocab_size,
            d_model=256,
            n_heads=8,
            n_layers=6,
            d_ff=1024,
            max_len=max_len
        ).to(self.device)
        
        param_count = self.model.count_parameters()
        print(f"  Model: {param_count:,} parameters")
        
        # Step 3: Create dataset and dataloader
        print("[3/4] Preparing data...")
        dataset = QADataset(qa_pairs, self.tokenizer, max_len=max_len)
        dataloader = DataLoader(dataset, batch_size=batch_size, shuffle=True, drop_last=True)
        
        # Step 4: Train
        print("[4/4] Training...")
        optimizer = AdamW(self.model.parameters(), lr=lr, weight_decay=0.01)
        scheduler = CosineAnnealingLR(optimizer, T_max=epochs)
        
        best_loss = float('inf')
        self.history = []
        
        for epoch in range(epochs):
            self.model.train()
            total_loss = 0
            n_batches = 0
            start_time = time.time()
            
            for batch_idx, (input_ids, targets) in enumerate(dataloader):
                input_ids = input_ids.to(self.device)
                targets = targets.to(self.device)
                
                logits, loss = self.model(input_ids, targets)
                
                optimizer.zero_grad()
                loss.backward()
                torch.nn.utils.clip_grad_norm_(self.model.parameters(), 1.0)
                optimizer.step()
                
                total_loss += loss.item()
                n_batches += 1
            
            scheduler.step()
            avg_loss = total_loss / max(n_batches, 1)
            elapsed = time.time() - start_time
            
            self.history.append({
                'epoch': epoch + 1,
                'loss': avg_loss,
                'lr': scheduler.get_last_lr()[0],
                'time': elapsed
            })
            
            # Save best model
            if avg_loss < best_loss:
                best_loss = avg_loss
                self.save_checkpoint('best')
            
            # Print progress
            if (epoch + 1) % 5 == 0 or epoch == 0:
                print(f"  Epoch {epoch+1}/{epochs} | Loss: {avg_loss:.4f} | Best: {best_loss:.4f} | LR: {scheduler.get_last_lr()[0]:.6f} | {elapsed:.1f}s")
        
        # Save final model
        self.save_checkpoint('final')
        self.tokenizer.save(os.path.join(self.model_dir, 'tokenizer.json'))
        
        print(f"\nTraining complete! Best loss: {best_loss:.4f}")
        print(f"Model saved to: {self.model_dir}")
        
        return self.history
    
    def save_checkpoint(self, name):
        path = os.path.join(self.model_dir, f'{name}.pt')
        self.model.save(path)
    
    def load_model(self, name='best'):
        path = os.path.join(self.model_dir, f'{name}.pt')
        tok_path = os.path.join(self.model_dir, 'tokenizer.json')
        
        if os.path.exists(path):
            self.model = TinkerModel.load(path).to(self.device)
            if os.path.exists(tok_path):
                self.tokenizer = TinkerTokenizer.load(tok_path)
            print(f"Model loaded from {path}")
            print(f"Parameters: {self.model.count_parameters():,}")
            return True
        return False
    
    @torch.no_grad()
    def generate(self, question, max_new_tokens=150, temperature=0.7, top_k=40):
        """Generate an answer to a question"""
        self.model.eval()
        
        prompt = f"<Q> {question} <A>"
        ids = self.tokenizer.encode(prompt, add_special=False)
        input_ids = torch.tensor([ids], dtype=torch.long).to(self.device)
        
        output = self.model.generate(
            input_ids,
            max_new_tokens=max_new_tokens,
            temperature=temperature,
            top_k=top_k
        )
        
        answer = self.tokenizer.decode(output[0].tolist())
        # Extract just the answer part
        if '<A>' in answer:
            answer = answer.split('<A>')[-1].strip()
        
        return answer
    
    def interactive(self):
        """Interactive chat mode"""
        print("\nTinkerAI Chat (type 'quit' to exit)")
        print("=" * 40)
        
        while True:
            question = input("\nYou: ").strip()
            if question.lower() in ('quit', 'exit', 'bye'):
                print("Goodbye!")
                break
            
            if not question:
                continue
            
            answer = self.generate(question)
            print(f"\nTinkerAI: {answer}")


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description='TinkerAI Trainer')
    parser.add_argument('--data', type=str, default='training_data', help='Training data directory')
    parser.add_argument('--epochs', type=int, default=20)
    parser.add_argument('--lr', type=float, default=3e-4)
    parser.add_argument('--batch-size', type=int, default=8)
    parser.add_argument('--chat', action='store_true', help='Interactive chat mode')
    parser.add_argument('--model-dir', type=str, default='checkpoints')
    args = parser.parse_args()
    
    trainer = TinkerTrainer(args.model_dir)
    
    if args.chat:
        trainer.load_model()
        trainer.interactive()
    else:
        qa_pairs, texts = trainer.load_training_data(args.data)
        if qa_pairs:
            trainer.train(qa_pairs, texts, epochs=args.epochs, lr=args.lr, batch_size=args.batch_size)
        else:
            print("No training data found. Add Q&A pairs to the training_data/ directory.")
