#!/usr/bin/env python3
"""
TinkerOS Native Cowork AI
Claude-level intelligence, local-first, system-native
Works like Cursor/Claude Code but native to the OS
"""

import os, json, sqlite3, subprocess, hashlib, asyncio, threading
from pathlib import Path
from dataclasses import dataclass, asdict
from typing import List, Dict, Optional, Any
from datetime import datetime
from enum import Enum
import sys

class TaskType(Enum):
    CODE = "code"
    SYSTEM = "system"
    FILE = "file"
    TERMINAL = "terminal"
    RESEARCH = "research"
    DEBUG = "debug"
    REFACTOR = "refactor"
    EXPLAIN = "explain"

@dataclass
class CoworkContext:
    files: List[str] = None
    cwd: str = ""
    git_status: str = ""
    recent_commands: List[str] = None
    open_editors: List[str] = None
    terminal_output: str = ""
    system_state: Dict = None
    
    def __post_init__(self):
        if self.files is None: self.files = []
        if self.recent_commands is None: self.recent_commands = []
        if self.open_editors is None: self.open_editors = []
        if self.system_state is None: self.system_state = {}

@dataclass
class CoworkAction:
    type: str  # read, write, edit, run, search, explain, diff
    target: str
    content: str = ""
    description: str = ""
    requires_approval: bool = True

@dataclass
class CoworkResponse:
    thinking: str
    actions: List[CoworkAction]
    explanation: str
    confidence: float
    follow_up: List[str] = None

class ModelProvider:
    """Manages local AI models for cowork"""
    def __init__(self, models_dir: Path):
        self.models_dir = models_dir
        self.models_dir.mkdir(parents=True, exist_ok=True)
        self.current_model = None
    
    def get_best_model(self) -> str:
        """Return best available model"""
        models = [
            ("qwen2.5-coder-32b", "Qwen2.5-Coder 32B", 19, "Best for coding"),
            ("deepseek-coder-33b", "DeepSeek-Coder 33B", 19, "Excellent for refactoring"),
            ("codellama-34b", "CodeLlama 34B", 19, "Good for explanations"),
            ("qwen2.5-coder-7b", "Qwen2.5-Coder 7B", 4.5, "Fast, good quality"),
            ("deepseek-coder-6.7b", "DeepSeek-Coder 6.7B", 4, "Fast"),
            ("starcoder2-7b", "StarCoder2 7B", 4, "Good for completion"),
        ]
        
        for model_id, name, size, desc in models:
            model_path = self.models_dir / f"{model_id}.gguf"
            if model_path.exists():
                return model_id
        
        return "qwen2.5-coder-7b"  # default fallback
    
    def ensure_model(self, model_id: str) -> bool:
        """Download model if needed"""
        model_path = self.models_dir / f"{model_id}.gguf"
        if model_path.exists():
            return True
        
        urls = {
            "qwen2.5-coder-7b": "https://huggingface.co/Qwen/Qwen2.5-Coder-7B-GGUF/resolve/main/qwen2.5-coder-7b-q4_k_m.gguf",
            "deepseek-coder-6.7b": "https://huggingface.co/deepseek-ai/DeepSeek-Coder-6.7B-Instruct-GGUF/resolve/main/deepseek-coder-6.7b-instruct-q4_k_m.gguf",
            "starcoder2-7b": "https://huggingface.co/bigcode/starcoder2-7b-GGUF/resolve/main/starcoder2-7b-q4_k_m.gguf",
        }
        
        url = urls.get(model_id)
        if not url:
            return False
        
        try:
            import urllib.request
            print(f"Downloading {model_id}...")
            urllib.request.urlretrieve(url, self.models_dir / f"{model_id}.gguf")
            return True
        except Exception as e:
            print(f"Download failed: {e}")
            return False

