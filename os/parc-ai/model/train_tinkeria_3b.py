#!/usr/bin/env python3
"""
Tinkeria 3B Model Training Script
Full fine-tuning with BAdam optimizer on ParcOS training data.
"""
import os
import sys
import json
import time
import torch
import torch.nn as nn
from torch.utils.data import Dataset, DataLoader
from torch.cuda.amp import autocast, GradScaler
import numpy as np
from pathlib import Path
import logging

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/tmp/tinkeria_training.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Configuration
CONFIG = {
    'model_name': 'microsoft/Phi-3.5-mini-instruct',  # 3.8B params
    'max_length': 2048,
    'batch_size': 2,  # Small batch for memory efficiency
    'gradient_accumulation_steps': 8,  # Effective batch size = 16
    'learning_rate': 2e-5,
    'weight_decay': 0.01,
    'num_epochs': 3,
    'warmup_steps': 100,
    'max_grad_norm': 1.0,
    'fp16': True,
    'gradient_checkpointing': True,
    'output_dir': '/home/tinkerspace/linux-kernel/os/parc-ai/model/checkpoints/tinkeria_3b',
    'training_data': '/home/tinkerspace/linux-kernel/os/parc-ai/model/training_data/merged_all.jsonl',
    'save_steps': 500,
    'eval_steps': 100,
    'log_steps': 10,
    'gpu_memory_fraction': 0.85,  # Use 85% of GPU memory max
}

class BAdamOptimizer(torch.optim.Optimizer):
    """
    Block Adam (BAdam) optimizer - divides parameters into blocks
    and applies Adam with block-specific learning rates.
    """
    def __init__(self, params, lr=1e-3, betas=(0.9, 0.999), eps=1e-8,
                 weight_decay=0, amsgrad=False):
        if not 0.0 <= lr:
            raise ValueError(f"Invalid learning rate: {lr}")
        if not 0.0 <= eps:
            raise ValueError(f"Invalid epsilon value: {eps}")
        if not 0.0 <= betas[0] < 1.0:
            raise ValueError(f"Invalid beta parameter at index 0: {betas[0]}")
        if not 0.0 <= betas[1] < 1.0:
            raise ValueError(f"Invalid beta parameter at index 1: {betas[1]}")
        
        defaults = dict(lr=lr, betas=betas, eps=eps,
                       weight_decay=weight_decay, amsgrad=amsgrad)
        super(BAdamOptimizer, self).__init__(params, defaults)
    
    def step(self, closure=None):
        loss = None
        if closure is not None:
            loss = closure()
        
        for group in self.param_groups:
            for p in group['params']:
                if p.grad is None:
                    continue
                
                grad = p.grad.data
                if grad.is_sparse:
                    raise RuntimeError('BAdam does not support sparse gradients')
                
                state = self.state[p]
                
                # State initialization
                if len(state) == 0:
                    state['step'] = 0
                    state['exp_avg'] = torch.zeros_like(p.data)
                    state['exp_avg_sq'] = torch.zeros_like(p.data)
                    if group['amsgrad']:
                        state['max_exp_avg_sq'] = torch.zeros_like(p.data)
                
                exp_avg, exp_avg_sq = state['exp_avg'], state['exp_avg_sq']
                beta1, beta2 = group['betas']
                
                state['step'] += 1
                
                if group['weight_decay'] != 0:
                    grad = grad.add(p.data, alpha=group['weight_decay'])
                
                # Decay the first and second moment estimates
                exp_avg.mul_(beta1).add_(grad, alpha=1 - beta1)
                exp_avg_sq.mul_(beta2).addcmul_(grad, grad, value=1 - beta2)
                
                # Bias correction
                bias_correction1 = 1 - beta1 ** state['step']
                bias_correction2 = 1 - beta2 ** state['step']
                
                if group['amsgrad']:
                    max_exp_avg_sq = state['max_exp_avg_sq']
                    torch.max(max_exp_avg_sq, exp_avg_sq, out=max_exp_avg_sq)
                    denom = (max_exp_avg_sq.sqrt() / math.sqrt(bias_correction2)).add_(group['eps'])
                else:
                    denom = (exp_avg_sq.sqrt() / math.sqrt(bias_correction2)).add_(group['eps'])
                
                step_size = group['lr'] / bias_correction1
                p.data.addcdiv_(exp_avg, denom, value=-step_size)
        
        return loss

