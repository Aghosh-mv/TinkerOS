#!/usr/bin/env python3
"""
KorrinUILang Compiler — v0.1
Compiles .kui files to Korlang code, then to C, then to native binaries.

Declarative UI language inspired by SwiftUI, Flutter, Jetpack Compose.
"""

import sys
import os
import re
from dataclasses import dataclass, field
from typing import List, Optional, Dict, Any
from enum import Enum, auto

# ============================================================
#  TOKEN TYPES
# ============================================================
class TokenType(Enum):
    IDENT = auto()
    STRING_LIT = auto()
    INT_LIT = auto()
    FLOAT_LIT = auto()
    BOOL_LIT = auto()
    
    # Keywords
    COMPONENT = auto()
    STATE = auto()
    PROP = auto()
    BINDING = auto()
    COMPUTED = auto()
    BUILD = auto()
    IF = auto()
    ELSE = auto()
    FOR = auto()
    EACH = auto()
    IN = auto()
    LET = auto()
    MUT = auto()
    FN = auto()
    RETURN = auto()
    IMPORT = auto()
    AS = auto()
    ON = auto()
    TOGGLE = auto()
    TRUE = auto()
    FALSE = auto()
    
    # Layout components
    VSTACK = auto()
    HSTACK = auto()
    ZSTACK = auto()
    GRID = auto()
    SCROLL = auto()
    LIST = auto()
    
    # UI components
    TEXT = auto()
    IMAGE = auto()
    BUTTON = auto()
    TEXTFIELD = auto()
    TOGGLE_COMP = auto()
    SLIDER = auto()
    PICKER = auto()
    CARD = auto()
    MODAL = auto()
    SHEET = auto()
    NAV = auto()
    
    # Modifiers
    FONT = auto()
    COLOR = auto()
    BACKGROUND = auto()
    PADDING = auto()
    MARGIN = auto()
    CORNER_RADIUS = auto()
    SHADOW = auto()
    OPACITY = auto()
    FRAME = auto()
    ON_TAP = auto()
    ON_LONG_PRESS = auto()
    ANIMATION = auto()
    TRANSITION = auto()
    CLIP = auto()
    BORDER = auto()
    OFFSET = auto()
    ALIGN = auto()
    SPACING = auto()
    
    # Theme
    THEME = auto()
    DARK = auto()
    LIGHT = auto()
    GLASS = auto()
    VIOLET = auto()
    CYAN = auto()
    ORANGE = auto()
    
    # Animation
    SPRING = auto()
    EASE = auto()
    LINEAR = auto()
    BOUNCE = auto()
    
    # Special
    DOT = auto()
    COMMA = auto()
    COLON = auto()
    SEMICOLON = auto()
    EQ = auto()
    FAT_ARROW = auto()
    LPAREN = auto()
    RPAREN = auto()
    LBRACE = auto()
    RBRACE = auto()
    LBRACKET = auto()
    RBRACKET = auto()
    DOLLAR = auto()
    AT = auto()
    HASH = auto()
    NEWLINE = auto()
    INDENT = auto()
    DEDENT = auto()
    EOF = auto()

@dataclass
class Token:
    type: TokenType
    value: str
    line: int

# ============================================================
#  LEXER
# ============================================================
KEYWORDS = {
    'component': TokenType.COMPONENT, 'state': TokenType.STATE,
    'prop': TokenType.PROP, 'binding': TokenType.BINDING,
    'computed': TokenType.COMPUTED, 'build': TokenType.BUILD,
    'if': TokenType.IF, 'else': TokenType.ELSE,
    'for': TokenType.FOR, 'each': TokenType.EACH, 'in': TokenType.IN,
    'let': TokenType.LET, 'mut': TokenType.MUT, 'fn': TokenType.FN,
    'return': TokenType.RETURN, 'import': TokenType.IMPORT,
    'as': TokenType.AS, 'on': TokenType.ON, 'toggle': TokenType.TOGGLE,
    'true': TokenType.BOOL_LIT, 'false': TokenType.BOOL_LIT,
}

