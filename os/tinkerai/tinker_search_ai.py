#!/usr/bin/env python3
"""
TinkerSearchAI - local retrieval + summarisation AI for TinkerOS
===============================================================
Answers queries by hybrid retrieval (BM42 word tokens + char n-grams blended
with RNN hidden-state embeddings) over a local knowledge corpus, then
summarises the top results into a concise natural-language answer.

For follow-up questions it re-searches against the new query, summarising
again - this is invisible to the user (the search context is carried
silently).

Train builds the index + calibrates blend/threshold weights via a fast
leave-one-out check on a representative subset of the corpus.
"""
import sys, re, json, math
from pathlib import Path
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))

MODEL_DIR = Path.home() / ".tinker" / "ai" / "models"
INDEX_PATH = MODEL_DIR / "search-index.json"

# Static TinkerOS knowledge facts, paired with the dynamic QA corpus below.
FACTS = [
    ("tinkeros", "TinkerOS is a lightweight Linux distribution built for x86 tablets and convertibles. It ships a local AI assistant and on-device tools."),
    ("tinkerspace", "TinkerSpace is the project root and user workspace for the TinkerOS build."),
    ("local ai", "TinkerAI runs entirely on-device using a small numpy LSTM (char-level). No cloud calls are made for assistant answers."),
    ("computer use", "TinkerAI can use the computer: capture the screen, read it with OCR, and drive mouse and keyboard."),
    ("power", "Power tools: gaming for max performance and fps, balanced for normal use, battery saver to save power."),
    ("themes", "TinkerOS supports dark and light themes - dark mode and light mode."),
    ("apps", "Install, remove and launch applications like firefox, steam, terminal and file manager."),
    ("training", "The model trains in two stages: base Adam, then GaLore low-rank fine-tune, then a merge."),
    ("ai training", "Both TinkerAI (LSTM) and TinkerSearchAI (retrieval index) can be trained separately."),
    ("tinker search ai", "TinkerSearchAI is a local search assistant that retrieves and summarises knowledge to answer questions. Follow-ups re-search silently."),
]

_KW_RE = re.compile(r"[a-z0-9]+")
_GRAM_LEN = 3


def _tokens(text):
    return _KW_RE.findall(text.lower())

def _grams(text):
    t = text.lower()
    return [t[i:i + _GRAM_LEN] for i in range(len(t) - _GRAM_LEN + 1)] or [t]


def _idfs(texts_tokens):
    df = {}
    for toks in texts_tokens:
        for t in set(toks):
            df[t] = df.get(t, 0) + 1
    n = max(1, len(texts_tokens))
    return {t: math.log((1 + n) / (1 + d)) + 1.0 for t, d in df.items()}


