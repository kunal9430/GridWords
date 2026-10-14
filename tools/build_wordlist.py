#!/usr/bin/env python3
"""Regenerates assets/words/words.txt (word<TAB>meaning, one per line).

A word is accepted only if ALL of these hold:
  1. WordNet has it as a lower-case dictionary entry (so it has a real
     meaning, is a BASE form - not a plural / conjugation - and is not a
     proper noun). WordNet entries all carry a definition.
  2. SCOWL (graded by commonness) lists it at level <= 50 ("found in a large
     dictionary"), which removes rare/obscure words.
  3. 2-10 letters, contains a vowel (drops abbreviations such as "kg", "nth").
  4. It is not a plural / -es / -ies form of another accepted word.
  5. It is not marked offensive/vulgar in its definition or on the blocklist.
  6. It is not an acronym / abbreviation listed in tools/blocked_words.txt.
  7. It is the 1st (base) form of a verb, never the 2nd / 3rd / 4th form
     (walked, built, gone, walking, was ...) - see tools/verb_forms.py.
A short list of everyday function words that WordNet omits (it, of, to...)
is added with hand-written definitions.

Inputs (npm packages, unpacked):
  npm pack wordnet-db wordlist-english   # then untar each into a folder
Usage:
  python3 build_wordlist.py <wordnet-db/dict> <wordlist-english folder> <out words.txt>
"""
import collections, json, re, sys

wn_dir, scowl_dir, out_path = sys.argv[1].rstrip('/') + '/', sys.argv[2].rstrip('/') + '/', sys.argv[3]
POS = ['noun', 'adj', 'verb', 'adv']  # preference order for ties

data, lower_forms = {}, set()
for p in POS:
    for line in open(wn_dir + 'data.' + p, encoding='utf8'):
        if line.startswith('  '):
            continue
        head, _, gloss = line.partition('|')
        t = head.split()
        n = int(t[3], 16)
        for i in range(n):
            f = re.sub(r'\(.*\)$', '', t[4 + 2 * i])
            if f.isalpha() and f == f.lower():
                lower_forms.add(f)
        data[(p, t[0])] = gloss.strip()

best = {}  # lemma -> (tagged count, -pos rank, pos, first synset offset)
for rank, p in enumerate(POS):
    for line in open(wn_dir + 'index.' + p, encoding='utf8'):
        if line.startswith('  '):
            continue
        t = line.split()
        lem, pc = t[0], int(t[3])
        if not lem.isalpha():
            continue
        cand = (int(t[5 + pc]), -rank, p, t[6 + pc])
        if lem not in best or cand[:2] > best[lem][:2]:
            best[lem] = cand

scowl = set()
for lvl in (10, 20, 35, 40, 50):
    scowl |= {w for w in json.load(open(f'{scowl_dir}english-words-{lvl}.json')) if w.isalpha() and w == w.lower()}

def gloss(w):
    _, _, p, off = best[w]
    g = data[(p, off)].split(';')[0].strip().strip('"')
    g = re.sub(r'\s+', ' ', g)
    if len(g) > 90:
        g = g[:90].rsplit(' ', 1)[0] + '...'
    return g

OFFENSIVE = re.compile(r'offensive|derogat|vulgar|obscene|disparag|insulting|\bslur\b|bawdy|pejorative', re.I)
BLOCK = set('''ass bum tit sex fag gyp hag crap damn bitch bastard chink coolie dyke bunghole darky gook kike wop
nigger spic wetback coon jap paki queer homo dago'''.split())

# Acronyms / initialisms / clipped forms are not allowed (tools/blocked_words.txt).
import os
_bl = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'blocked_words.txt')
ACRONYMS = {l.strip() for l in open(_bl, encoding='utf8') if l.strip() and not l.startswith('#')}
BLOCK |= ACRONYMS

base = {w for w in (lower_forms & scowl) if w in best and 2 <= len(w) <= 10 and re.search('[aeiouy]', w)}
base = {w for w in base if w not in BLOCK and not OFFENSIVE.search(gloss(w))}
# very short words: keep only ones that are plainly ordinary words
SHORT_DROP = set('''em ex fa id la mi mu nu re ti alb amp bop bur cad cam chi cob cox deb doc erg eta hep hie hob hod ism ken
lei lox mar meg mil mod nit nix non pap pas pol poi pro pyx rep rev rho sac sic sis sol sop sot tam tat tog tom tor tun ump
wen wiz yon zed zit gal gee hew ell fey fop gad haw dun cur tux lam fez'''.split())
base -= SHORT_DROP

def inflected(w):
    if len(w) < 4 or w.endswith(('ss', 'us', 'is', 'ous')):
        return False
    if w.endswith('ies') and len(w) > 4 and (w[:-3] + 'y') in base:
        return True
    if w.endswith('es') and len(w[:-2]) >= 3 and w[:-2] in base:
        return True
    return w.endswith('s') and len(w[:-1]) >= 3 and w[:-1] in base

words = {w: gloss(w) for w in base if not inflected(w)}

FUNCTION = {
    'am': "first-person singular present of 'be'", 'an': "the form of 'a' used before a vowel sound",
    'is': "third-person singular present of 'be'", 'it': 'the thing or animal already mentioned',
    'if': 'on the condition that; whether', 'me': 'the speaker, as the object of a verb',
    'my': 'belonging to the speaker', 'of': 'belonging to, or made from', 'oh': 'an exclamation of surprise',
    'or': 'used to link alternatives', 'to': 'in the direction of', 'us': 'the speaker and others, as an object',
    'we': 'the speaker and others', 'the': 'used before a noun that is specific or already known',
    'and': 'used to join words or ideas', 'for': 'intended to benefit or belong to', 'you': 'the person being spoken to',
    'her': 'belonging to or about a woman or girl', 'him': 'a man or boy, as the object of a verb',
    'his': 'belonging to a man or boy', 'she': 'a woman or girl already mentioned', 'who': 'which person',
    'was': "past tense of 'be'", 'are': "present plural of 'be'", 'has': "third-person singular present of 'have'",
    'had': "past tense of 'have'", 'not': 'used to make a statement negative', 'its': 'belonging to a thing already mentioned',
    'our': 'belonging to the speaker and others', 'but': 'however; except', 'can': 'be able to', 'did': "past tense of 'do'",
    'got': "past tense of 'get'", 'that': 'the one pointed to', 'this': 'the one close by', 'with': 'together or alongside',
    'from': 'starting at', 'have': 'to own or hold', 'were': "past plural of 'be'", 'been': "past participle of 'be'",
    'will': 'expresses the future', 'your': 'belonging to the person spoken to', 'what': 'which thing',
    'when': 'at what time', 'into': 'to the inside of', 'they': 'the people or things already mentioned',
    'them': 'those people or things, as an object', 'then': 'at that time', 'than': 'used to compare two things',
    'also': 'in addition', 'just': 'only; exactly', 'yes': 'used to agree', 'how': 'in what way', 'why': 'for what reason',
}
for w, g in FUNCTION.items():
    words.setdefault(w, g)
for w in ACRONYMS:
    words.pop(w, None)

# The computer may only play the 1st verb form: drop V2 / V3 / V4 (and V5) forms.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from verb_forms import is_verb_form
_all = set(words)
words = {w: g for w, g in words.items() if not is_verb_form(w, _all)}

with open(out_path, 'w', encoding='utf8') as f:
    for w in sorted(words):
        f.write(f"{w}\t{words[w].replace(chr(9), ' ')}\n")
print(len(words), 'words written to', out_path)
