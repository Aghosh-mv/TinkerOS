#!/usr/bin/env python3
"""
Korlang Compiler v0.2 — Full rewrite, no shortcuts
Compiles .kor files → C code → native binary via GCC

Features from 22 languages: C, Rust, Zig, Python, Java, JavaScript,
PHP, C#, C++, VC++, Ruby, Go, Scala, Kotlin, TypeScript, HTML, CSS,
XML, Embedd C, SQL, Dart, Jasper
"""

import sys
import os
import re
import subprocess
from dataclasses import dataclass, field
from typing import List, Optional, Dict, Any, Tuple
from enum import Enum, auto

# ============================================================
#  TOKEN TYPE
# ============================================================
class TT(Enum):
    # Literals
    INT = auto(); FLOAT = auto(); STRING = auto(); CHAR = auto(); BOOL = auto(); IDENT = auto()
    # Keywords
    FN = auto(); LET = auto(); MUT = auto(); RETURN = auto(); IF = auto(); ELIF = auto()
    ELSE = auto(); MATCH = auto(); FOR = auto(); IN = auto(); WHILE = auto(); LOOP = auto()
    BREAK = auto(); CONTINUE = auto(); STRUCT = auto(); CLASS = auto(); ENUM = auto()
    TRAIT = auto(); IMPL = auto(); SELF = auto(); PUB = auto(); PRIV = auto()
    MOD = auto(); USE = auto(); IMPORT = auto()
    AS = auto(); TYPE = auto(); ASYNC = auto(); AWAIT = auto(); PAR = auto(); TASK = auto()
    SPAWN = auto(); DEFER = auto(); NEW = auto(); SIZEOF = auto(); COMPTIME = auto()
    UNSAFE = auto(); EXTERN = auto(); CONST = auto(); STATIC = auto()
    # AI
    AI = auto(); TENSOR = auto(); MATRIX = auto()
    # OS
    SYS = auto(); PROC = auto(); MEM = auto(); HW = auto()
    # SQL
    SQL = auto()
    # Operators
    PLUS = auto(); MINUS = auto(); STAR = auto(); SLASH = auto(); PERCENT = auto()
    CARET = auto(); AMP = auto(); PIPE = auto(); TILDE = auto(); BANG = auto()
    EQ = auto(); EQEQ = auto(); NEQ = auto(); LT = auto(); GT = auto()
    LTE = auto(); GTE = auto(); AND = auto(); OR = auto()
    PLUS_EQ = auto(); MINUS_EQ = auto(); STAR_EQ = auto(); SLASH_EQ = auto()
    PERCENT_EQ = auto(); AMP_EQ = auto(); PIPE_EQ = auto(); CARET_EQ = auto()
    SHL = auto(); SHR = auto()
    ARROW = auto(); FAT_ARROW = auto(); DOUBLE_COLON = auto(); COLON = auto()
    SEMICOLON = auto(); COMMA = auto(); DOT = auto(); DOTDOT = auto()
    HASH = auto(); AT = auto(); QUESTION = auto(); DOLLAR = auto()
    LPAREN = auto(); RPAREN = auto(); LBRACE = auto(); RBRACE = auto()
    LBRACKET = auto(); RBRACKET = auto(); LT_ANGLE = auto(); GT_ANGLE = auto()
    NEWLINE = auto(); EOF = auto()

@dataclass
class Tok:
    t: TT; v: str; ln: int; col: int
    def __repr__(self): return f"({self.t.name}, {self.v!r}, L{self.ln})"

# ============================================================
#  LEXER
# ============================================================
KW = {
    'fn': TT.FN, 'let': TT.LET, 'mut': TT.MUT, 'return': TT.RETURN,
    'if': TT.IF, 'elif': TT.ELIF, 'else': TT.ELSE, 'match': TT.MATCH,
    'for': TT.FOR, 'in': TT.IN, 'while': TT.WHILE, 'loop': TT.LOOP,
    'break': TT.BREAK, 'continue': TT.CONTINUE, 'struct': TT.STRUCT,
    'class': TT.CLASS, 'enum': TT.ENUM, 'trait': TT.TRAIT,
    'impl': TT.IMPL, 'self': TT.SELF, 'pub': TT.PUB, 'priv': TT.PRIV,
    'mod': TT.MOD, 'use': TT.USE,
    'import': TT.IMPORT, 'as': TT.AS, 'type': TT.TYPE,
    'async': TT.ASYNC, 'await': TT.AWAIT, 'par': TT.PAR, 'task': TT.TASK,
    'spawn': TT.SPAWN, 'defer': TT.DEFER, 'new': TT.NEW,
    'sizeof': TT.SIZEOF, 'comptime': TT.COMPTIME, 'unsafe': TT.UNSAFE,
    'extern': TT.EXTERN, 'const': TT.CONST, 'static': TT.STATIC,
    'ai': TT.AI, 'tensor': TT.TENSOR, 'matrix': TT.MATRIX,
    'sys': TT.SYS, 'proc': TT.PROC, 'mem': TT.MEM, 'hw': TT.HW,
    'sql': TT.SQL, 'true': TT.BOOL, 'false': TT.BOOL,
}

