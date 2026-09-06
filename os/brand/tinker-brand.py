#!/usr/bin/env python3
"""
TinkerOS Brand Identity System
Complete brand guidelines and asset generator
"""

from dataclasses import dataclass
from typing import Dict, List
import json
import os

@dataclass
class ColorPalette:
    primary: str = "#00D4AA"
    primary_dark: str = "#00B896"
    primary_light: str = "#33E0C0"
    secondary: str = "#6366F1"
    secondary_dark: str = "#4F46E5"
    secondary_light: str = "#818CF8"
    accent: str = "#F59E0B"
    accent_dark: str = "#D97706"
    accent_light: str = "#FCD34D"
    bg_primary: str = "#0D0D12"
    bg_secondary: str = "#12121A"
    bg_tertiary: str = "#1A1A26"
    bg_card: str = "#16161F"
    border: str = "#1E1E2E"
    text_primary: str = "#FFFFFF"
    text_secondary: str = "#E0E0E0"
    text_muted: str = "#888888"
    text_disabled: str = "#555555"
    success: str = "#10B981"
    warning: str = "#F59E0B"
    error: str = "#EF4444"
    info: str = "#3B82F6"

@dataclass
class Typography:
    font_sans: str = "Inter"
    font_mono: str = "JetBrains Mono"
    font_display: str = "Inter Tight"
    scale: Dict[str, float] = None
    def __post_init__(self):
        if self.scale is None:
            self.scale = {
                "xs": 0.75, "sm": 0.875, "base": 1.0, "lg": 1.125,
                "xl": 1.25, "2xl": 1.5, "3xl": 1.875, "4xl": 2.25,
                "5xl": 3.0, "6xl": 3.75,
            }

@dataclass
class Spacing:
    base: int = 4
    scale: Dict[str, int] = None
    def __post_init__(self):
        if self.scale is None:
            self.scale = {
                "0": 0, "1": 4, "2": 8, "3": 12, "4": 16, "5": 20,
                "6": 24, "8": 32, "10": 40, "12": 48, "16": 64,
                "20": 80, "24": 96,
            }

@dataclass
class BorderRadius:
    none: str = "0"
    sm: str = "4px"
    md: str = "8px"
    lg: str = "12px"
    xl: str = "16px"
    xxl: str = "24px"
    full: str = "9999px"

@dataclass
class Shadows:
    sm: str = "0 1px 2px rgba(0,0,0,0.3)"
    md: str = "0 4px 6px rgba(0,0,0,0.4)"
    lg: str = "0 10px 15px rgba(0,0,0,0.5)"
    xl: str = "0 20px 25px rgba(0,0,0,0.6)"
    glow: str = "0 0 20px rgba(0, 212, 170, 0.3)"
    glow_strong: str = "0 0 40px rgba(0, 212, 170, 0.5)"

@dataclass
class Transitions:
    fast: str = "150ms ease"
    normal: str = "200ms ease"
    slow: str = "300ms ease"