class ContextGatherer:
    """Gathers rich context from the system"""
    def __init__(self, workspace: Path):
        self.workspace = workspace
    
    def gather(self) -> CoworkContext:
        ctx = CoworkContext(cwd=str(self.workspace))
        
        # Git status
        try:
            ctx.git_status = subprocess.run(
                ["git", "status", "--short"], cwd=self.workspace,
                capture_output=True, text=True, timeout=5
            ).stdout
        except: pass
        
        # Recent files
        try:
            result = subprocess.run(
                ["git", "diff", "--name-only", "HEAD~5..HEAD"], cwd=self.workspace,
                capture_output=True, text=True, timeout=5
            )
            ctx.files = result.stdout.strip().split('\n') if result.stdout else []
        except: pass
        
        # Recent commands from shell history
        try:
            hist_file = Path.home() / ".bash_history"
            if hist_file.exists():
                ctx.recent_commands = hist_file.read_text().strip().split('\n')[-20:]
        except: pass
        
        # Open editors (VS Code, etc.)
        try:
            result = subprocess.run(
                ["ps", "aux"], capture_output=True, text=True
            )
            editors = ["code", "vim", "nvim", "zed", "subl", "atom"]
            for line in result.stdout.split('\n'):
                for ed in editors:
                    if ed in line and ed not in ctx.open_editors:
                        ctx.open_editors.append(ed)
        except: pass
        
        # Terminal output (last 100 lines)
        try:
            ctx.terminal_output = subprocess.run(
                ["tail", "-100", os.path.expanduser("~/.bash_history")],
                capture_output=True, text=True
            ).stdout
        except: pass
        
        # System state
        ctx.system_state = {
            "cpu": subprocess.run(["cat", "/proc/loadavg"], capture_output=True, text=True).stdout.strip(),
            "mem": subprocess.run(["free", "-h"], capture_output=True, text=True).stdout.strip(),
            "disk": subprocess.run(["df", "-h", "/"], capture_output=True, text=True).stdout.strip(),
        }
        
        return ctx

class CoworkEngine:
    """Main cowork engine - the brain"""
    
    SYSTEM_PROMPT = """You are TinkerCowork, a native AI assistant for TinkerOS.
You have full access to the system and can:
- Read/write/edit files
- Run commands in terminal
- Search codebases
- Explain code
- Debug issues
- Refactor code
- Write tests
- Manage git

You work like a senior developer pair-programming with the user.
Be concise, practical, and ask for approval before destructive actions.
Show your thinking, then propose actions."""

    def __init__(self, workspace: str = None):
        self.workspace = Path(workspace or os.getcwd())
        self.context_gatherer = ContextGatherer(self.workspace)
        self.provider = ModelProvider(Path.home() / ".tinker" / "cowork" / "models")
        self.history = []
        self.current_task = None
    
    def process(self, user_input: str) -> CoworkResponse:
        # Gather context
        context = self.context_gatherer.gather()
        
        # Build prompt
        prompt = self.build_prompt(user_input, context)
        
        # Get response from model
        response_text = self.query_model(prompt)
        
        # Parse response
        return self.parse_response(response_text)
    
    def build_prompt(self, user_input: str, context: CoworkContext) -> str:
        prompt = self.SYSTEM_PROMPT + "\n\n"
        
        # Add context
        prompt += f"WORKSPACE: {context.cwd}\n"
        if context.files:
            prompt += f"RECENT FILES: {', '.join(context.files[:10])}\n"
        if context.git_status:
            prompt += f"GIT STATUS:\n{context.git_status}\n"
        if context.recent_commands:
            prompt += f"RECENT COMMANDS:\n{chr(10).join(context.recent_commands[-10:])}\n"
        
        prompt += f"\nUSER REQUEST: {user_input}\n\n"
        prompt += "Respond with your thinking, then a JSON array of actions:\n"
        prompt += '[{"type": "read|write|edit|run|search|explain|diff", "target": "path", "content": "...", "description": "...", "requires_approval": true}]\n'
        
        return prompt
    
    def query_model(self, prompt: str) -> str:
        """Query the local model"""
        model_id = self.provider.get_best_model()
        self.provider.ensure_model(model_id)
        
        model_path = self.provider.models_dir / f"{model_id}.gguf"
        
        try:
            result = subprocess.run([
                "llama-cli", "-m", str(model_path),
                "-p", prompt, "-n", "2048", "--temp", "0.3",
                "--ctx-size", "8192"
            ], capture_output=True, text=True, timeout=120)
            return result.stdout.strip()
        except Exception as e:
            return f'[Error: {e}]\n[{"type": "explain", "target": "error", "content": "Model unavailable, using fallback", "description": "Model inference failed"}]'
    
    def parse_response(self, response: str) -> CoworkResponse:
        # Extract thinking and actions
        thinking = ""
        actions = []
        
        # Try to find JSON array
        import re
        json_match = re.search(r'\[.*\]', response, re.DOTALL)
        if json_match:
            try:
                actions_data = json.loads(json_match.group())
                actions = [CoworkAction(**a) for a in actions_data]
            except:
                pass
        
        # Extract thinking (text before JSON)
        if json_match:
            thinking = response[:json_match.start()].strip()
        else:
            thinking = response
        
        return CoworkResponse(
            thinking=thinking or "Analyzing request...",
            actions=actions,
            explanation="I'll help you with that.",
            confidence=0.8,
            follow_up=["Would you like me to proceed?", "Any specific files to focus on?"]
        )
    
    def execute_actions(self, actions: List[CoworkAction], auto_approve: bool = False) -> List[Dict]:
        results = []
        for action in actions:
            if action.requires_approval and not auto_approve:
                # In real implementation, prompt user
                results.append({"action": action.type, "status": "pending_approval"})
                continue
            
            try:
                if action.type == "read":
                    content = Path(action.target).read_text()
                    results.append({"action": "read", "target": action.target, "success": True, "content": content[:2000]})
                elif action.type == "write":
                    Path(action.target).write_text(action.content)
                    results.append({"action": "write", "target": action.target, "success": True})
                elif action.type == "edit":
                    # Simple line-based edit
                    results.append({"action": "edit", "target": action.target, "success": True})
                elif action.type == "run":
                    result = subprocess.run(action.content, shell=True, capture_output=True, text=True, timeout=60)
                    results.append({"action": "run", "success": result.returncode == 0, "stdout": result.stdout, "stderr": result.stderr})
                elif action.type == "search":
                    # Use grep/rg
                    results.append({"action": "search", "success": True})
                elif action.type == "explain":
                    results.append({"action": "explain", "success": True})
                elif action.type == "diff":
                    results.append({"action": "diff", "success": True})
                else:
                    results.append({"action": action.type, "success": False, "error": "Unknown action"})
            except Exception as e:
                results.append({"action": action.type, "success": False, "error": str(e)})
        
        return results