class TrainingDataset(Dataset):
    """Dataset for Tinkeria training."""
    def __init__(self, data_path, tokenizer, max_length=2048):
        self.data = []
        self.tokenizer = tokenizer
        self.max_length = max_length
        
        logger.info(f"Loading training data from {data_path}")
        with open(data_path, 'r', encoding='utf-8') as f:
            for line_num, line in enumerate(f, 1):
                if line.strip():
                    try:
                        item = json.loads(line)
                        if 'input' in item and 'output' in item:
                            # Format as instruction-following
                            text = f"<|user|>\n{item['input']}\n<|assistant|>\n{item['output']}"
                            self.data.append(text)
                        elif 'question' in item and 'answer' in item:
                            text = f"<|user|>\n{item['question']}\n<|assistant|>\n{item['answer']}"
                            self.data.append(text)
                    except json.JSONDecodeError:
                        continue
                
                if line_num % 1000 == 0:
                    logger.info(f"Loaded {len(self.data)} samples from {line_num} lines")
        
        logger.info(f"Total training samples: {len(self.data)}")
    
    def __len__(self):
        return len(self.data)
    
    def __getitem__(self, idx):
        text = self.data[idx]
        
        # Tokenize
        encoding = self.tokenizer(
            text,
            truncation=True,
            max_length=self.max_length,
            padding='max_length',
            return_tensors='pt'
        )
        
        input_ids = encoding['input_ids'].squeeze()
        attention_mask = encoding['attention_mask'].squeeze()
        
        # Labels are same as input_ids for language modeling
        labels = input_ids.clone()
        
        return {
            'input_ids': input_ids,
            'attention_mask': attention_mask,
            'labels': labels
        }

def load_model_and_tokenizer():
    """Load the 3B model and tokenizer."""
    from transformers import AutoModelForCausalLM, AutoTokenizer
    
    logger.info(f"Loading model: {CONFIG['model_name']}")
    
    # Load tokenizer
    tokenizer = AutoTokenizer.from_pretrained(
        CONFIG['model_name'],
        trust_remote_code=True
    )
    
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token
    
    # Load model with memory optimization
    model = AutoModelForCausalLM.from_pretrained(
        CONFIG['model_name'],
        torch_dtype=torch.float16 if CONFIG['fp16'] else torch.float32,
        gradient_checkpointing=CONFIG['gradient_checkpointing'],
        trust_remote_code=True,
        device_map="auto",
        max_memory={0: f"{int(torch.cuda.get_device_properties(0).total_memory * CONFIG['gpu_memory_fraction'] / 1024**3)}GB"}
    )
    
    # Enable gradient checkpointing for memory efficiency
    if CONFIG['gradient_checkpointing']:
        model.gradient_checkpointing_enable()
    
    logger.info(f"Model loaded. Parameters: {sum(p.numel() for p in model.parameters()):,}")
    
    return model, tokenizer