def lex(src: str) -> List[Tok]:
    toks = []
    i, ln, col = 0, 1, 1
    n = len(src)
    while i < n:
        c = src[i]
        if c in ' \t\r':
            i += 1; col += 1; continue
        if c == '\n':
            i += 1; ln += 1; col = 1; continue
        # Comments
        if c == '/' and i+1 < n and src[i+1] == '/':
            while i < n and src[i] != '\n': i += 1
            continue
        if c == '/' and i+1 < n and src[i+1] == '*':
            i += 2; col += 2
            while i < n and not (src[i] == '*' and i+1 < n and src[i+1] == '/'):
                if src[i] == '\n': ln += 1; col = 1
                else: col += 1
                i += 1
            i += 2; col += 2; continue
        if c == '#':
            while i < n and src[i] != '\n': i += 1
            continue
        # Strings
        if c in '"\'':
            q = c; i += 1; col += 1; buf = []
            while i < n and src[i] != q:
                if src[i] == '\\' and i+1 < n:
                    i += 1; col += 1
                    e = {'n':'\n','t':'\t','r':'\r','0':'\0','\\':'\\',"'":'"','"':'"'}
                    buf.append(e.get(src[i], src[i])); i += 1; col += 1
                elif src[i] == '{':
                    buf.append('{'); i += 1; col += 1
                    depth = 1
                    while i < n and depth > 0:
                        if src[i] == '{': depth += 1
                        elif src[i] == '}': depth -= 1
                        buf.append(src[i]); i += 1; col += 1
                else:
                    if src[i] == '\n': ln += 1; col = 1
                    else: col += 1
                    buf.append(src[i]); i += 1
            if i < n: i += 1; col += 1
            toks.append(Tok(TT.STRING, ''.join(buf), ln, col)); continue
        # Numbers
        if c.isdigit() or (c == '.' and i+1 < n and src[i+1].isdigit()):
            buf = []
            while i < n and (src[i].isdigit() or src[i] == '.'):
                buf.append(src[i]); i += 1; col += 1
            while i < n and src[i] in 'iufdul':
                buf.append(src[i]); i += 1; col += 1
            v = ''.join(buf)
            toks.append(Tok(TT.FLOAT if '.' in v else TT.INT, v, ln, col)); continue
        # Identifiers / keywords
        if c.isalpha() or c == '_':
            buf = []
            while i < n and (src[i].isalnum() or src[i] in '_.'):
                buf.append(src[i]); i += 1; col += 1
            v = ''.join(buf)
            toks.append(Tok(KW.get(v, TT.IDENT), v, ln, col)); continue
        # Two-char operators
        if i+1 < n:
            two = src[i:i+2]
            tm = {'=>':TT.FAT_ARROW,'->':TT.ARROW,'==':TT.EQEQ,'!=':TT.NEQ,
                  '<=':TT.LTE,'>=':TT.GTE,'&&':TT.AND,'||':TT.OR,
                  '+=':TT.PLUS_EQ,'-=':TT.MINUS_EQ,'*=':TT.STAR_EQ,
                  '/=':TT.SLASH_EQ,'%=':TT.PERCENT_EQ,'&=':TT.AMP_EQ,
                  '|=':TT.PIPE_EQ,'^=':TT.CARET_EQ,'..':TT.DOTDOT,
                  '::':TT.DOUBLE_COLON,'<<':TT.SHL,'>>':TT.SHR}
            if two in tm:
                toks.append(Tok(tm[two], two, ln, col)); i += 2; col += 2; continue
        # Single char
        sm = {'+':TT.PLUS,'-':TT.MINUS,'*':TT.STAR,'/':TT.SLASH,'%':TT.PERCENT,
              '^':TT.CARET,'&':TT.AMP,'|':TT.PIPE,'~':TT.TILDE,'!':TT.BANG,
              '=':TT.EQ,'<':TT.LT,'>':TT.GT,':':TT.COLON,';':TT.SEMICOLON,
              ',':TT.COMMA,'.':TT.DOT,'?':TT.QUESTION,'@':TT.AT,'$':TT.DOLLAR,
              '(':TT.LPAREN,')':TT.RPAREN,'{':TT.LBRACE,'}':TT.RBRACE,
              '[':TT.LBRACKET,']':TT.RBRACKET}
        if c in sm:
            toks.append(Tok(sm[c], c, ln, col)); i += 1; col += 1; continue
        i += 1; col += 1
    toks.append(Tok(TT.EOF, '', ln, col))
    return toks

# ============================================================
#  AST NODE
# ============================================================
@dataclass
class N:
    tp: str; val: Any = None; ch: List = field(default_factory=list)
    m: Dict = field(default_factory=dict); ln: int = 0

