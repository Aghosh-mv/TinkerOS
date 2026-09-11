#!/usr/bin/env python3
"""
TinkerAI Inference Engine — runs the trained model for real-time answers
Falls back to Ollama when the local model isn't confident enough
"""

import os
import sys
import json
import torch
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tinker_model import TinkerModel
from tinker_tokenizer import TinkerTokenizer

MODEL_DIR = os.path.join(os.path.dirname(__file__), 'checkpoints')
OLLAMA_HOST = os.environ.get('OLLAMA_HOST', 'http://localhost:11434')


class TinkerInference:
    """Real-time inference engine"""
    
    def __init__(self):
        self.model = None
        self.tokenizer = None
        self.device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
        self._load_model()
    
    def _load_model(self):
        model_path = os.path.join(MODEL_DIR, 'best.pt')
        tok_path = os.path.join(MODEL_DIR, 'tokenizer.json')
        
        if os.path.exists(model_path) and os.path.exists(tok_path):
            self.model = TinkerModel.load(model_path).to(self.device)
            self.model.eval()
            self.tokenizer = TinkerTokenizer.load(tok_path)
            print(f"Neural model loaded: {self.model.count_parameters():,} parameters")
        else:
            print("No trained model found. Using Ollama fallback.")
    
    def has_local_model(self):
        return self.model is not None
    
    def generate_local(self, question, max_tokens=150, temperature=0.7):
        """Generate answer using local neural network"""
        if not self.has_local_model():
            return None
        
        prompt = f"<Q> {question} <A>"
        ids = self.tokenizer.encode(prompt, add_special=False)
        input_ids = torch.tensor([ids], dtype=torch.long).to(self.device)
        
        start = time.time()
        with torch.no_grad():
            output = self.model.generate(
                input_ids,
                max_new_tokens=max_tokens,
                temperature=temperature,
                top_k=40
            )
        elapsed = time.time() - start
        
        answer = self.tokenizer.decode(output[0].tolist())
        if '<A>' in answer:
            answer = answer.split('<A>')[-1].strip()
        
        return {
            'answer': answer,
            'source': 'local_neural_network',
            'time': f'{elapsed:.2f}s',
            'model_size': f'{self.model.count_parameters():,} params'
        }
    
    def generate_ollama(self, question, model='llama3.1:8b'):
        """Generate answer using Ollama as fallback"""
        import subprocess
        try:
            result = subprocess.run(
                ['curl', '-s', f'{OLLAMA_HOST}/api/generate',
                 '-d', json.dumps({
                     'model': model,
                     'prompt': question,
                     'stream': False,
                     'options': {'temperature': 0.7, 'num_predict': 512}
                 })],
                capture_output=True, text=True, timeout=30
            )
            data = json.loads(result.stdout)
            return {
                'answer': data.get('response', 'Could not generate response.'),
                'source': f'ollama_{model}',
                'time': 'N/A'
            }
        except:
            return None
    
    def answer(self, question, prefer_local=True):
        """Smart inference: try local first, fall back to Ollama"""
        # Try local neural network first
        if prefer_local and self.has_local_model():
            result = self.generate_local(question)
            if result and result['answer']:
                return result
        
        # Fall back to Ollama
        ollama_result = self.generate_ollama(question)
        if ollama_result:
            return ollama_result
        
        return {
            'answer': "I'm not sure how to answer that. Could you rephrase?",
            'source': 'fallback',
            'time': '0s'
        }
    
    def benchmark(self):
        """Run benchmark to test model performance"""
        if not self.has_local_model():
            print("No model loaded for benchmarking.")
            return
        
        test_questions = [
            "What is TinkerOS?",
            "How do I switch worlds?",
            "What is Searchie?",
            "How do I open the Control Center?",
            "What games are pre-installed?",
            "How do I enable GameMode?",
            "What is the AI assistant?",
            "How do I take a screenshot?",
        ]
        
        print(f"\n{'='*60}")
        print(f"  TinkerAI Benchmark")
        print(f"  Model: {self.model.count_parameters():,} parameters")
        print(f"  Device: {self.device}")
        print(f"{'='*60}\n")
        
        total_time = 0
        for q in test_questions:
            start = time.time()
            result = self.generate_local(q, max_tokens=100)
            elapsed = time.time() - start
            total_time += elapsed
            
            print(f"Q: {q}")
            print(f"A: {result['answer'][:100]}...")
            print(f"Time: {elapsed:.2f}s")
            print()
        
        print(f"Average time: {total_time/len(test_questions):.2f}s per question")


if __name__ == "__main__":
    engine = TinkerInference()
    
    if len(sys.argv) > 1 and sys.argv[1] == 'benchmark':
        engine.benchmark()
    elif len(sys.argv) > 1 and sys.argv[1] == 'chat':
        print("TinkerAI Neural Chat (type 'quit' to exit)")
        while True:
            q = input("\nYou: ").strip()
            if q.lower() in ('quit', 'exit'):
                break
            result = engine.answer(q)
            print(f"TinkerAI: {result['answer']}")
    else:
        # Single question mode
        q = ' '.join(sys.argv[1:]) or "What is TinkerOS?"
        result = engine.answer(q)
        print(json.dumps(result, indent=2))
