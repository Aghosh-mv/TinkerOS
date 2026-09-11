#!/usr/bin/env python3
"""
TinkerAI Tokenizer — converts text to tokens and back
Supports both character-level and word-level tokenization
"""

import json
import re
from collections import Counter

class TinkerTokenizer:
    """Simple but effective tokenizer for TinkerAI"""
    
    SPECIAL_TOKENS = {
        '<PAD>': 0,
        '<UNK>': 1,
        '<BOS>': 2,
        '<EOS>': 3,
        '<SEP>': 4,
        '<Q>': 5,
        '<A>': 6,
    }
    
    def __init__(self, vocab_size=8000):
        self.vocab_size = vocab_size
        self.token_to_id = dict(self.SPECIAL_TOKENS)
        self.id_to_token = {v: k for k, v in self.token_to_id.items()}
        self.trained = False
    
    def train(self, texts):
        """Build vocabulary from training texts"""
        counter = Counter()
        for text in texts:
            tokens = self._tokenize_raw(text)
            counter.update(tokens)
        
        # Add most common tokens up to vocab_size
        for token, _ in counter.most_common(self.vocab_size - len(self.SPECIAL_TOKENS)):
            if token not in self.token_to_id:
                idx = len(self.token_to_id)
                self.token_to_id[token] = idx
                self.id_to_token[idx] = token
        
        self.trained = True
        print(f"Tokenizer trained: {len(self.token_to_id)} tokens")
    
    def _tokenize_raw(self, text):
        """Raw tokenization: split into words and subwords"""
        text = text.lower().strip()
        # Split on whitespace and punctuation
        tokens = re.findall(r'\b\w+\b|[^\w\s]', text)
        return tokens
    
    def encode(self, text, max_len=None, add_special=True):
        """Convert text to token IDs"""
        tokens = self._tokenize_raw(text)
        
        if add_special:
            tokens = ['<BOS>'] + tokens + ['<EOS>']
        
        ids = [self.token_to_id.get(t, self.token_to_id['<UNK>']) for t in tokens]
        
        if max_len is not None:
            if len(ids) > max_len:
                ids = ids[:max_len]
            else:
                ids += [self.token_to_id['<PAD>']] * (max_len - len(ids))
        
        return ids
    
    def decode(self, ids):
        """Convert token IDs back to text"""
        tokens = []
        for id in ids:
            token = self.id_to_token.get(id, '<UNK>')
            if token in ('<PAD>', '<BOS>', '<EOS>'):
                continue
            tokens.append(token)
        
        # Reconstruct text
        text = ' '.join(tokens)
        # Fix spacing around punctuation
        text = re.sub(r'\s([.,!?;:])', r'\1', text)
        text = re.sub(r'\s+', ' ', text)
        return text.strip()
    
    def save(self, path):
        data = {
            'vocab_size': self.vocab_size,
            'token_to_id': self.token_to_id,
        }
        with open(path, 'w') as f:
            json.dump(data, f)
    
    @classmethod
    def load(cls, path):
        with open(path) as f:
            data = json.load(f)
        tok = cls(data['vocab_size'])
        tok.token_to_id = data['token_to_id']
        tok.id_to_token = {int(v): k for k, v in tok.token_to_id.items()}
        tok.trained = True
        return tok


class QAPair:
    """A question-answer training pair"""
    def __init__(self, question, answer, intent="general"):
        self.question = question
        self.answer = answer
        self.intent = intent
    
    def to_prompt(self):
        return f"<Q> {self.question} <A> {self.answer}"
    
    def __repr__(self):
        return f"QA({self.question[:30]}... -> {self.answer[:30]}...)"