class TinkerSearchAI:
    def __init__(self, rnn=None, tokenizer=None):
        self.rnn = rnn
        self.tokenizer = tokenizer
        self.docs = []
        self.idf = {}
        self.avgdl = 0.0
        self.bm25_k1 = 1.5
        self.bm25_b = 0.75
        self.bm25_w = 0.5
        self.embed_w = 0.5
        self.threshold = 0.0
        self.last_context = None

    def _embed(self, text):
        if not self.rnn or not self.tokenizer:
            return None
        ids = self.tokenizer.encode(text)
        if not ids:
            return None
        try:
            _, hidden = self.rnn.forward(np.array([ids]))
            v = hidden[0][0][0]
            n = float(np.linalg.norm(v))
            return v / n if n > 0 else v
        except Exception:
            return None

    @staticmethod
    def _cos(a, b):
        if a is None or b is None:
            return 0.0
        return float(np.dot(a, b))

    def _bm25(self, q_tokens, doc_tokens):
        if not doc_tokens:
            return 0.0
        dl = len(doc_tokens)
        avg = max(1.0, self.avgdl)
        counts = {}
        for t in doc_tokens:
            counts[t] = counts.get(t, 0) + 1
        score = 0.0
        for tok in set(q_tokens):
            if tok in counts:
                tf = counts[tok]
                idf = self.idf.get(tok, 1.5)
                num = tf * (self.bm25_k1 + 1)
                den = tf + self.bm25_k1 * (1 - self.bm25_b + self.bm25_b * dl / avg)
                score += idf * (num / den)
        return score

    def _raw_scores(self, q_tokens, q_grams, q_vec):
        raw = []
        for d in self.docs:
            b = self._bm25(q_tokens, d['q_tokens']) + self._bm25(q_tokens, d['a_tokens'])
            c = max(0.0, self._cos(q_vec, d['q_vec'])) if q_vec is not None else 0.0
            raw.append(self.bm25_w * b + self.embed_w * c)
        return np.array(raw) if raw else None

    @staticmethod
    def _norm(scores):
        if scores is None or len(scores) == 0:
            return None
        lo, hi = float(scores.min()), float(scores.max())
        if hi - lo < 1e-12:
            return np.ones_like(scores)
        return (scores - lo) / (hi - lo)

    def index_docs(self, docs):
        self.docs = []
        all_tokens = []
        for d in docs:
            q_tok = _tokens(d['q'])
            a_tok = _tokens(d['a'])
            q_vec = self._embed(d['q'])
            self.docs.append({
                'q': d['q'], 'a': d['a'], 'source': d.get('source', 'qa'),
                'q_tokens': q_tok, 'q_grams': _grams(d['q']), 'q_vec': q_vec,
                'a_tokens': a_tok, 'a_grams': _grams(d['a']),
            })
            all_tokens.append(q_tok + a_tok)
        self.idf = _idfs(all_tokens)
        dlens = [len(d['q_tokens']) + len(d['a_tokens']) for d in self.docs]
        self.avgdl = sum(dlens) / max(1, len(dlens))

    def _loo_recall(self, qa_docs, bw, ew, subset):
        """Leave-one-out: subset is a list of (global_index, doc) pairs.
        Returns (recall, [raw score of each correct self-match])."""
        old_bw, old_ew = self.bm25_w, self.embed_w
        self.bm25_w, self.embed_w = bw, ew
        hits = 0
        correct_scores = []
        for gi, doc in subset:
            q_tokens = doc['q_tokens']
            q_vec = doc['q_vec']
            raw = self._raw_scores(q_tokens, doc['q_grams'], q_vec)
            if raw is None:
                continue
            norm = self._norm(raw)
            correct_scores.append(float(raw[gi]))
            if norm is not None and norm[gi] >= norm.max():
                hits += 1
        self.bm25_w, self.embed_w = old_bw, old_ew
        recall = hits / max(1, len(subset))
        return recall, correct_scores

    def train(self, qa_pairs, facts=FACTS, calib_size=400, seed=1234):
        docs = [{'q': q, 'a': a, 'source': 'qa'} for q, a in qa_pairs] + \
               [{'q': q, 'a': a, 'source': 'fact'} for q, a in facts]
        self.index_docs(docs)
        qa_docs = [i for i, d in enumerate(self.docs) if d['source'] == 'qa']
        rng = np.random.default_rng(seed)
        subset_idx = rng.choice(qa_docs, size=min(calib_size, len(qa_docs)), replace=False)
        subset = [(int(idx), self.docs[idx]) for idx in subset_idx]

        # BM42 (word tokens + char n-grams) + embedding cosine blend.
        # Calibrate via leave-one-out on the subset; the correct answer doc
        # should rank #1 and its raw score forms the threshold.
        # (unrelated queries have raw scores ~<11, correct ones >= ~14)
        bw, ew = 0.2, 0.8
        rec, sc = self._loo_recall(qa_docs, bw, ew, subset)
        sc_sorted = sorted(sc)
        thr = sc_sorted[int(len(sc_sorted) * 0.10)] if sc_sorted else 0.0
        thr = max(thr, 1.0)
        self.bm25_w, self.embed_w, self.threshold = bw, ew, thr
        print(f"[search] trained on {len(self.docs)} docs "
              f"(qa={len(qa_docs)}, facts={len(docs)-len(qa_docs)}); "
              f"loo-recall={rec:.2f} blend bm25={bw} embed={ew}; "
              f"threshold={thr:.2f}", flush=True)

    def score_query(self, query):
        q_tokens = _tokens(query)
        q_vec = self._embed(query)
        raw = self._raw_scores(q_tokens, _grams(query), q_vec)
        return self._norm(raw)

    def score_raw(self, query):
        q_tokens = _tokens(query)
        q_vec = self._embed(query)
        raw = self._raw_scores(q_tokens, _grams(query), q_vec)
        return raw

    def search(self, query, topk=5):
        raw = self.score_raw(query)
        if raw is None:
            return [], 0.0
        order = np.argsort(-raw)
        ranked = [(self.docs[i], float(raw[i])) for i in order[:topk]]
        return ranked, float(raw.max() if raw.size else 0.0)

    def summarise(self, ranked, topk=3):
        if not ranked:
            return None, 0.0, []
        top_doc, top_score = ranked[0]
        parts = [top_doc['a']]
        # only append a 2nd distinct answer when it is very confident (near top)
        if len(ranked) > 1 and top_score > 0 and ranked[1][1] / top_score > 0.9:
            a = ranked[1][0]['a']
            if a and a not in parts:
                parts.append(a)
        summary = re.sub(r'\s+', ' ', '. '.join(parts)).strip().rstrip('.')
        return summary, top_score, [d['q'] for d, _ in ranked[:topk]]

    def answer(self, query):
        ranked, score = self.search(query, topk=5)
        summary, s, sources = self.summarise(ranked, topk=3)
        self.last_context = ranked[:5]
        if summary and score >= self.threshold:
            return summary, s, sources
        return None, s, sources

    def followup(self, query):
        ranked, score = self.search(query, topk=5)
        self.last_context = ranked[:5]
        summary, s, sources = self.summarise(ranked, topk=3)
        return summary, s, sources

    def save(self):
        MODEL_DIR.mkdir(parents=True, exist_ok=True)
        data = {
            'bm25_w': self.bm25_w, 'embed_w': self.embed_w, 'threshold': self.threshold,
            'avgdl': self.avgdl, 'idf': self.idf,
            'docs': [{'q': d['q'], 'a': d['a'], 'source': d.get('source', 'qa')} for d in self.docs],
        }
        INDEX_PATH.write_text(json.dumps(data, indent=2))
        print(f"[search] index saved: {INDEX_PATH}", flush=True)

    def load(self):
        if not INDEX_PATH.exists():
            return False
        data = json.loads(INDEX_PATH.read_text())
        self.bm25_w = data.get('bm25_w', 0.5)
        self.embed_w = data.get('embed_w', 0.5)
        self.threshold = data.get('threshold', 0.0)
        self.avgdl = data.get('avgdl', 0.0)
        self.idf = data.get('idf', {})
        self.docs = []
        for d in data.get('docs', []):
            q_vec = self._embed(d['q'])
            self.docs.append({
                'q': d['q'], 'a': d['a'], 'source': d.get('source', 'qa'),
                'q_tokens': _tokens(d['q']), 'q_grams': _grams(d['q']),
                'q_vec': q_vec, 'a_tokens': _tokens(d['a']), 'a_grams': _grams(d['a']),
            })
        print(f"[search] index loaded: {len(self.docs)} docs", flush=True)
        return True


def train_search():
    from data_generator import TINKER_TRAINING_DATA
    from small_rnn_model import TinkerRNN, TinkerTokenizer
    tok_path = MODEL_DIR / "tokenizer.json"
    model_path = MODEL_DIR / "rnn-model.json"
    if not tok_path.exists() or not model_path.exists():
        print("[search] need trained rnn model+tokenizer first")
        sys.exit(1)
    tokenizer = TinkerTokenizer()
    tokenizer.load(str(tok_path))
    model = TinkerRNN(vocab_size=tokenizer.vocab_size, embed_dim=96, hidden_dim=256)
    model.load(str(model_path))
    sa = TinkerSearchAI(rnn=model, tokenizer=tokenizer)
    sa.train(TINKER_TRAINING_DATA, FACTS)
    sa.save()
    for q, _ in TINKER_TRAINING_DATA[:3]:
        ans, sc, src = sa.answer(q)
        print(f"  Q: {q}\n  A: {ans}  (score {sc:.3f})", flush=True)


if __name__ == "__main__":
    train_search()
