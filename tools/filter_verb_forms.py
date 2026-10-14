#!/usr/bin/env python3
"""Removes 2nd / 3rd / 4th (and 5th) verb forms from assets/words/words.txt.

The computer opponent may only use the 1st (base) form of a verb. This is the
same filter build_wordlist.py applies when it regenerates the list; use this
script to clean an existing words.txt without WordNet/SCOWL on hand.

Usage:  python3 tools/filter_verb_forms.py [path/to/words.txt] [--dry-run]
"""
import collections, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from verb_forms import verb_form_reason

args = [a for a in sys.argv[1:] if not a.startswith('--')]
dry = '--dry-run' in sys.argv
path = args[0] if args else os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'words', 'words.txt')

rows = []
for line in open(path, encoding='utf8'):
    line = line.rstrip('\n')
    if line.strip():
        w, _, g = line.partition('\t')
        rows.append((w, g))
words = {w for w, _ in rows}

kept, dropped = [], collections.defaultdict(list)
for w, g in rows:
    why = verb_form_reason(w, words)   # judged against the ORIGINAL list
    if why:
        dropped[why].append(w)
    else:
        kept.append((w, g))

for why, ws in dropped.items():
    print(f'{why:28s} {len(ws):5d}   e.g. {" ".join(ws[:12])}')
print(f'{len(rows)} -> {len(kept)} words ({len(rows) - len(kept)} removed)')
if not dry:
    with open(path, 'w', encoding='utf8') as f:
        for w, g in kept:
            f.write(f'{w}\t{g}\n')
    print('written', os.path.normpath(path))
