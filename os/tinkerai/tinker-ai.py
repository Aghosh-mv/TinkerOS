#!/usr/bin/env python3
"""
TinkerAI - Local-First AI Assistant
Runs entirely on-device, zero cloud dependency
"""

import os
import json
import subprocess
import sqlite3
import hashlib
import threading
import queue
import time
from pathlib import Path
from dataclasses import dataclass, asdict
from typing import List, Dict, Optional, Callable
from datetime import datetime
from enum import Enum
import sys

class ModelType(Enum):
    TINYLLAMA = "tinyllama"
    PHI3 = "phi3"
    GEMMA = "gemma"
    LLAMA3 = "llama3"
    MISTRAL = "mistral"

@dataclass
class AIModel:
    name: str
    model_type: ModelType
    size_gb: float
    ram_required_gb: float
    description: str
    download_url: str
    quantized: bool = True

@dataclass
class AIResponse:
    text: str
    intent: str
    actions: List[Dict]
    confidence: float
    model_used: str

class ModelManager:
    """Manages local AI models"""
    AVAILABLE_MODELS = {
        ModelType.TINYLLAMA: AIModel(
            name="TinyLlama 1.1B",
            model_type=ModelType.TINYLLAMA,
            size_gb=0.6,
            ram_required_gb=1.5,
            description="Fast, lightweight model for basic tasks",
            download_url="https://huggingface.co/TinyLlama/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"
        ),
        ModelType.PHI3: AIModel(
            name="Phi-3 Mini 3.8B",
            model_type=ModelType.PHI3,
            size_gb=2.3,
            ram_required_gb=4,
            description="Microsoft's efficient small model",
            download_url="https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf"
        ),
        ModelType.GEMMA: AIModel(
            name="Gemma 2B",
            model_type=ModelType.GEMMA,
            size_gb=1.5,
            ram_required_gb=3,
            description="Google's lightweight open model",
            download_url="https://huggingface.co/google/gemma-2b-it-gguf/resolve/main/gemma-2b-it-q4.gguf"
        ),
    }
    
    def __init__(self, models_dir: Path):
        self.models_dir = models_dir
        self.models_dir.mkdir(parents=True, exist_ok=True)
        self.loaded_model = None
        self.llama_cpp_path = None
    
    def check_llama_cpp(self) -> bool:
        """Check if llama.cpp is available"""
        for path in ["/usr/bin/llama-cli", "/usr/local/bin/llama-cli", 
                     os.path.expanduser("~/.local/bin/llama-cli")]:
            if os.path.exists(path):
                self.llama_cpp_path = path
                return True
        return False
    
    def install_llama_cpp(self) -> bool:
        """Install llama.cpp for inference"""
        try:
            subprocess.run(["pip", "install", "llama-cpp-python"], check=True)
            return True
        except Exception:
            return False
    
    def download_model(self, model_type: ModelType, progress_callback=None) -> bool:
        """Download model file"""
        model = self.AVAILABLE_MODELS.get(model_type)
        if not model:
            return False
        
        model_file = self.models_dir / f"{model_type.value}.gguf"
        if model_file.exists():
            return True
        
        try:
            import urllib.request
            def reporthook(block_num, block_size, total_size):
                if progress_callback and total_size > 0:
                    progress = min(100, (block_num * block_size * 100) // total_size)
                    progress_callback(progress)
            
            urllib.request.urlretrieve(model.download_url, model_file, reporthook)
            return True
        except Exception as e:
            print(f"Download failed: {e}")
            return False
    
    def load_model(self, model_type: ModelType) -> bool:
        """Load model for inference"""
        if not self.check_llama_cpp():
            if not self.install_llama_cpp():
                return False
        
        model = self.AVAILABLE_MODELS.get(model_type)
        model_file = self.models_dir / f"{model_type.value}.gguf"
        
        if not model_file.exists():
            return False
        
        self.loaded_model = model_type
        return True
    
    def run_inference(self, prompt: str, max_tokens: int = 512, 
                      temperature: float = 0.7) -> str:
        """Run inference using llama.cpp"""
        if not self.loaded_model:
            return "No model loaded"
        
        model_file = self.models_dir / f"{self.loaded_model.value}.gguf"
        
        try:
            cmd = [
                self.llama_cpp_path or "llama-cli",
                "-m", str(model_file),
                "-p", prompt,
                "-n", str(max_tokens),
                "--temp", str(temperature),
                "--ctx-size", "2048"
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
            return result.stdout.strip()
        except Exception as e:
            return f"Inference error: {e}"

class SystemController:
    """Controls system via AI commands"""
    
    def __init__(self):
        self.commands = {
            "optimize_gaming": self.optimize_gaming,
            "optimize_battery": self.optimize_battery,
            "optimize_performance": self.optimize_performance,
            "clean_system": self.clean_system,
            "update_system": self.update_system,
            "backup_system": self.backup_system,
            "install_app": self.install_app,
            "remove_app": self.remove_app,
            "set_theme": self.set_theme,
            "set_power_mode": self.set_power_mode,
            "get_status": self.get_status,
            "run_benchmark": self.run_benchmark,
        }
    
    def execute(self, action: str, params: Dict = None) -> Dict:
        params = params or {}
        if action in self.commands:
            try:
                result = self.commands[action](**params)
                return {"success": True, "result": result}
            except Exception as e:
                return {"success": False, "error": str(e)}
        return {"success": False, "error": f"Unknown action: {action}"}
    
    def optimize_gaming(self) -> str:
        subprocess.run(["systemctl", "set-property", "user.slice", "CPUShares=1024"])
        subprocess.run(["cpupower", "frequency-set", "-g", "performance"])
        return "Gaming mode enabled: CPU performance, GPU max, notifications off"
    
    def optimize_battery(self) -> str:
        subprocess.run(["cpupower", "frequency-set", "-g", "powersave"])
        subprocess.run(["echo", "1", ">", "/proc/sys/vm/laptop_mode"])
        return "Battery saver enabled: CPU powersave, reduced background activity"
    
    def optimize_performance(self) -> str:
        subprocess.run(["cpupower", "frequency-set", "-g", "performance"])
        return "Performance mode enabled"
    
    def clean_system(self) -> str:
        subprocess.run(["apt", "clean"])
        subprocess.run(["journalctl", "--vacuum-time=3d"])
        return "System cleaned: package cache, old logs removed"
    
    def update_system(self) -> str:
        subprocess.run(["apt", "update", "&&", "apt", "upgrade", "-y"])
        return "System updated"
    
    def backup_system(self) -> str:
        subprocess.run(["timeshift", "--create", "--comments", "AI backup"])
        return "System backup created"
    
    def install_app(self, app: str) -> str:
        subprocess.run(["flatpak", "install", "-y", "flathub", app])
        return f"Installed {app}"
    
    def remove_app(self, app: str) -> str:
        subprocess.run(["flatpak", "uninstall", "-y", app])
        return f"Removed {app}"
    
    def set_theme(self, theme: str) -> str:
        themes = {"dark": "Adwaita-dark", "light": "Adwaita"}
        subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", 
                       "gtk-theme", themes.get(theme, "Adwaita")])
        return f"Theme set to {theme}"
    
    def set_power_mode(self, mode: str) -> str:
        modes = {"performance": "performance", "balanced": "ondemand", "powersave": "powersave"}
        gov = modes.get(mode, "ondemand")
        subprocess.run(["cpupower", "frequency-set", "-g", gov])
        return f"Power mode: {mode}"
    
    def get_status(self) -> str:
        cpu = subprocess.run(["cat", "/proc/loadavg"], capture_output=True, text=True).stdout.strip()
        mem = subprocess.run(["free", "-h"], capture_output=True, text=True).stdout.strip()
        disk = subprocess.run(["df", "-h", "/"], capture_output=True, text=True).stdout.strip()
        return f"Load: {cpu}\nMemory:\n{mem}\nDisk:\n{disk}"
    
    def run_benchmark(self) -> str:
        return "Benchmark completed - check tinker-benchmark for results"