class TinkerBrand:
    def __init__(self):
        self.colors = ColorPalette()
        self.typography = Typography()
        self.spacing = Spacing()
        self.border_radius = BorderRadius()
        self.shadows = Shadows()
        self.transitions = Transitions()
        self.mascot = "🦝"
        self.name = "TinkerOS"
        self.tagline = "Your Computer. Your Rules."
        self.version = "7.2.0-rc6"
    
    def generate_css_variables(self) -> str:
        css = ":root {\n"
        for key, value in self.colors.__dict__.items():
            css += f"  --color-{key.replace('_', '-')}: {value};\n"
        css += "\n  /* Typography */\n"
        css += f"  --font-sans: '{self.typography.font_sans}', system-ui, sans-serif;\n"
        css += f"  --font-mono: '{self.typography.font_mono}', monospace;\n"
        css += f"  --font-display: '{self.typography.font_display}', system-ui, sans-serif;\n"
        for key, value in self.typography.scale.items():
            css += f"  --text-{key}: {value}rem;\n"
        css += "\n  /* Spacing */\n"
        for key, value in self.spacing.scale.items():
            css += f"  --space-{key}: {value}px;\n"
        css += "\n  /* Border Radius */\n"
        for key, value in self.border_radius.__dict__.items():
            css += f"  --radius-{key}: {value};\n"
        css += "\n  /* Shadows */\n"
        for key, value in self.shadows.__dict__.items():
            css += f"  --shadow-{key}: {value};\n"
        css += "\n  /* Transitions */\n"
        for key, value in self.transitions.__dict__.items():
            css += f"  --transition-{key}: {value};\n"
        css += "}\n"
        return css
    
    def generate_gtk_theme(self) -> str:
        return f"""
/* TinkerOS GTK Theme */
@define-color bg_color {self.colors.bg_primary};
@define-color fg_color {self.colors.text_primary};
@define-color base_color {self.colors.bg_card};
@define-color text_color {self.colors.text_primary};
@define-color selected_bg_color {self.colors.primary};
@define-color selected_fg_color #000000;
@define-color border_color {self.colors.border};
@define-color accent_color {self.colors.primary};
@define-color accent_bg_color {self.colors.primary_dark};
"""
    
    def generate_qt_stylesheet(self) -> str:
        return f"""
/* TinkerOS Qt Stylesheet */
QWidget {{ background-color: {self.colors.bg_primary}; color: {self.colors.text_primary}; font-family: "{self.typography.font_sans}"; }}
QPushButton {{ background-color: {self.colors.primary}; color: #000000; border: none; border-radius: 8px; padding: 10px 20px; font-weight: 600; }}
QPushButton:hover {{ background-color: {self.colors.primary_light}; }}
QLineEdit, QTextEdit, QComboBox {{ background-color: {self.colors.bg_card}; border: 1px solid {self.colors.border}; border-radius: 8px; padding: 8px 12px; }}
QScrollBar:vertical {{ background: transparent; width: 8px; }}
QScrollBar::handle:vertical {{ background: {self.colors.border}; border-radius: 4px; min-height: 30px; }}
QScrollBar::handle:vertical:hover {{ background: {self.colors.text_muted}; }}
"""
    
    def generate_brand_json(self) -> str:
        brand = {
            "name": self.name, "tagline": self.tagline, "version": self.version,
            "mascot": self.mascot,
            "colors": self.colors.__dict__, "typography": self.typography.__dict__,
            "spacing": self.spacing.__dict__, "border_radius": self.border_radius.__dict__,
            "shadows": self.shadows.__dict__, "transitions": self.transitions.__dict__,
        }
        return json.dumps(brand, indent=2)
    
    def generate_tailwind_config(self) -> str:
        return f"""/** @type {{import('tailwindcss').Config}} */
module.exports = {{
  darkMode: 'class',
  content: ['./src/**/*.{{html,js,ts,jsx,tsx}}'],
  theme: {{
    extend: {{
      colors: {{
        primary: {{ DEFAULT: '{self.colors.primary}', dark: '{self.colors.primary_dark}', light: '{self.colors.primary_light}' }},
        secondary: {{ DEFAULT: '{self.colors.secondary}', dark: '{self.colors.secondary_dark}', light: '{self.colors.secondary_light}' }},
        accent: {{ DEFAULT: '{self.colors.accent}', dark: '{self.colors.accent_dark}', light: '{self.colors.accent_light}' }},
        tinker: {{
          bg: '{self.colors.bg_primary}', 'bg-secondary': '{self.colors.bg_secondary}',
          'bg-tertiary': '{self.colors.bg_tertiary}', card: '{self.colors.bg_card}',
          border: '{self.colors.border}', 'text-primary': '{self.colors.text_primary}',
          'text-secondary': '{self.colors.text_secondary}', 'text-muted': '{self.colors.text_muted}',
        }},
        success: '{self.colors.success}', warning: '{self.colors.warning}',
        error: '{self.colors.error}', info: '{self.colors.info}',
      }},
      fontFamily: {{
        sans: ['{self.typography.font_sans}', 'system-ui', 'sans-serif'],
        mono: ['{self.typography.font_mono}', 'monospace'],
        display: ['{self.typography.font_display}', 'system-ui', 'sans-serif'],
      }},
      borderRadius: {{ none: '0', sm: '4px', md: '8px', lg: '12px', xl: '16px', '2xl': '24px', full: '9999px' }},
      boxShadow: {{ sm: '{self.shadows.sm}', md: '{self.shadows.md}', lg: '{self.shadows.lg}', xl: '{self.shadows.xl}', glow: '{self.shadows.glow}', 'glow-strong': '{self.shadows.glow_strong}' }},
      transitionDuration: {{ fast: '150ms', normal: '200ms', slow: '300ms' }},
    }},
  }},
  plugins: [],
}}
"""
    
    def save_all_assets(self, output_dir: str = "/home/tinkerspace/linux-kernel/os/brand/output"):
        os.makedirs(output_dir, exist_ok=True)
        with open(f"{output_dir}/variables.css", "w") as f: f.write(self.generate_css_variables())
        with open(f"{output_dir}/gtk-theme.css", "w") as f: f.write(self.generate_gtk_theme())
        with open(f"{output_dir}/qt-stylesheet.qss", "w") as f: f.write(self.generate_qt_stylesheet())
        with open(f"{output_dir}/brand.json", "w") as f: f.write(self.generate_brand_json())
        with open(f"{output_dir}/tailwind.config.js", "w") as f: f.write(self.generate_tailwind_config())
        print(f"Brand assets saved to {output_dir}")

if __name__ == "__main__":
    brand = TinkerBrand()
    brand.save_all_assets()
    print("TinkerOS Brand Identity System generated!")
    print(f"Name: {brand.name}, Tagline: {brand.tagline}")
    print(f"Primary: {brand.colors.primary}, Mascot: {brand.mascot}")
