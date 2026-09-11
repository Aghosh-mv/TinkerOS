#!/usr/bin/env bash
# language.sh — multilingual support, translation, language detection

# Detect language of text (basic heuristic)
ai_lang_detect() {
  local text="$1"
  python3 -c "
import re
text = '''$text'''

# Language patterns (common words/characters)
langs = {
    'english': (r'\b(the|is|are|was|were|have|has|had|will|would|could|should|can|may|might|this|that|with|from|for|and|but|not|you|they|we|she|he|it|a|an|in|on|at|to|of)\b', 0.6),
    'spanish': (r'\b(el|la|los|las|es|son|está|hay|tiene|tienen|con|por|para|como|pero|este|esta|eso|del|más|también|puede|todo|bien|aquí|donde|cuando)\b', 0.5),
    'french': (r'\b(le|la|les|des|est|sont|avec|pour|dans|mais|que|qui|cette|tout|bien|aussi|peut|nous|vous|ils|elle|comme|fait|être|avoir)\b', 0.5),
    'german': (r'\b(der|die|das|ist|sind|mit|für|auf|und|aber|nicht|auch|kann|noch|wie|oder|wenn|man|nur|dass|ich|sie|wir|nach|bei)\b', 0.5),
    'portuguese': (r'\b(o|a|os|as|é|são|com|para|como|mas|que|esta|isso|mais|também|pode|bem|eu|ele|ela|nós|eles|del|um|uma)\b', 0.5),
    'italian': (r'\b(il|lo|la|gli|le|è|sono|con|per|come|ma|che|questo|questa|quello|più|anche|può|bene|io|lui|lei|noi|loro|dal|un|una)\b', 0.5),
    'russian': (r'[\u0400-\u04FF]', 0.8),
    'chinese': (r'[\u4e00-\u9fff]', 0.9),
    'japanese': (r'[\u3040-\u309f\u30a0-\u30ff]', 0.9),
    'korean': (r'[\uac00-\ud7af]', 0.9),
    'arabic': (r'[\u0600-\u06ff]', 0.9),
    'hindi': (r'[\u0900-\u097f]', 0.9),
    'turkish': (r'\b(bir|bu|da|de|için|ile|çok|var|ama|ben|sen|biz|siz|onlar|gibi|kadar|daha|hem|sonra|önce|bile|şey|her|hiç)\b', 0.5),
}

scores = {}
for lang, (pattern, weight) in langs.items():
    matches = len(re.findall(pattern, text, re.I))
    words = len(text.split())
    if words > 0:
        scores[lang] = (matches / words) * weight

if scores:
    best = max(scores, key=scores.get)
    if scores[best] > 0.05:
        print(f'{best} (confidence: {min(scores[best]*100, 99):.0f}%)')
    else:
        print('english (low confidence)')
else:
    print('english (default)')
" 2>/dev/null || echo "english (default)"
}

# Translate text (basic phrase-level translation using local dictionary)
ai_lang_translate() {
  local text="$1" target_lang="${2:-en}"
  python3 -c "
import json
text = '''$text'''
target = '$target_lang'

# Common phrase translations (subset for demonstration)
translations = {
    'es': {
        'hello': 'hola', 'goodbye': 'adiós', 'thank you': 'gracias', 'please': 'por favor',
        'yes': 'sí', 'no': 'no', 'good morning': 'buenos días', 'good night': 'buenas noches',
        'how are you': 'cómo estás', 'i love you': 'te quiero', 'welcome': 'bienvenido',
        'sorry': 'lo siento', 'help': 'ayuda', 'friend': 'amigo', 'water': 'agua',
        'food': 'comida', 'house': 'casa', 'car': 'coche', 'book': 'libro',
        'today': 'hoy', 'tomorrow': 'mañana', 'yesterday': 'ayer',
    },
    'fr': {
        'hello': 'bonjour', 'goodbye': 'au revoir', 'thank you': 'merci', 'please': 's\'il vous plaît',
        'yes': 'oui', 'no': 'non', 'good morning': 'bonjour', 'good night': 'bonne nuit',
        'how are you': 'comment allez-vous', 'welcome': 'bienvenue', 'sorry': 'désolé',
        'help': 'aide', 'friend': 'ami', 'water': 'eau', 'food': 'nourriture',
        'house': 'maison', 'car': 'voiture', 'book': 'livre',
    },
    'de': {
        'hello': 'hallo', 'goodbye': 'auf wiedersehen', 'thank you': 'danke', 'please': 'bitte',
        'yes': 'ja', 'no': 'nein', 'good morning': 'guten morgen', 'good night': 'gute nacht',
        'how are you': 'wie geht es ihnen', 'welcome': 'willkommen', 'sorry': 'entschuldigung',
        'help': 'hilfe', 'friend': 'freund', 'water': 'wasser', 'food': 'essen',
        'house': 'haus', 'car': 'auto', 'book': 'buch',
    },
    'ja': {
        'hello': 'こんにちは', 'goodbye': 'さようなら', 'thank you': 'ありがとう',
        'please': 'お願いします', 'yes': 'はい', 'no': 'いいえ',
        'good morning': 'おはようございます', 'good night': 'おやすみなさい',
        'welcome': 'ようこそ', 'sorry': 'ごめんなさい', 'help': '助けて',
        'friend': '友達', 'water': '水', 'food': '食べ物',
    },
    'zh': {
        'hello': '你好', 'goodbye': '再见', 'thank you': '谢谢', 'please': '请',
        'yes': '是', 'no': '不', 'good morning': '早上好', 'good night': '晚安',
        'welcome': '欢迎', 'sorry': '对不起', 'help': '帮助', 'friend': '朋友',
    },
}

if target in translations:
    d = translations[target]
    result = text
    for eng, trans in sorted(d.items(), key=lambda x: -len(x[0])):
        result = result.replace(eng, trans)
    print(f'[{target}] {result}')
else:
    print(f'Translation to {target} not available locally.')
    print(f'Supported: {\", \".join(translations.keys())}')
    print(f'For full translation, use an online API or install argos-translate.')
" 2>/dev/null || echo "Translation unavailable. Install python3 for full support."
}

# List supported languages
ai_lang_list() {
  echo "Supported languages:"
  echo "  es — Spanish"
  echo "  fr — French"
  echo "  de — German"
  echo "  ja — Japanese"
  echo "  zh — Chinese"
  echo "  en — English"
  echo ""
  echo "For full translation support, install: pip install argos-translate"
}

# Romanize text (for CJK languages)
ai_lang_romanize() {
  local text="$1"
  python3 -c "
text = '''$text'''
# Basic romanization mappings
romaji = {
    'あ':'a','い':'i','う':'u','え':'e','お':'o',
    'か':'ka','き':'ki','く':'ku','け':'ke','こ':'ko',
    'さ':'sa','し':'shi','す':'su','せ':'se','そ':'so',
    'た':'ta','ち':'chi','つ':'tsu','て':'te','と':'to',
    'な':'na','に':'ni','ぬ':'nu','ね':'ne','の':'no',
    'は':'ha','ひ':'hi','ふ':'fu','へ':'he','ほ':'ho',
    'ま':'ma','み':'mi','む':'mu','め':'me','も':'mo',
    'や':'ya','ゆ':'yu','よ':'yo',
    'ら':'ra','り':'ri','る':'ru','れ':'re','ろ':'ro',
    'わ':'wa','を':'wo','ん':'n',
}
result = ''
for c in text:
    if c in romaji:
        result += romaji[c]
    else:
        result += c
print(result)
" 2>/dev/null || echo "$text"
}
