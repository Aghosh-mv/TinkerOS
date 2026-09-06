#!/usr/bin/env python3
"""
TinkerOS AI Training Script
Trains a small neural network for voice command recognition
"""

import json
import os
import re
import pickle
from collections import Counter
from typing import List, Dict, Tuple
import random

class SimpleTokenizer:
    """Simple word tokenizer for training"""
    
    def __init__(self, vocab_size=5000):
        self.vocab_size = vocab_size
        self.word_to_idx = {"<PAD>": 0, "<UNK>": 1}
        self.idx_to_word = {0: "<PAD>", 1: "<UNK>"}
    
    def fit(self, texts: List[str]):
        word_counts = Counter()
        for text in texts:
            words = self.tokenize(text)
            word_counts.update(words)
        
        for word, _ in word_counts.most_common(self.vocab_size - 2):
            idx = len(self.word_to_idx)
            self.word_to_idx[word] = idx
            self.idx_to_word[idx] = word
    
    def tokenize(self, text: str) -> List[str]:
        text = text.lower().strip()
        text = re.sub(r'[^\w\s]', ' ', text)
        return text.split()
    
    def encode(self, text: str, max_length: int = 32) -> List[int]:
        tokens = self.tokenize(text)
        indices = [self.word_to_idx.get(t, 1) for t in tokens[:max_length]]
        indices += [0] * (max_length - len(indices))
        return indices
    
    def save(self, path: str):
        with open(path, 'wb') as f:
            pickle.dump({
                'vocab_size': self.vocab_size,
                'word_to_idx': self.word_to_idx,
                'idx_to_word': self.idx_to_word
            }, f)
    
    def load(self, path: str):
        with open(path, 'rb') as f:
            data = pickle.load(f)
            self.vocab_size = data['vocab_size']
            self.word_to_idx = data['word_to_idx']
            self.idx_to_word = data['idx_to_word']


class SimpleNeuralNetwork:
    """Simple neural network for classification"""
    
    def __init__(self, vocab_size: int, embed_dim: int, num_classes: int):
        self.vocab_size = vocab_size
        self.embed_dim = embed_dim
        self.num_classes = num_classes
        
        # Initialize weights
        self.embedding = [[random.gauss(0, 0.1) for _ in range(embed_dim)] 
                          for _ in range(vocab_size)]
        
        hidden_dim = 128
        self.W1 = [[random.gauss(0, 0.1) for _ in range(hidden_dim)] 
                    for _ in range(embed_dim)]
        self.b1 = [0.0] * hidden_dim
        
        self.W2 = [[random.gauss(0, 0.1) for _ in range(num_classes)] 
                    for _ in range(hidden_dim)]
        self.b2 = [0.0] * num_classes
    
    def relu(self, x):
        return max(0, x)
    
    def softmax(self, x):
        max_x = max(x)
        exp_x = [2.71828 ** (xi - max_x) for xi in x]
        sum_exp = sum(exp_x)
        return [ei / sum_exp for ei in exp_x]
    
    def forward(self, tokens: List[int]) -> List[float]:
        # Embedding
        embed = [0.0] * self.embed_dim
        for idx in tokens:
            if idx < len(self.embedding):
                for j in range(self.embed_dim):
                    embed[j] += self.embedding[idx][j]
        
        # Normalize
        count = sum(1 for t in tokens if t > 0)
        if count > 0:
            embed = [e / count for e in embed]
        
        # Hidden layer
        hidden = []
        for j in range(len(self.b1)):
            h = self.b1[j]
            for i in range(self.embed_dim):
                h += embed[i] * self.W1[i][j]
            hidden.append(self.relu(h))
        
        # Output layer
        output = []
        for j in range(self.num_classes):
            o = self.b2[j]
            for i in range(len(self.b1)):
                o += hidden[i] * self.W2[i][j]
            output.append(o)
        
        return self.softmax(output)
    
    def train_step(self, tokens: List[int], label: int, lr: float = 0.01):
        # Forward pass
        embed = [0.0] * self.embed_dim
        for idx in tokens:
            if idx < len(self.embedding):
                for j in range(self.embed_dim):
                    embed[j] += self.embedding[idx][j]
        
        count = sum(1 for t in tokens if t > 0)
        if count > 0:
            embed = [e / count for e in embed]
        
        hidden = []
        for j in range(len(self.b1)):
            h = self.b1[j]
            for i in range(self.embed_dim):
                h += embed[i] * self.W1[i][j]
            hidden.append(self.relu(h))
        
        output = []
        for j in range(self.num_classes):
            o = self.b2[j]
            for i in range(len(self.b1)):
                o += hidden[i] * self.W2[i][j]
            output.append(o)
        
        probs = self.softmax(output)
        
        # Backward pass
        d_output = [probs[j] - (1 if j == label else 0) for j in range(self.num_classes)]
        
        d_hidden = [0.0] * len(self.b1)
        for i in range(len(self.b1)):
            for j in range(self.num_classes):
                d_hidden[i] += d_output[j] * self.W2[i][j]
            d_hidden[i] *= (1 if hidden[i] > 0 else 0)
        
        # Update weights
        for i in range(len(self.b1)):
            for j in range(self.num_classes):
                self.W2[i][j] -= lr * d_output[j] * hidden[i]
        
        for j in range(self.num_classes):
            self.b2[j] -= lr * d_output[j]
        
        for i in range(self.embed_dim):
            for j in range(len(self.b1)):
                self.W1[i][j] -= lr * d_hidden[j] * embed[i]
        
        for j in range(len(self.b1)):
            self.b1[j] -= lr * d_hidden[j]
        
        # Update embeddings
        for idx in tokens:
            if idx < len(self.embedding):
                for j in range(self.embed_dim):
                    self.embedding[idx][j] -= lr * d_hidden[j % len(d_hidden)]
    
    def predict(self, tokens: List[int]) -> Tuple[int, float]:
        probs = self.forward(tokens)
        max_idx = probs.index(max(probs))
        return max_idx, probs[max_idx]
    
    def save(self, path: str):
        with open(path, 'wb') as f:
            pickle.dump({
                'vocab_size': self.vocab_size,
                'embed_dim': self.embed_dim,
                'num_classes': self.num_classes,
                'embedding': self.embedding,
                'W1': self.W1, 'b1': self.b1,
                'W2': self.W2, 'b2': self.b2
            }, f)
    
    def load(self, path: str):
        with open(path, 'rb') as f:
            data = pickle.load(f)
            self.vocab_size = data['vocab_size']
            self.embed_dim = data['embed_dim']
            self.num_classes = data['num_classes']
            self.embedding = data['embedding']
            self.W1 = data['W1']
            self.b1 = data['b1']
            self.W2 = data['W2']
            self.b2 = data['b2']