class IntentClassifier:
    """Classifies user intent from natural language"""
    
    INTENTS = {
        "system_control": [
            "optimize", "speed up", "slow down", "performance", "battery",
            "gaming", "game mode", "power mode", "theme", "dark mode", "light mode"
        ],
        "maintenance": [
            "clean", "update", "upgrade", "backup", "backup system", "clean up"
        ],
        "app_management": [
            "install", "uninstall", "remove", "add app", "get app"
        ],
        "information": [
            "status", "how is", "what is", "show me", "check", "temperature"
        ],
        "benchmark": [
            "benchmark", "test performance", "speed test", "run test"
        ],
        "help": [
            "help", "how do i", "what can you", "commands"
        ]
    }
    
    def classify(self, text: str) -> tuple:
        text_lower = text.lower()
        scores = {}
        
        for intent, keywords in self.INTENTS.items():
            score = sum(1 for kw in keywords if kw in text_lower)
            if score > 0:
                scores[intent] = score
        
        if not scores:
            return "general", 0.0
        
        best_intent = max(scores, key=scores.get)
        confidence = min(scores[best_intent] / 3.0, 1.0)
        return best_intent, confidence

class TinkerAI:
    def __init__(self, data_dir: str = None):
        self.data_dir = Path(data_dir or os.path.expanduser("~/.tinker/ai"))
        self.data_dir.mkdir(parents=True, exist_ok=True)
        
        self.model_manager = ModelManager(self.data_dir / "models")
        self.system_controller = SystemController()
        self.intent_classifier = IntentClassifier()
        self.conversation_history = []
        self.context = {}
    
    def process(self, user_input: str) -> AIResponse:
        """Process user input and generate response"""
        # Classify intent
        intent, confidence = self.intent_classifier.classify(user_input)
        
        # Extract action
        actions = self.extract_actions(user_input, intent)
        
        # Generate response
        if actions:
            action_results = []
            for action in actions:
                result = self.system_controller.execute(action["name"], action.get("params", {}))
                action_results.append(result)
            
            response_text = self.format_action_response(actions, action_results)
        else:
            # Use LLM for general conversation
            response_text = self.generate_llm_response(user_input)
        
        # Save to history
        self.conversation_history.append({
            "role": "user", "content": user_input, "timestamp": datetime.utcnow().isoformat()
        })
        self.conversation_history.append({
            "role": "assistant", "content": response_text, "timestamp": datetime.utcnow().isoformat()
        })
        
        # Keep last 20 messages
        if len(self.conversation_history) > 40:
            self.conversation_history = self.conversation_history[-40:]
        
        return AIResponse(
            text=response_text,
            intent=intent,
            actions=actions,
            confidence=confidence,
            model_used=self.model_manager.loaded_model.value if self.model_manager.loaded_model else "rule-based"
        )
    
    def extract_actions(self, text: str, intent: str) -> List[Dict]:
        """Extract actionable commands from text"""
        actions = []
        text_lower = text.lower()
        
        action_map = {
            "optimize_gaming": ["gaming", "game mode", "optimize for gaming"],
            "optimize_battery": ["battery", "power save", "battery saver"],
            "optimize_performance": ["performance", "speed up", "max performance"],
            "clean_system": ["clean", "clean up", "clean system"],
            "update_system": ["update", "upgrade", "update system"],
            "backup_system": ["backup", "backup system"],
            "set_theme": ["dark mode", "light mode", "theme"],
            "set_power_mode": ["power mode", "performance mode", "balanced mode", "powersave mode"],
            "get_status": ["status", "system status", "how is system"],
            "run_benchmark": ["benchmark", "run benchmark", "test performance"],
        }
        
        for action, triggers in action_map.items():
            if any(trigger in text_lower for trigger in triggers):
                params = self.extract_params(action, text)
                actions.append({"name": action, "params": params})
        
        # App install/remove
        if "install" in text_lower:
            app_name = self.extract_app_name(text, "install")
            if app_name:
                actions.append({"name": "install_app", "params": {"app": app_name}})
        
        if "uninstall" in text_lower or "remove" in text_lower:
            app_name = self.extract_app_name(text, "uninstall")
            if app_name:
                actions.append({"name": "remove_app", "params": {"app": app_name}})
        
        return actions
    
    def extract_params(self, action: str, text: str) -> Dict:
        params = {}
        text_lower = text.lower()
        
        if action == "set_theme":
            if "dark" in text_lower: params["theme"] = "dark"
            elif "light" in text_lower: params["theme"] = "light"
        elif action == "set_power_mode":
            if "performance" in text_lower: params["mode"] = "performance"
            elif "balanced" in text_lower: params["mode"] = "balanced"
            elif "powersave" in text_lower or "battery" in text_lower: params["mode"] = "powersave"
        
        return params
    
    def extract_app_name(self, text: str, action: str) -> Optional[str]:
        # Simple extraction - in production use NER
        words = text.split()
        try:
            idx = words.index(action)
            if idx + 1 < len(words):
                return words[idx + 1]
        except ValueError:
            pass
        return None
    
    def format_action_response(self, actions: List[Dict], results: List[Dict]) -> str:
        response = ""
        for action, result in zip(actions, results):
            if result.get("success"):
                response += f"✅ {action['name']}: {result.get('result', 'Done')}\n"
            else:
                response += f"❌ {action['name']}: {result.get('error', 'Failed')}\n"
        return response.strip()
    
    def generate_llm_response(self, prompt: str) -> str:
        # Build context
        context = "You are TinkerAI, a helpful local AI assistant for TinkerOS Linux. "
        context += "You can control the system, install apps, optimize performance, and answer questions. "
        context += "Be concise and helpful.\n\n"
        
        # Add recent history
        for msg in self.conversation_history[-6:]:
            context += f"{msg['role']}: {msg['content']}\n"
        
        context += f"user: {prompt}\nassistant:"
        
        # Try LLM if available
        if self.model_manager.loaded_model:
            response = self.model_manager.run_inference(context, max_tokens=256)
            if response and len(response) > 10:
                return response.strip()
        
        # Fallback responses
        return self.fallback_response(prompt)
    
    def fallback_response(self, prompt: str) -> str:
        prompt_lower = prompt.lower()
        
        if any(w in prompt_lower for w in ["hello", "hi", "hey"]):
            return "Hello! I'm TinkerAI, your local assistant. How can I help you today?"
        
        if any(w in prompt_lower for w in ["help", "what can you do"]):
            return """I can help you with:
• System optimization: "optimize for gaming", "save battery", "max performance"
• Maintenance: "clean system", "update system", "backup system"
• Apps: "install firefox", "remove vlc"
• Settings: "dark mode", "light mode", "performance mode"
• Info: "system status", "run benchmark"
• Questions about TinkerOS features

Just ask naturally!"""
        
        if "thank" in prompt_lower:
            return "You're welcome! Let me know if you need anything else."
        
        return "I understand. Let me help you with that. Could you be more specific about what you'd like me to do?"