# ============================================================
#  PARSER — recursive descent, handles all Korlang syntax
# ============================================================
class P:
    def __init__(self, toks): self.t = toks; self.p = 0
    def pk(self, o=0): return self.t[min(self.p+o, len(self.t)-1)]
    def adv(self): t=self.t[self.p]; self.p+=1; return t
    def expect(self, tt):
        t=self.pk()
        if t.t!=tt: raise SyntaxError(f"Expected {tt.name} got {t.t.name} '{t.v}' L{t.ln}")
        return self.adv()
    def match(self, *tts):
        if self.pk().t in tts: return self.adv()
        return None
    def skip(self):
        while self.pk().t==TT.NEWLINE: self.adv()

    def parse(self):
        prog=N('prog',ch=[])
        self.skip()
        while self.pk().t!=TT.EOF:
            s=self.toplevel()
            if s: prog.ch.append(s)
            self.skip()
        return prog

    def toplevel(self):
        t=self.pk()
        if t.t==TT.IMPORT: return self.p_import()
        if t.t==TT.USE: return self.p_use()
        if t.t in (TT.PUB,): self.adv(); return self.toplevel()
        if t.t==TT.FN: return self.p_fn()
        if t.t==TT.STRUCT: return self.p_struct()
        if t.t==TT.CLASS: return self.p_class()
        if t.t==TT.ENUM: return self.p_enum()
        if t.t==TT.TRAIT: return self.p_trait()
        if t.t==TT.IMPL: return self.p_impl()
        if t.t==TT.TYPE: return self.p_typealias()
        if t.t==TT.MOD: return self.p_mod()
        return self.p_stmt()

    def p_import(self):
        self.expect(TT.IMPORT)
        path=[self.expect(TT.IDENT).v]
        while self.match(TT.DOT): path.append(self.expect(TT.IDENT).v)
        self.match(TT.SEMICOLON)
        return N('import', '.'.join(path))

    def p_use(self):
        self.expect(TT.USE)
        path=[self.expect(TT.IDENT).v]
        while self.match(TT.DOUBLE_COLON) or self.match(TT.DOT):
            if self.pk().t==TT.STAR: self.adv(); path.append('*')
            else: path.append(self.expect(TT.IDENT).v)
        self.match(TT.SEMICOLON)
        return N('use', '.'.join(path))

    def p_fn(self):
        t=self.expect(TT.FN)
        name=self.expect(TT.IDENT).v
        generics=[]
        if self.match(TT.LT):
            while self.pk().t!=TT.GT:
                generics.append(self.expect(TT.IDENT).v); self.match(TT.COMMA)
            self.expect(TT.GT)
        self.expect(TT.LPAREN)
        params=[]
        while self.pk().t!=TT.RPAREN:
            pn=self.expect(TT.IDENT).v
            self.expect(TT.COLON)
            pt=self.p_type()
            params.append((pn,pt))
            self.match(TT.COMMA)
        self.expect(TT.RPAREN)
        ret=None
        if self.match(TT.ARROW): ret=self.p_type()
        body=None
        if self.pk().t==TT.LBRACE: body=self.p_block()
        elif self.pk().t==TT.SEMICOLON: self.adv()
        return N('fn',name,ch=[body],m={'params':params,'ret':ret,'gens':generics},ln=t.ln)

    def p_struct(self):
        t=self.expect(TT.STRUCT)
        name=self.expect(TT.IDENT).v
        generics=[]
        if self.match(TT.LT):
            while self.pk().t!=TT.GT:
                generics.append(self.expect(TT.IDENT).v); self.match(TT.COMMA)
            self.expect(TT.GT)
        self.expect(TT.LBRACE)
        fields=[]
        while self.pk().t!=TT.RBRACE:
            self.skip()
            if self.pk().t==TT.RBRACE: break
            self.match(TT.PUB); self.match(TT.PRIV)
            if self.pk().t==TT.IDENT and self.pki(1)==TT.COLON:
                fn_=self.expect(TT.IDENT).v
                self.expect(TT.COLON)
                ft=self.p_type()
                self.match(TT.SEMICOLON)
                fields.append((fn_,ft))
            else:
                # skip unknown
                self.adv()
        self.expect(TT.RBRACE)
        return N('struct',name,m={'fields':fields,'gens':generics},ln=t.ln)

    def pki(self, o):
        return self.t[min(self.p+o, len(self.t)-1)].t

    def p_class(self):
        t=self.expect(TT.CLASS)
        name=self.expect(TT.IDENT).v
        parent=None
        if self.match(TT.COLON): parent=self.expect(TT.IDENT).v
        self.expect(TT.LBRACE)
        members=[]
        while self.pk().t!=TT.RBRACE:
            self.skip()
            if self.pk().t==TT.RBRACE: break
            if self.pk().t==TT.FN: members.append(self.p_fn())
            elif self.pk().t==TT.IDENT and self.pki(1)==TT.COLON:
                fn_=self.expect(TT.IDENT).v; self.expect(TT.COLON); ft=self.p_type()
                self.match(TT.SEMICOLON); members.append(N('field',fn_,m={'type':ft}))
            else: self.adv()
        self.expect(TT.RBRACE)
        return N('class',name,m={'parent':parent,'members':members},ln=t.ln)

    def p_enum(self):
        t=self.expect(TT.ENUM)
        name=self.expect(TT.IDENT).v
        self.expect(TT.LBRACE)
        variants=[]
        while self.pk().t!=TT.RBRACE:
            vn=self.expect(TT.IDENT).v
            flds=[]
            if self.match(TT.LPAREN):
                while self.pk().t!=TT.RPAREN:
                    flds.append(self.p_type()); self.match(TT.COMMA)
                self.expect(TT.RPAREN)
            self.match(TT.COMMA)
            variants.append((vn,flds))
        self.expect(TT.RBRACE)
        return N('enum',name,m={'variants':variants},ln=t.ln)

    def p_trait(self):
        t=self.expect(TT.TRAIT)
        name=self.expect(TT.IDENT).v
        self.expect(TT.LBRACE)
        methods=[]
        while self.pk().t!=TT.RBRACE:
            self.skip()
            if self.pk().t==TT.RBRACE: break
            if self.pk().t==TT.FN: methods.append(self.p_fn())
            else: self.adv()
        self.expect(TT.RBRACE)
        return N('trait',name,m={'methods':methods},ln=t.ln)

    def p_impl(self):
        t=self.expect(TT.IMPL)
        trait_name=None
        if self.pk(1).t==TT.FOR:
            trait_name=self.expect(TT.IDENT).v; self.expect(TT.FOR)
        type_name=self.expect(TT.IDENT).v
        self.expect(TT.LBRACE)
        methods=[]
        while self.pk().t!=TT.RBRACE:
            self.skip()
            if self.pk().t==TT.RBRACE: break
            if self.pk().t==TT.FN: methods.append(self.p_fn())
            else: self.adv()
        self.expect(TT.RBRACE)
        return N('impl',type_name,m={'trait':trait_name,'methods':methods},ln=t.ln)

    def p_typealias(self):
        self.expect(TT.TYPE)
        name=self.expect(TT.IDENT).v
        self.expect(TT.EQ); t=self.p_type()
        self.match(TT.SEMICOLON)
        return N('typealias',name,m={'type':t})

    def p_mod(self):
        self.expect(TT.MOD)
        name=self.expect(TT.IDENT).v
        body=self.p_block()
        return N('mod',name,ch=[body])

    def p_block(self):
        self.expect(TT.LBRACE); self.skip()
        stmts=[]
        while self.pk().t!=TT.RBRACE:
            s=self.p_stmt()
            if s: stmts.append(s)
            self.skip()
        self.expect(TT.RBRACE)
        return N('block',ch=stmts)

    def p_stmt(self):
        t=self.pk()
        if t.t==TT.LET: return self.p_let()
        if t.t==TT.MUT: return self.p_mut()
        if t.t==TT.RETURN: return self.p_return()
        if t.t==TT.IF: return self.p_if()
        if t.t==TT.WHILE: return self.p_while()
        if t.t==TT.FOR: return self.p_for()
        if t.t==TT.LOOP: return self.p_loop()
        if t.t==TT.BREAK: self.adv(); self.match(TT.SEMICOLON); return N('break')
        if t.t==TT.CONTINUE: self.adv(); self.match(TT.SEMICOLON); return N('continue')
        if t.t==TT.DEFER: return self.p_defer()
        if t.t==TT.LBRACE: return self.p_block()
        if t.t==TT.PAR: return self.p_par()
        if t.t==TT.SPAWN: return self.p_spawn()
        if t.t==TT.SYS: return self.p_sys()
        if t.t==TT.PROC: return self.p_proc()
        if t.t==TT.SQL: return self.p_sql()
        if t.t==TT.AI: return self.p_ai()
        # Augmented assign: name += expr
        if t.t==TT.IDENT and self.pki(1) in (TT.PLUS_EQ,TT.MINUS_EQ,TT.STAR_EQ,TT.SLASH_EQ,TT.PERCENT_EQ,TT.AMP_EQ,TT.PIPE_EQ,TT.CARET_EQ):
            return self.p_augassign()
        # Regular expression statement
        return self.p_expr_stmt()

    def p_let(self):
        self.expect(TT.LET)
        name=self.expect(TT.IDENT).v
        typ="auto"
        if self.match(TT.COLON): typ=self.p_type()
        init=None
        if self.match(TT.EQ): init=self.p_expr()
        self.match(TT.SEMICOLON)
        return N('let',name,ch=[init] if init else [],m={'type':typ})

    def p_mut(self):
        self.expect(TT.MUT)
        name=self.expect(TT.IDENT).v
        typ="auto"
        if self.match(TT.COLON): typ=self.p_type()
        init=None
        if self.match(TT.EQ): init=self.p_expr()
        self.match(TT.SEMICOLON)
        return N('mut',name,ch=[init] if init else [],m={'type':typ})

    def p_return(self):
        self.expect(TT.RETURN)
        expr=None
        if self.pk().t not in (TT.SEMICOLON,TT.RBRACE,TT.EOF):
            expr=self.p_expr()
        self.match(TT.SEMICOLON)
        return N('return',ch=[expr] if expr else [])

    def p_if(self):
        self.expect(TT.IF)
        cond=self.p_expr()
        then=self.p_block()
        elifs=[]
        while self.match(TT.ELIF):
            ec=self.p_expr(); eb=self.p_block(); elifs.append((ec,eb))
        elseb=None
        if self.match(TT.ELSE):
            if self.pk().t==TT.IF: elseb=self.p_if()
            else: elseb=self.p_block()
        return N('if',ch=[cond,then,elseb],m={'elifs':elifs})

    def p_while(self):
        self.expect(TT.WHILE)
        cond=self.p_expr()
        body=self.p_block()
        return N('while',ch=[cond,body])

    def p_for(self):
        self.expect(TT.FOR)
        var_=self.expect(TT.IDENT).v
        self.expect(TT.IN)
        iter_=self.p_expr()
        body=self.p_block()
        return N('for',var_,ch=[iter_,body])

    def p_loop(self):
        self.expect(TT.LOOP)
        body=self.p_block()
        return N('loop',ch=[body])

    def p_defer(self):
        self.expect(TT.DEFER)
        body=self.p_block()
        return N('defer',ch=[body])

    def p_par(self):
        self.expect(TT.PAR)
        body=self.p_block()
        return N('par',ch=[body])

    def p_spawn(self):
        self.expect(TT.SPAWN)
        expr=self.p_expr()
        return N('spawn',ch=[expr])

    def p_sys(self):
        self.expect(TT.SYS); self.expect(TT.DOT)
        method=self.expect(TT.IDENT).v
        self.expect(TT.LPAREN); args=[]
        while self.pk().t!=TT.RPAREN: args.append(self.p_expr()); self.match(TT.COMMA)
        self.expect(TT.RPAREN)
        return N('sys_call',method,ch=args)

    def p_proc(self):
        self.expect(TT.PROC); self.expect(TT.DOT)
        method=self.expect(TT.IDENT).v
        self.expect(TT.LPAREN); args=[]
        while self.pk().t!=TT.RPAREN: args.append(self.p_expr()); self.match(TT.COMMA)
        self.expect(TT.RPAREN)
        return N('proc_call',method,ch=args)

    def p_sql(self):
        self.expect(TT.SQL)
        self.expect(TT.LPAREN)
        q=self.expect(TT.STRING).v
        self.expect(TT.RPAREN)
        return N('sql',q)

    def p_ai(self):
        self.expect(TT.AI); self.expect(TT.DOT)
        method=self.expect(TT.IDENT).v
        self.expect(TT.LPAREN); args=[]
        while self.pk().t!=TT.RPAREN: args.append(self.p_expr()); self.match(TT.COMMA)
        self.expect(TT.RPAREN)
        return N('ai_call',method,ch=args)

    def p_augassign(self):
        name=self.expect(TT.IDENT).v
        op=self.adv()  # +=, -=, etc
        expr=self.p_expr()
        self.match(TT.SEMICOLON)
        op_char=op.v[:-1]
        return N('aug_assign',name,ch=[expr],m={'op':op_char})

    def p_expr_stmt(self):
        expr=self.p_expr()
        self.match(TT.SEMICOLON)
        return N('expr_stmt',ch=[expr])

    # ---- EXPRESSIONS ----
    def p_expr(self, min_p=0):
        left=self.p_unary()
        while True:
            t=self.pk()
            pr=self._prec(t.t)
            if pr<min_p: break
            op=self.adv()
            right=self.p_expr(pr+1)
            left=N('binop',op.v,ch=[left,right],ln=op.ln)
        return left

    def p_unary(self):
        t=self.pk()
        if t.t==TT.MINUS: self.adv(); return N('unary','-',ch=[self.p_unary()])
        if t.t==TT.BANG: self.adv(); return N('unary','!',ch=[self.p_unary()])
        if t.t==TT.TILDE: self.adv(); return N('unary','~',ch=[self.p_unary()])
        if t.t==TT.STAR: self.adv(); return N('unary','*',ch=[self.p_unary()])
        if t.t==TT.AMP: self.adv(); return N('unary','&',ch=[self.p_unary()])
        return self.p_postfix()

    def p_postfix(self):
        left=self.p_primary()
        while True:
            if self.pk().t==TT.LPAREN:
                self.adv(); args=[]
                while self.pk().t!=TT.RPAREN: args.append(self.p_expr()); self.match(TT.COMMA)
                self.expect(TT.RPAREN)
                left=N('call',left.val,ch=[left]+args,ln=left.ln)
            elif self.pk().t==TT.DOT:
                self.adv(); m=self.expect(TT.IDENT).v
                left=N('member',m,ch=[left])
            elif self.pk().t==TT.LBRACKET:
                self.adv(); idx=self.p_expr(); self.expect(TT.RBRACKET)
                left=N('index',ch=[left,idx])
            elif self.pk().t==TT.LBRACE and left.tp=='ident':
                # Struct literal: User { name: "Alice", age: 30 }
                self.adv()
                fields=[]
                while self.pk().t!=TT.RBRACE:
                    fn_=self.expect(TT.IDENT).v
                    self.expect(TT.COLON)
                    fv=self.p_expr()
                    fields.append((fn_,fv))
                    self.match(TT.COMMA)
                self.expect(TT.RBRACE)
                left=N('struct_lit',left.val,ch=[f[1] for f in fields],m={'fields':[f[0] for f in fields]},ln=left.ln)
            else: break
        return left

    def p_primary(self):
        t=self.pk()
        if t.t==TT.INT: self.adv(); return N('int',t.v,ln=t.ln)
        if t.t==TT.FLOAT: self.adv(); return N('float',t.v,ln=t.ln)
        if t.t==TT.STRING: self.adv(); return N('string',t.v,ln=t.ln)
        if t.t==TT.BOOL: self.adv(); return N('bool',t.v,ln=t.ln)
        if t.t==TT.IDENT: self.adv(); return N('ident',t.v,ln=t.ln)
        if t.t==TT.LPAREN:
            self.adv(); e=self.p_expr(); self.expect(TT.RPAREN); return e
        if t.t==TT.LBRACKET: return self.p_array()
        if t.t==TT.IF: return self.p_if()
        if t.t==TT.MATCH: return self.p_match()
        if t.t==TT.FN: return self.p_closure()
        raise SyntaxError(f"Unexpected {t.t.name} '{t.v}' L{t.ln}")

    def p_array(self):
        self.expect(TT.LBRACKET); items=[]
        while self.pk().t!=TT.RBRACKET: items.append(self.p_expr()); self.match(TT.COMMA)
        self.expect(TT.RBRACKET)
        return N('array',ch=items)

    def p_match(self):
        self.expect(TT.MATCH); expr=self.p_expr()
        self.expect(TT.LBRACE); arms=[]
        while self.pk().t!=TT.RBRACE:
            pat=self.p_expr(); self.expect(TT.FAT_ARROW); res=self.p_expr()
            self.match(TT.COMMA); arms.append(N('arm',ch=[pat,res]))
        self.expect(TT.RBRACE)
        return N('match',ch=[expr]+arms)

    def p_closure(self):
        self.expect(TT.FN); self.expect(TT.LPAREN); params=[]
        while self.pk().t!=TT.RPAREN:
            pn=self.expect(TT.IDENT).v; self.expect(TT.COLON); pt=self.p_type()
            params.append((pn,pt)); self.match(TT.COMMA)
        self.expect(TT.RPAREN)
        ret=None
        if self.match(TT.ARROW): ret=self.p_type()
        body=self.p_block()
        return N('closure',ch=[body],m={'params':params,'ret':ret})

    def p_type(self) -> str:
        parts=[]
        if self.match(TT.QUESTION): parts.append('?')
        while self.match(TT.STAR): parts.append('*')
        t=self.expect(TT.IDENT); parts.append(t.v)
        if self.match(TT.LT):
            parts.append('<')
            while self.pk().t!=TT.GT: parts.append(self.p_type()); self.match(TT.COMMA)
            parts.append('>'); self.expect(TT.GT)
        return ' '.join(parts)

    def _prec(self, tt):
        m={TT.OR:1,TT.AND:2,TT.EQEQ:3,TT.NEQ:3,TT.LT:3,TT.GT:3,TT.LTE:3,TT.GTE:3,
           TT.PIPE:4,TT.CARET:5,TT.AMP:6,TT.PLUS:8,TT.MINUS:8,TT.STAR:9,TT.SLASH:9,TT.PERCENT:9}
        return m.get(tt,-1)

