# Word list: `words.txt`

One entry per line: `word<TAB>meaning`. About 22,100 common English base-form words
(2-10 letters). The game also accepts the one-letter words `A` and `I`
(added in `lib/ai/word_list.dart`). Regenerate with `tools/build_wordlist.py`.

## How a word gets in
1. It is a lower-case entry in **WordNet** - so it has a real meaning, is a
   dictionary (base) form rather than a plural/conjugation, and is not a
   proper noun. The meaning shown in the game is its WordNet definition.
2. It is listed by **SCOWL** at commonness level <= 50 (words found in a large
   dictionary), which removes rare/obscure words.
3. It contains a vowel (drops abbreviations such as "kg").
4. It is not a plural / -es / -ies form of another word in the list.
5. It is not marked offensive/vulgar and is not on a small blocklist.
6. It is the **1st verb form** only: 2nd/3rd/4th forms (past, past participle,
   -ing: `walked`, `built`, `gone`, `walking`, `was`...) are removed by
   `tools/verb_forms.py` (run `tools/filter_verb_forms.py` to re-apply it).
A short set of everyday function words WordNet omits (it, of, to, the, ...)
is added with hand-written meanings.

## Sources and licences
* **WordNet** (npm package `wordnet-db` 3.1.14; full licence in `WORDNET_LICENSE.txt`) - Copyright Princeton
  University. Permission to use, copy, modify and distribute WordNet for any
  purpose and without fee or royalty is granted, provided this copyright
  notice and licence appear in all copies. WordNet is a registered trademark
  of Princeton University. https://wordnet.princeton.edu/license-and-commercial-use
* **SCOWL** (npm package `wordlist-english`, MIT-licensed packaging) -
  Copyright 2000-2016 by Kevin Atkinson. Permission to use, copy, modify,
  distribute and sell these word lists for any purpose is granted without
  fee, provided the above copyright notice and this permission notice appear
  in all copies. Provided "as is" without warranty.