COMPONENTS = {
    'VStack': TokenType.VSTACK, 'HStack': TokenType.HSTACK,
    'ZStack': TokenType.ZSTACK, 'Grid': TokenType.GRID,
    'Scroll': TokenType.SCROLL, 'List': TokenType.LIST,
    'Text': TokenType.TEXT, 'Image': TokenType.IMAGE,
    'Button': TokenType.BUTTON, 'TextField': TokenType.TEXTFIELD,
    'Toggle': TokenType.TOGGLE_COMP, 'Slider': TokenType.SLIDER,
    'Picker': TokenType.PICKER, 'Card': TokenType.CARD,
    'Modal': TokenType.MODAL, 'Sheet': TokenType.SHEET,
    'Nav': TokenType.NAV,
}

MODIFIERS = {
    'font': TokenType.FONT, 'color': TokenType.COLOR,
    'background': TokenType.BACKGROUND, 'padding': TokenType.PADDING,
    'margin': TokenType.MARGIN, 'cornerRadius': TokenType.CORNER_RADIUS,
    'shadow': TokenType.SHADOW, 'opacity': TokenType.OPACITY,
    'frame': TokenType.FRAME, 'onTap': TokenType.ON_TAP,
    'onLongPress': TokenType.ON_LONG_PRESS,
    'animation': TokenType.ANIMATION, 'transition': TokenType.TRANSITION,
    'clip': TokenType.CLIP, 'border': TokenType.BORDER,
    'offset': TokenType.OFFSET, 'align': TokenType.ALIGN,
    'spacing': TokenType.SPACING,
}

THEME_VALS = {
    'dark': TokenType.DARK, 'light': TokenType.LIGHT, 'glass': TokenType.GLASS,
    'violet': TokenType.VIOLET, 'cyan': TokenType.CYAN, 'orange': TokenType.ORANGE,
    '.dark': TokenType.DARK, '.light': TokenType.LIGHT, '.glass': TokenType.GLASS,
    '.violet': TokenType.VIOLET, '.cyan': TokenType.CYAN, '.orange': TokenType.ORANGE,
}

ANIM_VALS = {
    'spring': TokenType.SPRING, 'ease': TokenType.EASE,
    'linear': TokenType.LINEAR, 'bounce': TokenType.BOUNCE,
}