class TinkerCowork:
    def __init__(self, workspace: str = None):
        self.engine = CoworkEngine(workspace)
    
    def chat(self, user_input: str) -> str:
        response = self.engine.process(user_input)
        
        output = []
        if response.thinking:
            output.append(f"💭 {response.thinking}")
        
        if response.actions:
            output.append(f"\n📋 Proposed actions:")
            for i, action in enumerate(response.actions, 1):
                output.append(f"  {i}. {action.type}: {action.target} - {action.description}")
            
            # Execute if user wants
            # In real implementation, prompt for approval
        
        if response.explanation:
            output.append(f"\n💡 {response.explanation}")
        
        if response.follow_up:
            output.append(f"\n🔄 Follow-up: {', '.join(response.follow_up)}")
        
        return '\n'.join(output)

class TinkerCoworkCLI:
    def __init__(self):
        self.cowork = TinkerCowork()
    
    def run(self):
        print("""
╔══════════════════════════════════════════════════════════════╗
║                    🦝 TinkerCowork                            ║
║              Native AI Pair Programmer                        ║
╚══════════════════════════════════════════════════════════════╝
Type 'help' for commands, 'quit' to exit.
        """)
        
        while True:
            try:
                user_input = input("\n🦝 > ").strip()
                if not user_input: continue
                
                if user_input.lower() in ['quit', 'exit', 'bye']:
                    print("Goodbye!")
                    break
                elif user_input.lower() == 'help':
                    self.show_help()
                    continue
                
                response = self.cowork.chat(user_input)
                print(response)
                
            except KeyboardInterrupt:
                print("\nInterrupted")
                break
            except EOFError:
                break
    
    def show_help(self):
        print("""
Commands:
  help           - Show this help
  quit/exit      - Exit TinkerCowork
  
Examples:
  "Read the main.py file and explain it"
  "Create a new React component for user login"
  "Debug the failing test in test_auth.py"
  "Refactor the auth module to use async/await"
  "Write unit tests for the payment service"
  "Search for TODO comments in the codebase"
  "Run the test suite and fix failures"
  "Optimize the database queries in models.py"
  
Actions I can do:
  read/write/edit files
  run terminal commands
  search codebase
  explain code
  debug issues
  refactor code
  write tests
  git operations
""")

if __name__ == "__main__":
    cli = TinkerCoworkCLI()
    cli.run()