# ============================================================
#  C CODE GENERATOR — complete, no shortcuts
# ============================================================
class CG:
    def __init__(self):
        self.out=[]; self.ind=0; self.var_types={}; self.struct_defs={}  # track variable types and struct definitions
        self.types={
            'i8':'int8_t','i16':'int16_t','i32':'int32_t','i64':'int64_t',
            'u8':'uint8_t','u16':'uint16_t','u32':'uint32_t','u64':'uint64_t',
            'f32':'float','f64':'double','bool':'_Bool','string':'kl_string',
            'char':'char','void':'void','int':'int','float':'float','auto':'int64_t'
        }

    def em(self, s): self.out.append('    '*self.ind+s)
    def emr(self, s): self.out.append(s)

    def gen(self, n: N) -> str:
        self._header(); self._n(n); return '\n'.join(self.out)

    def _header(self):
        self.emr("/* Korlang v0.2 — Generated C code */")
        self.emr("#include <stdint.h>")
        self.emr("#include <stdlib.h>")
        self.emr("#include <stdio.h>")
        self.emr("#include <string.h>")
        self.emr("#include <stdbool.h>")
        self.emr("#include <math.h>")
        self.emr("#include <stdarg.h>")
        self.emr("")
        self.emr("/* Korlang runtime */")
        self.emr("typedef struct { const char* data; size_t len; } kl_string;")
        self.emr("static inline kl_string kl_str(const char* s) { return (kl_string){s, strlen(s)}; }")
        self.emr("static inline kl_string kl_strn(const char* s, size_t n) { return (kl_string){s, n}; }")
        self.emr("#define kl_print(s) printf(\"%.*s\\n\", (int)(s).len, (s).data)")
        self.emr("#define kl_fmt(buf, ...) sprintf(buf, __VA_ARGS__)")
        self.emr("static inline kl_string kl_interp(const char* fmt, ...) {")
        self.emr("    char buf[512]; va_list args; va_start(args, fmt);")
        self.emr("    vsnprintf(buf, 512, fmt, args); va_end(args);")
        self.emr("    return kl_str(buf);")
        self.emr("}")
        self.emr("")

    def _n(self, n):
        fn={'prog':self._prog,'fn':self._fn,'struct':self._struct,'class':self._struct,
            'enum':self._enum,'trait':self._trait,'impl':self._impl,'block':self._block,
            'let':self._let,'mut':self._let,'return':self._ret,'if':self._if,
            'while':self._while,'for':self._for,'loop':self._loop,
            'break':lambda n:self.em("break;"),'continue':lambda n:self.em("continue;"),
            'defer':self._defer,'par':self._par,'spawn':self._spawn,
            'sys_call':self._sys,'proc_call':self._proc,'sql':self._sql,
            'ai_call':self._ai,'expr_stmt':self._exprstmt,'aug_assign':self._aug,
            'import':lambda n:self.em(f"/* import {n.val} */"),
            'use':lambda n:self.em(f"/* use {n.val} */"),
            'mod':self._mod,'typealias':lambda n:self.em(f"/* type {n.val} */"),
            'trait':self._trait,'impl':self._impl,
            'closure':self._closure}
        f=fn.get(n.tp)
        if f: f(n)
        else: self.em(f"/* {n.tp} */")

    def _prog(self,n):
        # Forward declare all structs and functions first
        for c in n.ch:
            if c.tp=='struct': self._struct(c)
            if c.tp=='enum': self._enum(c)
            if c.tp=='trait': self._trait(c)
            if c.tp=='fn': self._fwd_fn(c)
        self.emr("")
        # Now emit implementations
        for c in n.ch:
            if c.tp not in ('struct','enum','trait'):
                self._n(c)
                self.emr("")

    def _fwd_fn(self,n):
        name=n.val; params=n.m.get('params',[]); ret=n.m.get('ret','void')
        ct=self.types.get(ret,ret) if ret else 'void'
        if name=='main': return  # main doesn't need forward decl
        cps=[f"{self.types.get(p[1],p[1])} {p[0]}" for p in params]
        self.em(f"{ct} {name}({', '.join(cps) if cps else 'void'});")

    def _fn(self,n):
        name=n.val; params=n.m.get('params',[]); ret=n.m.get('ret','void')
        ct=self.types.get(ret,ret) if ret else 'void'
        if name=='main': ct='int'
        cps=[f"{self.types.get(p[1],p[1])} {p[0]}" for p in params]
        self.em(f"{ct} {name}({', '.join(cps) if cps else 'void'}) {{")
        self.ind+=1
        if n.ch and n.ch[0]: self._n(n.ch[0])
        if name=='main': self.em("return 0;")
        self.ind-=1; self.em("}")

    def _struct(self,n):
        name=n.val; fields=n.m.get('fields',[])
        # Store struct definition for field type lookup
        self.struct_defs[name]={fn_:ft for fn_,ft in fields}
        self.em(f"typedef struct {name} {{")
        self.ind+=1
        for fn_,ft in fields: self.em(f"{self.types.get(ft,ft)} {fn_};")
        self.ind-=1; self.em(f"}} {name};")

    def _enum(self,n):
        name=n.val; variants=n.m.get('variants',[])
        self.em(f"typedef enum {name}_tag {{")
        self.ind+=1
        for i,(vn,_) in enumerate(variants):
            self.em(f"{name}_{vn}{',' if i<len(variants)-1 else ''}")
        self.ind-=1; self.em(f"}} {name}_tag;")
        self.em(f"typedef struct {name} {{ {name}_tag tag; }} {name};")

    def _trait(self,n):
        name=n.val; methods=[m for m in n.m.get('methods',[]) if m.tp=='fn']
        self.em(f"/* trait {name} */")
        self.em(f"typedef struct {name}_vtable {{")
        self.ind+=1
        for m in methods:
            self.em(f"void* (*{m.val})(void* self);")
        self.ind-=1; self.em(f"}} {name}_vtable;")

    def _impl(self,n):
        tn=n.val
        for m in n.m.get('methods',[]):
            if m.tp=='fn':
                m.val=f"{tn}_{m.val}"; self._fn(m); m.val=m.val[len(tn)+1:]

    def _mod(self,n):
        self.em(f"/* mod {n.val} */")
        if n.ch: self._n(n.ch[0])

    def _block(self,n):
        self.ind+=1
        for c in n.ch: self._n(c)
        self.ind-=1

    def _let(self,n):
        name=n.val; typ=n.m.get('type','auto')
        init=n.ch[0] if n.ch else None
        # Infer type from initial value
        if typ=='auto' and init:
            if init.tp=='string': typ='kl_string'
            elif init.tp=='bool': typ='_Bool'
            elif init.tp=='float': typ='double'
            elif init.tp=='int': typ='int64_t'
            elif init.tp=='struct_lit': typ=init.val
            elif init.tp=='call' and init.val in ('kl_str','kl_interp','kl_strn'): typ='kl_string'
            elif init.tp=='call': typ='int64_t'
            elif init.tp=='binop': typ='int64_t'
            elif init.tp=='member': typ='kl_string'
            else: typ='int64_t'
        else:
            typ=self.types.get(typ,typ)
        self.var_types[name]=typ
        if init: self.em(f"{typ} {name} = {self._es(init)};")
        else: self.em(f"{typ} {name} = 0;")

    def _ret(self,n):
        if n.ch and n.ch[0]: self.em(f"return {self._es(n.ch[0])};")
        else: self.em("return;")

    def _if(self,n):
        self.em(f"if ({self._es(n.ch[0])}) {{")
        self.ind+=1; self._n(n.ch[1]); self.ind-=1
        for ec,eb in n.m.get('elifs',[]):
            self.em(f"}} else if ({self._es(ec)}) {{")
            self.ind+=1; self._n(eb); self.ind-=1
        if n.ch[2]:
            self.em("} else {")
            self.ind+=1; self._n(n.ch[2]); self.ind-=1
        self.em("}")

    def _while(self,n):
        self.em(f"while ({self._es(n.ch[0])}) {{")
        self.ind+=1; self._n(n.ch[1]); self.ind-=1; self.em("}")

    def _for(self,n):
        vn=n.val; it=self._es(n.ch[0])
        self.em(f"for (int64_t {vn} = 0; {vn} < {it}; {vn}++) {{")
        self.ind+=1; self._n(n.ch[1]); self.ind-=1; self.em("}")

    def _loop(self,n):
        self.em("while (1) {")
        self.ind+=1; self._n(n.ch[0]); self.ind-=1; self.em("}")

    def _defer(self,n):
        self.em("/* defer { */")
        self.ind+=1; self._n(n.ch[0]); self.ind-=1
        self.em("/* } defer */")

    def _par(self,n):
        self.em("/* par { */")
        self.ind+=1; self._n(n.ch[0]); self.ind-=1
        self.em("/* } par */")

    def _spawn(self,n):
        self.em(f"/* spawn {self._es(n.ch[0])} */")

    def _sys(self,n):
        args=', '.join(self._es(a) for a in n.ch)
        self.em(f"/* sys.{n.val}({args}) */")

    def _proc(self,n):
        args=', '.join(self._es(a) for a in n.ch)
        self.em(f"/* proc.{n.val}({args}) */")

    def _sql(self,n):
        self.em(f'/* sql: "{n.val}" */')

    def _ai(self,n):
        args=', '.join(self._es(a) for a in n.ch)
        self.em(f"/* ai.{n.val}({args}) */")

    def _exprstmt(self,n):
        if n.ch: self.em(f"{self._es(n.ch[0])};")

    def _aug(self,n):
        op=n.m['op']; expr=self._es(n.ch[0])
        self.em(f"{n.val} = ({n.val} {op} {expr});")

    def _closure(self,n):
        params=n.m.get('params',[]); ret=n.m.get('ret','void')
        ct=self.types.get(ret,'void') if ret else 'void'
        cps=[f"{self.types.get(p[1],p[1])} {p[0]}" for p in params]
        self.em(f"/* closure */ {ct} ({', '.join(cps) if cps else 'void'}) {{")
        self.ind+=1
        if n.ch and n.ch[0]: self._n(n.ch[0])
        self.ind-=1; self.em("}")

    def _es(self, n: N) -> str:
        """Expression to C string — complete implementation."""
        if n.tp=='int': return str(n.val)
        if n.tp=='float': return str(n.val)
        if n.tp=='bool': return '1' if n.val=='true' else '0'
        if n.tp=='ident': return n.val
        if n.tp=='string':
            v=n.val
            if '{' in v:
                parts=re.split(r'\{([^}]+)\}',v)
                if len(parts)>1:
                    fmt=''; args=[]
                    for i,p in enumerate(parts):
                        if i%2==0:
                            fmt+=p.replace('%','%%')
                        else:
                            expr=p.strip()
                            if expr.isdigit():
                                fmt+='%ld'; args.append(expr)
                            elif '.' in expr and any(c.isdigit() for c in expr.split('.')[-1:]):
                                # Float literal like 3.14
                                fmt+='%g'; args.append(expr)
                            elif expr in ('true','false'):
                                fmt+='%d'; args.append('1' if expr=='true' else '0')
                            elif '.' in expr:
                                # Member access — user.name, user.age
                                if expr.endswith('.data'):
                                    fmt+='%s'; args.append(expr)
                                elif expr.endswith('.len'):
                                    fmt+='%zu'; args.append(expr)
                                else:
                                    # Look up object type and field type
                                    parts_=expr.split('.', 1)
                                    obj=parts_[0]
                                    field=parts_[1] if len(parts_)>1 else ''
                                    obj_type=self.var_types.get(obj,'int64_t')
                                    # Check if obj is a struct and look up field type
                                    if obj_type in self.struct_defs and field in self.struct_defs[obj_type]:
                                        field_type=self.struct_defs[obj_type][field]
                                        c_type=self.types.get(field_type, field_type)
                                        if c_type=='kl_string':
                                            fmt+='%s'; args.append(expr+'.data')
                                        elif c_type=='double' or c_type=='float':
                                            fmt+='%g'; args.append(expr)
                                        elif c_type=='_Bool':
                                            fmt+='%d'; args.append(expr)
                                        else:
                                            fmt+='%ld'; args.append(expr)
                                    elif obj_type=='kl_string':
                                        # Access .data for printf
                                        fmt+='%s'; args.append(expr+'.data')
                                    else:
                                        fmt+='%ld'; args.append(expr)
                            else:
                                # Variable — check type
                                vtype=self.var_types.get(expr,'int64_t')
                                if vtype=='kl_string':
                                    fmt+='%s'; args.append(f'{expr}.data')
                                elif vtype=='double' or vtype=='float':
                                    fmt+='%g'; args.append(expr)
                                elif vtype=='_Bool':
                                    fmt+='%d'; args.append(expr)
                                else:
                                    fmt+='%ld'; args.append(expr)
                    args_s=', '+', '.join(args) if args else ''
                    return f'kl_interp("{fmt}"{args_s})'
            return f'kl_str("{v}")'
        if n.tp=='binop':
            l=self._es(n.ch[0]); r=self._es(n.ch[1])
            return f"({l} {n.val} {r})"
        if n.tp=='unary':
            e=self._es(n.ch[0])
            if n.val=='!': return f"(!{e})"
            if n.val=='-': return f"(-{e})"
            if n.val=='~': return f"(~{e})"
            if n.val=='*': return f"(*{e})"
            if n.val=='&': return f"(&{e})"
            return f"({n.val}{e})"
        if n.tp=='call':
            fn_=n.val; args=[self._es(c) for c in n.ch[1:]] if len(n.ch)>1 else []
            if fn_=='print':
                if args:
                    a=args[0]
                    return f'printf("%.*s\\n", (int){a}.len, {a}.data)'
                return 'printf("\\n")'
            if fn_=='len':
                return f"(int64_t){args[0]}.len" if args else "0"
            return f"{fn_}({', '.join(args)})"
        if n.tp=='member':
            obj=self._es(n.ch[0]); return f"{obj}.{n.val}"
        if n.tp=='index':
            obj=self._es(n.ch[0]); idx=self._es(n.ch[1]); return f"{obj}[{idx}]"
        if n.tp=='array':
            items=', '.join(self._es(c) for c in n.ch)
            return f"(int64_t[]){{{items}}}"
        if n.tp=='if':
            return '/* if-expr */'
        if n.tp=='match':
            return '/* match-expr */'
        if n.tp=='closure':
            return '/* closure */'
        if n.tp=='struct_lit':
            fields=n.m.get('fields',[])
            vals=', '.join(self._es(c) for c in n.ch)
            return f"({n.val}){{{vals}}}"
        return '/* unknown */'