class KUILexer:
    def __init__(self, source: str):
        self.source = source
        self.pos = 0
        self.line = 1
        self.tokens = []
    
    def peek(self, offset=0):
        p = self.pos + offset
        return self.source[p] if p < len(self.source) else '\0'
    
    def advance(self):
        ch = self.source[self.pos]
        self.pos += 1
        if ch == '\n':
            self.line += 1
        return ch
    
    def skip_whitespace(self):
        while self.pos < len(self.source) and self.source[self.pos] in ' \t\r':
            self.advance()
    
    def read_string(self, quote):
        result = []
        while self.pos < len(self.source) and self.source[self.pos] != quote:
            if self.source[self.pos] == '{':
                result.append('{')
                self.advance()
                depth = 1
                while self.pos < len(self.source) and depth > 0:
                    if self.source[self.pos] == '{': depth += 1
                    elif self.source[self.pos] == '}': depth -= 1
                    result.append(self.advance())
            elif self.source[self.pos] == '\\':
                self.advance()
                ch = self.advance()
                escapes = {'n': '\n', 't': '\t', '"': '"', "'": "'", '\\': '\\'}
                result.append(escapes.get(ch, ch))
            else:
                result.append(self.advance())
        if self.pos < len(self.source):
            self.advance()
        return ''.join(result)
    
    def read_ident(self):
        result = []
        while self.pos < len(self.source) and (self.source[self.pos].isalnum() or self.source[self.pos] in '_-.'):
            result.append(self.advance())
        return ''.join(result)
    
    def tokenize(self):
        while self.pos < len(self.source):
            self.skip_whitespace()
            if self.pos >= len(self.source):
                break
            
            ch = self.source[self.pos]
            
            if ch == '\n':
                self.advance()
                self.tokens.append(Token(TokenType.NEWLINE, '\\n', self.line))
                continue
            
            if ch == '#':
                self.advance()
                while self.pos < len(self.source) and self.source[self.pos] != '\n':
                    self.advance()
                continue
            
            if ch in '"\'':
                self.advance()
                val = self.read_string(ch)
                self.tokens.append(Token(TokenType.STRING_LIT, val, self.line))
                continue
            
            if ch.isdigit() or (ch == '.' and self.peek(1).isdigit()):
                num = []
                while self.pos < len(self.source) and (self.source[self.pos].isdigit() or self.source[self.pos] == '.'):
                    num.append(self.advance())
                val = ''.join(num)
                tt = TokenType.FLOAT_LIT if '.' in val else TokenType.INT_LIT
                self.tokens.append(Token(tt, val, self.line))
                continue
            
            if ch.isalpha() or ch == '_' or ch == '.':
                val = self.read_ident()
                
                if val in KEYWORDS:
                    self.tokens.append(Token(KEYWORDS[val], val, self.line))
                elif val in COMPONENTS:
                    self.tokens.append(Token(COMPONENTS[val], val, self.line))
                elif val in MODIFIERS:
                    self.tokens.append(Token(MODIFIERS[val], val, self.line))
                elif val in THEME_VALS:
                    self.tokens.append(Token(THEME_VALS[val], val, self.line))
                elif val in ANIM_VALS:
                    self.tokens.append(Token(ANIM_VALS[val], val, self.line))
                elif val == 'spacing':
                    self.tokens.append(Token(TokenType.SPACING, val, self.line))
                else:
                    self.tokens.append(Token(TokenType.IDENT, val, self.line))
                continue
            
            ops = {
                '=': TokenType.EQ, ':': TokenType.COLON, ';': TokenType.SEMICOLON,
                ',': TokenType.COMMA, '.': TokenType.DOT, '@': TokenType.AT,
                '#': TokenType.HASH, '$': TokenType.DOLLAR,
                '(': TokenType.LPAREN, ')': TokenType.RPAREN,
                '{': TokenType.LBRACE, '}': TokenType.RBRACE,
                '[': TokenType.LBRACKET, ']': TokenType.RBRACKET,
            }
            
            two = self.source[self.pos:self.pos+2]
            if two == '=>':
                self.advance(); self.advance()
                self.tokens.append(Token(TokenType.FAT_ARROW, '=>', self.line))
                continue
            
            if ch in ops:
                self.advance()
                self.tokens.append(Token(ops[ch], ch, self.line))
                continue
            
            self.advance()
        
        self.tokens.append(Token(TokenType.EOF, '', self.line))
        return self.tokens

# ============================================================
#  AST
# ============================================================
@dataclass
class KUINode:
    type: str
    value: Any = None
    children: List = field(default_factory=list)
    attrs: Dict = field(default_factory=dict)
    modifiers: List = field(default_factory=list)
    line: int = 0