def load_dataset(data_dir: str) -> Tuple[List[str], List[int], Dict]:
    """Load dataset from JSONL"""
    texts = []
    labels = []
    action_map = {}
    
    with open(os.path.join(data_dir, "dataset.jsonl")) as f:
        for line in f:
            item = json.loads(line)
            texts.append(item["input"])
            
            if item["action"] not in action_map:
                action_map[item["action"]] = len(action_map)
            
            labels.append(action_map[item["action"]])
    
    return texts, labels, action_map


def train(data_dir: str, output_dir: str, epochs: int = 10, lr: float = 0.01):
    """Train the model"""
    
    print("Loading dataset...")
    texts, labels, action_map = load_dataset(data_dir)
    print(f"Loaded {len(texts)} samples, {len(action_map)} classes")
    
    # Create tokenizer
    print("Creating tokenizer...")
    tokenizer = SimpleTokenizer(vocab_size=5000)
    tokenizer.fit(texts)
    
    # Encode texts
    print("Encoding texts...")
    encoded = [tokenizer.encode(t) for t in texts]
    
    # Create model
    print("Creating model...")
    model = SimpleNeuralNetwork(
        vocab_size=5000,
        embed_dim=64,
        num_classes=len(action_map)
    )
    
    # Training loop
    print(f"Training for {epochs} epochs...")
    batch_size = 32
    
    for epoch in range(epochs):
        # Shuffle data
        indices = list(range(len(texts)))
        random.shuffle(indices)
        
        total_loss = 0
        correct = 0
        
        for i in range(0, len(indices), batch_size):
            batch_indices = indices[i:i+batch_size]
            
            for idx in batch_indices:
                tokens = encoded[idx]
                label = labels[idx]
                
                # Predict before training
                pred, _ = model.predict(tokens)
                if pred == label:
                    correct += 1
                
                # Train
                model.train_step(tokens, label, lr)
        
        accuracy = correct / len(texts) * 100
        print(f"Epoch {epoch+1}/{epochs} - Accuracy: {accuracy:.2f}%")
    
    # Save model
    print("Saving model...")
    os.makedirs(output_dir, exist_ok=True)
    
    tokenizer.save(os.path.join(output_dir, "tokenizer.pkl"))
    model.save(os.path.join(output_dir, "model.pkl"))
    
    with open(os.path.join(output_dir, "actions.json"), "w") as f:
        json.dump(action_map, f, indent=2)
    
    print(f"Model saved to {output_dir}")
    print("Training complete!")


if __name__ == "__main__":
    train(
        data_dir="/home/tinkerspace/linux-kernel/os/ai/training-data",
        output_dir="/home/tinkerspace/linux-kernel/os/ai/model",
        epochs=3,
        lr=0.01
    )