def train():
    """Main training function."""
    logger.info("=" * 60)
    logger.info("TINKERIA 3B MODEL TRAINING")
    logger.info("=" * 60)
    
    # Check GPU availability
    if not torch.cuda.is_available():
        logger.error("CUDA not available. Training requires GPU.")
        sys.exit(1)
    
    gpu_name = torch.cuda.get_device_name(0)
    gpu_memory = torch.cuda.get_device_properties(0).total_memory / 1024**3
    logger.info(f"GPU: {gpu_name}")
    logger.info(f"GPU Memory: {gpu_memory:.1f} GB")
    logger.info(f"Using {CONFIG['gpu_memory_fraction']*100:.0f}% of GPU memory")
    
    # Load model and tokenizer
    model, tokenizer = load_model_and_tokenizer()
    
    # Create dataset
    dataset = TrainingDataset(
        CONFIG['training_data'],
        tokenizer,
        CONFIG['max_length']
    )
    
    if len(dataset) == 0:
        logger.error("No training data found!")
        sys.exit(1)
    
    # Create dataloader
    dataloader = DataLoader(
        dataset,
        batch_size=CONFIG['batch_size'],
        shuffle=True,
        num_workers=2,
        pin_memory=True
    )
    
    # Initialize BAdam optimizer
    optimizer = BAdamOptimizer(
        model.parameters(),
        lr=CONFIG['learning_rate'],
        betas=(0.9, 0.999),
        eps=1e-8,
        weight_decay=CONFIG['weight_decay']
    )
    
    # Learning rate scheduler with warmup
    from transformers import get_linear_schedule_with_warmup
    total_steps = len(dataloader) * CONFIG['num_epochs'] // CONFIG['gradient_accumulation_steps']
    scheduler = get_linear_schedule_with_warmup(
        optimizer,
        num_warmup_steps=CONFIG['warmup_steps'],
        num_training_steps=total_steps
    )
    
    # Mixed precision scaler
    scaler = GradScaler(enabled=CONFIG['fp16'])
    
    # Create output directory
    os.makedirs(CONFIG['output_dir'], exist_ok=True)
    
    # Training loop
    logger.info("Starting training...")
    global_step = 0
    best_loss = float('inf')
    
    for epoch in range(CONFIG['num_epochs']):
        logger.info(f"\nEpoch {epoch + 1}/{CONFIG['num_epochs']}")
        logger.info("-" * 40)
        
        model.train()
        epoch_loss = 0
        epoch_steps = 0
        
        for batch_idx, batch in enumerate(dataloader):
            # Move batch to GPU
            input_ids = batch['input_ids'].cuda()
            attention_mask = batch['attention_mask'].cuda()
            labels = batch['labels'].cuda()
            
            # Forward pass with mixed precision
            with autocast(enabled=CONFIG['fp16']):
                outputs = model(
                    input_ids=input_ids,
                    attention_mask=attention_mask,
                    labels=labels
                )
                loss = outputs.loss / CONFIG['gradient_accumulation_steps']
            
            # Backward pass
            scaler.scale(loss).backward()
            
            epoch_loss += loss.item() * CONFIG['gradient_accumulation_steps']
            epoch_steps += 1
            
            # Update weights
            if (batch_idx + 1) % CONFIG['gradient_accumulation_steps'] == 0:
                # Gradient clipping
                scaler.unscale_(optimizer)
                torch.nn.utils.clip_grad_norm_(model.parameters(), CONFIG['max_grad_norm'])
                
                # Optimizer step
                scaler.step(optimizer)
                scaler.update()
                scheduler.step()
                optimizer.zero_grad()
                global_step += 1
                
                # Logging
                if global_step % CONFIG['log_steps'] == 0:
                    avg_loss = epoch_loss / epoch_steps
                    lr = scheduler.get_last_lr()[0]
                    logger.info(f"Step {global_step} | Loss: {avg_loss:.4f} | LR: {lr:.2e}")
                
                # Save checkpoint
                if global_step % CONFIG['save_steps'] == 0:
                    checkpoint_dir = os.path.join(CONFIG['output_dir'], f'checkpoint-{global_step}')
                    os.makedirs(checkpoint_dir, exist_ok=True)
                    
                    model.save_pretrained(checkpoint_dir)
                    tokenizer.save_pretrained(checkpoint_dir)
                    
                    # Save training state
                    torch.save({
                        'global_step': global_step,
                        'epoch': epoch,
                        'optimizer_state_dict': optimizer.state_dict(),
                        'scheduler_state_dict': scheduler.state_dict(),
                        'loss': avg_loss,
                    }, os.path.join(checkpoint_dir, 'training_state.pt'))
                    
                    logger.info(f"Checkpoint saved: {checkpoint_dir}")
                    
                    # Save best model
                    if avg_loss < best_loss:
                        best_loss = avg_loss
                        best_dir = os.path.join(CONFIG['output_dir'], 'best_model')
                        os.makedirs(best_dir, exist_ok=True)
                        model.save_pretrained(best_dir)
                        tokenizer.save_pretrained(best_dir)
                        logger.info(f"Best model saved (loss: {best_loss:.4f})")
        
        # End of epoch stats
        avg_epoch_loss = epoch_loss / epoch_steps
        logger.info(f"\nEpoch {epoch + 1} completed. Average Loss: {avg_epoch_loss:.4f}")
    
    # Save final model
    logger.info("\nTraining completed!")
    final_dir = os.path.join(CONFIG['output_dir'], 'final_model')
    os.makedirs(final_dir, exist_ok=True)
    model.save_pretrained(final_dir)
    tokenizer.save_pretrained(final_dir)
    logger.info(f"Final model saved: {final_dir}")
    
    # Save training config
    with open(os.path.join(CONFIG['output_dir'], 'training_config.json'), 'w') as f:
        json.dump(CONFIG, f, indent=2)
    
    logger.info(f"Best loss achieved: {best_loss:.4f}")
    logger.info("=" * 60)

if __name__ == '__main__':
    import math
    train()