# ============================================================
#  PARSER
# ============================================================
class KUIParser:
    def __init__(self, tokens):
        self.tokens = tokens
        self.pos = 0
    
    def peek(self, offset=0):
        p = self.pos + offset
        return self.tokens[p] if p < len(self.tokens) else Token(TokenType.EOF, '', 0)
    
    def advance(self):
        tok = self.tokens[self.pos]
        self.pos += 1
        return tok
    
    def expect(self, tt):
        tok = self.peek()
        if tok.type != tt:
            raise SyntaxError(f"Expected {tt.name}, got {tok.type.name} ({tok.value!r}) at line {tok.line}")
        return self.advance()
    
    def match(self, *types):
        if self.peek().type in types:
            return self.advance()
        return None
    
    def skip_newlines(self):
        while self.peek().type == TokenType.NEWLINE:
            self.advance()
    
    def parse(self):
        program = KUINode('program', children=[])
        self.skip_newlines()
        while self.peek().type != TokenType.EOF:
            if self.peek().type == TokenType.IMPORT:
                program.children.append(self.parse_import())
            elif self.peek().type == TokenType.COMPONENT:
                program.children.append(self.parse_component())
            else:
                self.advance()
            self.skip_newlines()
        return program
    
    def parse_import(self):
        self.expect(TokenType.IMPORT)
        path = []
        path.append(self.expect(TokenType.IDENT).value)
        while self.match(TokenType.DOT):
            path.append(self.expect(TokenType.IDENT).value)
        self.skip_newlines()
        return KUINode('import', value='.'.join(path))
    
    def parse_component(self):
        self.expect(TokenType.COMPONENT)
        name = self.expect(TokenType.IDENT).value
        self.skip_newlines()
        self.expect(TokenType.LBRACE)
        self.skip_newlines()
        
        props = []
        build_block = None
        
        while self.peek().type != TokenType.RBRACE:
            tok = self.peek()
            if tok.type == TokenType.STATE:
                props.append(self.parse_state())
            elif tok.type == TokenType.PROP:
                props.append(self.parse_prop())
            elif tok.type == TokenType.BINDING:
                props.append(self.parse_binding())
            elif tok.type == TokenType.COMPUTED:
                props.append(self.parse_computed())
            elif tok.type == TokenType.BUILD:
                build_block = self.parse_build()
            else:
                self.advance()
            self.skip_newlines()
        
        self.expect(TokenType.RBRACE)
        return KUINode('component', value=name, children=props + ([build_block] if build_block else []))
    
    def parse_state(self):
        self.expect(TokenType.STATE)
        name = self.expect(TokenType.IDENT).value
        self.expect(TokenType.COLON)
        typ = self.expect(TokenType.IDENT).value
        self.expect(TokenType.EQ)
        default = self.parse_value()
        self.skip_newlines()
        return KUINode('state', value=name, attrs={'type': typ, 'default': default})
    
    def parse_prop(self):
        self.expect(TokenType.PROP)
        name = self.expect(TokenType.IDENT).value
        self.expect(TokenType.COLON)
        typ = self.expect(TokenType.IDENT).value
        self.skip_newlines()
        return KUINode('prop', value=name, attrs={'type': typ})
    
    def parse_binding(self):
        self.expect(TokenType.BINDING)
        name = self.expect(TokenType.IDENT).value
        self.expect(TokenType.COLON)
        typ = self.expect(TokenType.IDENT).value
        self.skip_newlines()
        return KUINode('binding', value=name, attrs={'type': typ})
    
    def parse_computed(self):
        self.expect(TokenType.COMPUTED)
        name = self.expect(TokenType.IDENT).value
        self.expect(TokenType.COLON)
        typ = self.expect(TokenType.IDENT).value
        self.expect(TokenType.EQ)
        expr = self.parse_value()
        self.skip_newlines()
        return KUINode('computed', value=name, attrs={'type': typ, 'expr': expr})
    
    def parse_build(self):
        self.expect(TokenType.BUILD)
        self.skip_newlines()
        self.expect(TokenType.LBRACE)
        self.skip_newlines()
        children = []
        while self.peek().type != TokenType.RBRACE:
            node = self.parse_element()
            if node:
                children.append(node)
            self.skip_newlines()
        self.expect(TokenType.RBRACE)
        return KUINode('build', children=children)
    
    def parse_element(self):
        self.skip_newlines()
        tok = self.peek()
        
        if tok.type == TokenType.IF:
            return self.parse_if_element()
        elif tok.type == TokenType.FOR:
            return self.parse_for_element()
        elif tok.type in COMPONENTS:
            return self.parse_component_usage()
        elif tok.type == TokenType.IDENT:
            # Could be a variable reference
            return self.parse_variable_ref()
        return None
    
    def parse_if_element(self):
        self.expect(TokenType.IF)
        condition = self.parse_value()
        self.skip_newlines()
        self.expect(TokenType.LBRACE)
        self.skip_newlines()
        then_children = []
        while self.peek().type != TokenType.RBRACE:
            node = self.parse_element()
            if node:
                then_children.append(node)
            self.skip_newlines()
        self.expect(TokenType.RBRACE)
        self.skip_newlines()
        
        else_children = []
        if self.match(TokenType.ELSE):
            self.skip_newlines()
            self.expect(TokenType.LBRACE)
            self.skip_newlines()
            while self.peek().type != TokenType.RBRACE:
                node = self.parse_element()
                if node:
                    else_children.append(node)
                self.skip_newlines()
            self.expect(TokenType.RBRACE)
        
        return KUINode('if', value=condition, children=then_children, attrs={'else': else_children})
    
    def parse_for_element(self):
        self.expect(TokenType.FOR)
        var_name = self.expect(TokenType.IDENT).value
        self.expect(TokenType.IN)
        collection = self.parse_value()
        self.skip_newlines()
        self.expect(TokenType.LBRACE)
        self.skip_newlines()
        children = []
        while self.peek().type != TokenType.RBRACE:
            node = self.parse_element()
            if node:
                children.append(node)
            self.skip_newlines()
        self.expect(TokenType.RBRACE)
        return KUINode('for', value=var_name, children=children, attrs={'collection': collection})
    
    def parse_component_usage(self):
        comp_type = self.advance().value
        
        # Parse attributes in parentheses
        attrs = {}
        if self.peek().type == TokenType.LPAREN:
            self.advance()
            while self.peek().type != TokenType.RPAREN:
                key = self.expect(TokenType.IDENT).value
                self.expect(TokenType.COLON)
                val = self.parse_value()
                attrs[key] = val
                self.match(TokenType.COMMA)
            self.expect(TokenType.RPAREN)
        
        # Parse modifiers (chained .method calls)
        modifiers = []
        while self.peek().type == TokenType.DOT:
            self.advance()
            mod_name = self.expect(TokenType.IDENT).value
            mod_args = []
            if self.peek().type == TokenType.LPAREN:
                self.advance()
                while self.peek().type != TokenType.RPAREN:
                    mod_args.append(self.parse_value())
                    self.match(TokenType.COMMA)
                self.expect(TokenType.RPAREN)
            elif self.peek().type == TokenType.LBRACE:
                # Closure/modifier block
                self.advance()
                body = []
                while self.peek().type != TokenType.RBRACE:
                    body.append(self.parse_value())
                self.expect(TokenType.RBRACE)
                mod_args = body
            modifiers.append({'name': mod_name, 'args': mod_args})
        
        # Parse children (if followed by { })
        children = []
        self.skip_newlines()
        if self.peek().type == TokenType.LBRACE:
            self.advance()
            self.skip_newlines()
            while self.peek().type != TokenType.RBRACE:
                child = self.parse_element()
                if child:
                    children.append(child)
                self.skip_newlines()
            self.expect(TokenType.RBRACE)
        
        return KUINode('element', value=comp_type, children=children, attrs=attrs, modifiers=modifiers)
    
    def parse_variable_ref(self):
        name = self.expect(TokenType.IDENT).value
        return KUINode('variable', value=name)
    
    def parse_value(self):
        """Parse a value (string, number, bool, ident, expression)."""
        tok = self.peek()
        if tok.type == TokenType.STRING_LIT:
            self.advance()
            return tok.value
        elif tok.type == TokenType.INT_LIT:
            self.advance()
            return int(tok.value)
        elif tok.type == TokenType.FLOAT_LIT:
            self.advance()
            return float(tok.value)
        elif tok.type == TokenType.BOOL_LIT:
            self.advance()
            return tok.value == 'true'
        elif tok.type == TokenType.IDENT:
            self.advance()
            return tok.value
        elif tok.type == TokenType.DOT:
            # Theme value like .violet
            self.advance()
            val = self.expect(TokenType.IDENT).value
            return f".{val}"
        elif tok.type == TokenType.LPAREN:
            self.advance()
            val = self.parse_value()
            self.expect(TokenType.RPAREN)
            return val
        else:
            self.advance()
            return tok.value