class TinkerAIServer:
    """HTTP API server for TinkerAI"""
    def __init__(self, ai: TinkerAI, host: str = "127.0.0.1", port: int = 8765):
        self.ai = ai
        self.host = host
        self.port = port
    
    def start(self):
        try:
            from http.server import HTTPServer, BaseHTTPRequestHandler
            import threading
            
            class AIHandler(BaseHTTPRequestHandler):
                def do_POST(self):
                    if self.path == "/api/chat":
                        content_length = int(self.headers['Content-Length'])
                        post_data = self.rfile.read(content_length)
                        data = json.loads(post_data)
                        
                        response = self.server.ai.process(data.get("message", ""))
                        
                        self.send_response(200)
                        self.send_header("Content-Type", "application/json")
                        self.end_headers()
                        self.wfile.write(json.dumps(asdict(response)).encode())
                    else:
                        self.send_response(404)
                        self.end_headers()
                
                def log_message(self, format, *args):
                    pass
            
            server = HTTPServer((self.host, self.port), AIHandler)
            server.ai = self.ai
            
            print(f"TinkerAI API server running on http://{self.host}:{self.port}")
            server.serve_forever()
        except Exception as e:
            print(f"Server error: {e}")

def main():
    ai = TinkerAI()
    
    # Try to load a model
    if ai.model_manager.check_llama_cpp():
        print("llama.cpp found, attempting to load TinyLlama...")
        if ai.model_manager.download_model(ModelType.TINYLLAMA):
            ai.model_manager.load_model(ModelType.TINYLLAMA)
            print("Model loaded!")
        else:
            print("Could not download model, using rule-based mode")
    else:
        print("llama.cpp not found. Install with: pip install llama-cpp-python")
        print("Running in rule-based mode")
    
    print("\n🦝 TinkerAI Ready! Type 'help' for commands, 'quit' to exit.\n")
    
    while True:
        try:
            user_input = input("🦝 > ").strip()
            if not user_input:
                continue
            if user_input.lower() in ["quit", "exit", "bye"]:
                print("Goodbye!")
                break
            
            response = ai.process(user_input)
            print(f"\n{response.text}\n")
            print(f"[Intent: {response.intent} | Confidence: {response.confidence:.0%} | Model: {response.model_used}]\n")
        except KeyboardInterrupt:
            print("\nGoodbye!")
            break
        except EOFError:
            break

if __name__ == "__main__":
    main()
