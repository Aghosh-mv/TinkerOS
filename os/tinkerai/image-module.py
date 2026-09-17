#!/usr/bin/env python3
"""
TinkerAI Image Module v1.0
- Image Generation (diffusion-based, local, no cloud)
- Image Editing (add/remove/modify)
- Image Recognition (vision model)
- Graph Generation (charts, diagrams, plots)
- Link Opening (URL detection + browser launch)
"""
import os, sys, json, time, subprocess, hashlib, base64, io
from pathlib import Path
import logging

log = logging.getLogger(__name__)

# ============================================================
#  IMAGE GENERATION — Stable Diffusion pipeline (local)
# ============================================================

class ImageGenerator:
    """Local image generation using diffusers pipeline."""

    def __init__(self):
        self.model_id = "stabilityai/stable-diffusion-2-1"
        self.pipe = None
        self.device = "cpu"  # safe default

    def load(self):
        """Load the diffusion pipeline (lazy, takes ~30s on first use)."""
        if self.pipe is not None:
            return
        try:
            from diffusers import StableDiffusionPipeline
            import torch
            log.info(f"Loading {self.model_id}...")
            self.pipe = StableDiffusionPipeline.from_pretrained(
                self.model_id,
                torch_dtype=torch.float32,
                safety_checker=None,
                requires_safety_checker=False,
            )
            self.pipe = self.pipe.to(self.device)
            log.info("Image generator loaded.")
        except ImportError:
            log.error("diffusers not installed: pip install diffusers transformers accelerate")
            raise
        except Exception as e:
            log.error(f"Failed to load model: {e}")
            raise

    def generate(self, prompt, negative_prompt="", width=512, height=512, steps=25, guidance=7.5, seed=None):
        """Generate an image from a text prompt."""
        self.load()
        import torch

        if seed is not None:
            generator = torch.Generator(self.device).manual_seed(seed)
        else:
            generator = None

        result = self.pipe(
            prompt=prompt,
            negative_prompt=negative_prompt or "blurry, low quality, distorted, deformed",
            width=width, height=height,
            num_inference_steps=steps,
            guidance_scale=guidance,
            generator=generator,
        )

        image = result.images[0]
        # Save to output directory
        out_dir = Path.home() / ".local/share/korrinos/generated"
        out_dir.mkdir(parents=True, exist_ok=True)
        fname = f"gen_{int(time.time())}_{hashlib.md5(prompt.encode()).hexdigest()[:8]}.png"
        out_path = out_dir / fname
        image.save(str(out_path))
        return {"status": "ok", "path": str(out_path), "prompt": prompt}

    def edit(self, image_path, prompt, mask_path=None):
        """Edit an image — add/remove/modify elements."""
        self.load()
        from PIL import Image

        img = Image.open(image_path).convert("RGB").resize((512, 512))

        if mask_path:
            mask = Image.open(mask_path).convert("L").resize((512, 512))
        else:
            mask = None

        result = self.pipe(
            prompt=prompt,
            image=img,
            mask_image=mask,
            num_inference_steps=25,
        )

        out_dir = Path.home() / ".local/share/korrinos/generated"
        out_dir.mkdir(parents=True, exist_ok=True)
        fname = f"edit_{int(time.time())}.png"
        out_path = out_dir / fname
        result.images[0].save(str(out_path))
        return {"status": "ok", "path": str(out_path)}

    def generate_graph(self, data, chart_type="bar", title="Chart"):
        """Generate a graph/chart from data using matplotlib."""
        try:
            import matplotlib
            matplotlib.use('Agg')
            import matplotlib.pyplot as plt

            fig, ax = plt.subplots(figsize=(8, 5))

            if chart_type == "bar":
                ax.bar(range(len(data)), data, color='#6C9CFC')
            elif chart_type == "line":
                ax.plot(data, color='#6C9CFC', linewidth=2, marker='o')
            elif chart_type == "pie":
                ax.pie(data, labels=[f"Item {i+1}" for i in range(len(data))],
                       colors=['#6C9CFC', '#A78BFA', '#F472B6', '#34D399', '#FBBF24'])
            elif chart_type == "scatter":
                x = [d[0] for d in data] if isinstance(data[0], list) else range(len(data))
                y = [d[1] for d in data] if isinstance(data[0], list) else data
                ax.scatter(x, y, color='#6C9CFC', s=50)

            ax.set_title(title, fontsize=14, color='#333')
            ax.set_facecolor('#f8f9fa')
            fig.patch.set_facecolor('white')

            out_dir = Path.home() / ".local/share/korrinos/generated"
            out_dir.mkdir(parents=True, exist_ok=True)
            fname = f"graph_{int(time.time())}.png"
            out_path = out_dir / fname
            plt.savefig(str(out_path), dpi=150, bbox_inches='tight')
            plt.close()
            return {"status": "ok", "path": str(out_path), "type": chart_type}
        except ImportError:
            return {"status": "error", "msg": "matplotlib not installed"}
        except Exception as e:
            return {"status": "error", "msg": str(e)}