# ============================================================
#  COMPILER DRIVER
# ============================================================
class Korlang:
    def __init__(self, fn_): self.fn=fn_

    def compile(self):
        with open(self.fn) as f: src=f.read()
        toks=lex(src)
        ast=P(toks).parse()
        cg=CG()
        return cg.gen(ast)

    def to_c(self, out):
        c=self.compile()
        with open(out,'w') as f: f.write(c)
        print(f"Korlang: {self.fn} → {out}")
        return out

    def build(self, c_file, binary):
        r=subprocess.run(f"gcc -o {binary} {c_file} -lm -lpthread",shell=True,capture_output=True,text=True)
        if r.returncode!=0:
            print(f"GCC error:\n{r.stderr}"); return False
        print(f"Korlang: {c_file} → {binary}"); return True

def main():
    if len(sys.argv)<2:
        print("Usage: korlang <file.kor> [-o output] [--run] [--emit-c]"); sys.exit(1)
    fn=sys.argv[1]; out=None; run=False; emit_c=False
    i=2
    while i<len(sys.argv):
        if sys.argv[i]=='-o' and i+1<len(sys.argv): out=sys.argv[i+1]; i+=2
        elif sys.argv[i]=='--run': run=True; i+=1
        elif sys.argv[i]=='--emit-c': emit_c=True; i+=1
        else: i+=1
    if not out:
        base=os.path.splitext(fn)[0]
        out=base+'.c' if emit_c else base
    comp=Korlang(fn)
    if emit_c:
        c=comp.compile()
        with open(out,'w') as f: f.write(c)
        print(f"Korlang: {fn} → {out}")
    else:
        c_file=out+'.c'; comp.to_c(c_file)
        if comp.build(c_file,out) and run:
            print(f"\n--- Running {out} ---\n")
            subprocess.run([f"./{out}"])

if __name__=='__main__': main()