# ============================================================
#  KORLANG CODE GENERATOR
# ============================================================
class KUICodeGen:
    """Generates Korlang code from KorrinUILang AST."""
    
    def __init__(self):
        self.output = []
        self.indent = 0
        self.component_count = 0
    
    def generate(self, node: KUINode) -> str:
        self.emit_header()
        self.gen_node(node)
        return '\n'.join(self.output)
    
    def emit(self, line):
        self.output.append("    " * self.indent + line)
    
    def emit_header(self):
        self.emit("/* Generated by KorrinUILang compiler v0.1 */")
        self.emit("import korrinui")
        self.emit("import korrinui.render")
        self.emit("")
    
    def gen_node(self, node: KUINode):
        method = f"gen_{node.type}"
        if hasattr(self, method):
            getattr(self, method)(node)
    
    def gen_program(self, node):
        for child in node.children:
            self.gen_node(child)
            self.emit("")
    
    def gen_import(self, node):
        self.emit(f"import {node.value}")
    
    def gen_component(self, node):
        name = node.value
        self.emit(f"component {name} {{")
        self.indent += 1
        
        build_node = None
        for child in node.children:
            if child.type == 'state':
                self.emit(f"    state {child.value}: {child.attrs['type']} = {self.default_val(child.attrs['default'])}")
            elif child.type == 'prop':
                self.emit(f"    prop {child.value}: {child.attrs['type']}")
            elif child.type == 'binding':
                self.emit(f"    binding {child.value}: {child.attrs['type']}")
            elif child.type == 'computed':
                self.emit(f"    computed {child.value}: {child.attrs['type']} = {child.attrs['expr']}")
            elif child.type == 'build':
                build_node = child
        
        if build_node:
            self.emit("")
            self.emit("    build {")
            self.indent += 1
            for child in build_node.children:
                self.gen_element(child)
            self.indent -= 1
            self.emit("    }")
        
        self.indent -= 1
        self.emit("}")
    
    def gen_element(self, node):
        if node.type == 'element':
            self.gen_component_call(node)
        elif node.type == 'if':
            self.gen_if_element(node)
        elif node.type == 'for':
            self.gen_for_element(node)
        elif node.type == 'variable':
            self.emit(f"/* ref: {node.value} */")
    
    def gen_component_call(self, node):
        comp = node.value
        attrs = node.attrs
        modifiers = node.modifiers
        children = node.children
        
        # Build attribute string
        attr_parts = []
        for k, v in attrs.items():
            attr_parts.append(f"{k}: {self.fmt_val(v)}")
        attr_str = ", ".join(attr_parts)
        
        if children:
            self.emit(f"{comp}({attr_str}) {{")
            self.indent += 1
            for mod in modifiers:
                self.gen_modifier(mod)
            for child in children:
                self.gen_element(child)
            self.indent -= 1
            self.emit(f"}}")
        else:
            line = f"{comp}({attr_str})"
            for mod in modifiers:
                line += f".{mod['name']}({', '.join(self.fmt_val(a) for a in mod['args'])})"
            self.emit(line + "")
    
    def gen_modifier(self, mod):
        args = ", ".join(self.fmt_val(a) for a in mod['args'])
        self.emit(f".{mod['name']}({args})")
    
    def gen_if_element(self, node):
        self.emit(f"if {node.value} {{")
        self.indent += 1
        for child in node.children:
            self.gen_element(child)
        self.indent -= 1
        if node.attrs.get('else'):
            self.emit("} else {")
            self.indent += 1
            for child in node.attrs['else']:
                self.gen_element(child)
            self.indent -= 1
        self.emit("}")
    
    def gen_for_element(self, node):
        self.emit(f"for {node.value} in {node.attrs['collection']} {{")
        self.indent += 1
        for child in node.children:
            self.gen_element(child)
        self.indent -= 1
        self.emit("}")
    
    def fmt_val(self, v):
        if isinstance(v, str):
            if v.startswith('.'):
                return v
            return f'"{v}"'
        elif isinstance(v, bool):
            return "true" if v else "false"
        return str(v)
    
    def default_val(self, v):
        if isinstance(v, str):
            return f'"{v}"'
        elif isinstance(v, bool):
            return "true" if v else "false"
        return str(v)

# ============================================================
#  COMPILER DRIVER
# ============================================================
class KorrinUILangCompiler:
    def __init__(self, filename):
        self.filename = filename
    
    def compile(self):
        with open(self.filename) as f:
            source = f.read()
        
        lexer = KUILexer(source)
        tokens = lexer.tokenize()
        
        parser = KUIParser(tokens)
        ast = parser.parse()
        
        codegen = KUICodeGen()
        korlang_code = codegen.generate(ast)
        
        return korlang_code
    
    def compile_to_file(self, output):
        code = self.compile()
        with open(output, 'w') as f:
            f.write(code)
        print(f"KorrinUILang: {self.filename} -> {output}")
        return output

def main():
    if len(sys.argv) < 2:
        print("Usage: korrinuilang <file.kui> [-o output.kor]")
        sys.exit(1)
    
    filename = sys.argv[1]
    output = None
    
    if '-o' in sys.argv:
        idx = sys.argv.index('-o')
        output = sys.argv[idx + 1]
    
    if not output:
        output = os.path.splitext(filename)[0] + '.kor'
    
    compiler = KorrinUILangCompiler(filename)
    compiler.compile_to_file(output)

if __name__ == '__main__':
    main()