# ============================================================
#  IMAGE RECOGNITION — Local vision model
# ============================================================

class ImageRecognizer:
    """Local image recognition using transformers vision model."""

    def __init__(self):
        self.model_id = "microsoft/resnet-50"
        self.pipe = None

    def load(self):
        if self.pipe is not None:
            return
        try:
            from transformers import pipeline
            self.pipe = pipeline("image-classification", model=self.model_id)
            log.info("Image recognizer loaded.")
        except Exception as e:
            log.error(f"Failed to load vision model: {e}")
            raise

    def recognize(self, image_path):
        """Recognize objects in an image."""
        self.load()
        from PIL import Image
        img = Image.open(image_path).convert("RGB")
        results = self.pipe(img, top_k=5)
        return {
            "status": "ok",
            "predictions": [{"label": r["label"], "score": round(r["score"], 4)} for r in results]
        }

    def describe(self, image_path):
        """Generate a description of an image (uses BLIP)."""
        try:
            from transformers import pipeline
            pipe = pipeline("image-to-text", model="Salesforce/blip-image-captioning-base")
            from PIL import Image
            img = Image.open(image_path).convert("RGB")
            result = pipe(img)
            return {"status": "ok", "description": result[0]["generated_text"]}
        except Exception as e:
            return {"status": "error", "msg": str(e)}

# ============================================================
#  LINK OPENER — detects URLs and opens them
# ============================================================

class LinkOpener:
    """Detect URLs in text and open them in the default browser."""

    @staticmethod
    def extract_urls(text):
        """Extract all URLs from text."""
        import re
        url_pattern = re.compile(
            r'https?://(?:[-\w.]|(?:%[\da-fA-F]{2}))+(?:/[^\s]*)?'
        )
        return url_pattern.findall(text)

    @staticmethod
    def open_url(url):
        """Open a URL in the default browser."""
        try:
            subprocess.Popen(['xdg-open', url])
            return {"status": "ok", "msg": f"Opening: {url}"}
        except Exception as e:
            return {"status": "error", "msg": str(e)}

    @staticmethod
    def open_all(text):
        """Extract and open all URLs in text."""
        urls = LinkOpener.extract_urls(text)
        results = []
        for url in urls:
            results.append(LinkOpener.open_url(url))
        return {"status": "ok", "opened": len(urls), "urls": urls}

# ============================================================
#  UNIFIED API — for TinkerAI integration
# ============================================================

gen = ImageGenerator()
rec = ImageRecognizer()
links = LinkOpener()

def handle_image_request(action, params):
    """Route image-related requests."""
    if action == "generate":
        return gen.generate(
            prompt=params.get("prompt", ""),
            negative_prompt=params.get("negative", ""),
            width=params.get("width", 512),
            height=params.get("height", 512),
            steps=params.get("steps", 25),
            guidance=params.get("guidance", 7.5),
            seed=params.get("seed"),
        )
    elif action == "edit":
        return gen.edit(
            image_path=params.get("image", ""),
            prompt=params.get("prompt", ""),
            mask_path=params.get("mask"),
        )
    elif action == "graph":
        return gen.generate_graph(
            data=params.get("data", [1, 2, 3, 4, 5]),
            chart_type=params.get("type", "bar"),
            title=params.get("title", "Chart"),
        )
    elif action == "recognize":
        return rec.recognize(image_path=params.get("image", ""))
    elif action == "describe":
        return rec.describe(image_path=params.get("image", ""))
    elif action == "open_links":
        return links.open_all(text=params.get("text", ""))
    elif action == "open_url":
        return links.open_url(url=params.get("url", ""))
    else:
        return {"status": "error", "msg": f"Unknown image action: {action}"}

if __name__ == '__main__':
    # Quick test
    print("TinkerAI Image Module v1.0")
    print("Testing link extraction...")
    test = "Check out https://github.com and https://example.com for more info"
    urls = links.extract_urls(test)
    print(f"Found {len(urls)} URLs: {urls}")

    print("\nTesting graph generation...")
    result = gen.generate_graph([3, 7, 2, 8, 5], "bar", "Test Graph")
    print(result)
