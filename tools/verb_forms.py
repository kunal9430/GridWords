#!/usr/bin/env python3
"""Detects inflected VERB forms so the computer opponent can be limited to
the 1st verb form (the base form: walk, build, go, see ...).

Blocked forms
  * V2  past simple            walked, built, went, was, could
  * V3  past participle        walked, built, gone, been, broken
  * V4  -ing form              walking, building, going, being
  * V5  -s / -es (3rd person)  walks, goes, has, is  (plain plurals were already
                               removed by build_wordlist.py; irregular ones are
                               listed here)

How it decides (no network / no POS tagger needed):
  1. An explicit table of irregular verbs (V2/V3) - these cannot be derived.
  2. Regular -ed / -ing forms: the word is a form when its stem is itself a
     word in the list (walked -> walk, making -> make, stopped -> stop,
     carried -> carry, dying -> die).
  3. "un" + a form (unfinished, uncaring, undoing) is a form too.
  4. A small curated list of participles whose stem is not in the list.
  5. KEEP lists protect ordinary words that merely LOOK inflected: nouns such as
     morning / clothing, homographs such as saw / rose / felt, and adjectives
     built from nouns (wicked, ragged, bearded).
"""

# --------------------------------------------------------------------------
# 1. Irregular verbs: V2 and V3 forms that differ from the base form.
#    (Forms spelled like the base - cut, put, read, set ... - are not listed:
#    they ARE the 1st form.)
# --------------------------------------------------------------------------
IRREGULAR_FORMS = set('''
arose arisen awoke awoken was were been bore borne born beaten became began begun
beheld bent besought bade bidden bit bitten bled blew blown broke broken bred
brought built burnt bought caught chose chosen clung came crept dealt dug did done
drew drawn dreamt drank drunk drove driven ate eaten fell fallen fed felt fought
fled flung flew flown forbade forbidden forgot forgotten forgave forgiven froze
frozen got gotten gave given went gone grew grown hung had heard hid hidden held
kept knelt knew known laid lain led leant leapt learnt left lent lit lost made
meant met mistook mistaken overcame overtook overtaken paid rode ridden rang rung
rose risen ran sawn said saw seen sought sold sent sewn shook shaken shone shot
shown shrank shrunk slept slid slung spoke spoken sped spent spilt spun spat
sprang sprung stood stole stolen stuck stung stank stunk struck stricken strung
strove striven swore sworn swept swollen swam swum swung took taken taught tore
torn told thought threw thrown trod trodden understood undertook undertaken undid
undone woke woken wore worn wove woven wept won wound withdrew withdrawn withheld
withstood wrung wrote written begot begotten foresaw foreseen foretold misled
misunderstood outdid outdone overrode overridden overthrew overthrown rebuilt
redid redone repaid rewrote rewritten retold shorn slew slain slunk smote smitten
sown spoilt strode stridden throve unwound upheld mown snuck dove forsook forsaken
sank sunk sang sung dwelt shod undertook bound could would should
'''.split())

# Present-tense forms of irregular verbs (V5 / conjugated forms of be, have, do, go).
IRREGULAR_PRESENT = set('am is are has does goes'.split())

# --------------------------------------------------------------------------
# 5. Words that look inflected but are ordinary words / the 1st form itself.
# --------------------------------------------------------------------------
KEEP = set('''
saw rose felt found bound wound ground spoke bit lay fell left rent bore fit spat
lent might ought must shot dove rung
morning evening herring thing clothing earring inning offing outing bunting
bushing shilling shirting sheeting webbing wadding bedding flooring roofing
siding piping tubing wedding padding outgoing incoming impending underlying
ongoing
feed heed seed weed tweed aniseed shed need deed breed creed bleed speed greed
indeed proceed succeed exceed hundred kindred sacred naked
wicked ragged rugged jagged crooked crocked wretched beaked bearded horned winged
wooded feathered gifted talented moneyed principled gabled haired legged lidded
toothed tusked whiskered pronged tufted striped potbellied humpbacked walleyed
redheaded towheaded hotheaded flatfooted barefooted pinstriped hobnailed
backhanded bedded hipped
'''.split())

# --------------------------------------------------------------------------
# 4. Participles whose stem is missing from the list, so rule 2 cannot see them.
# --------------------------------------------------------------------------
EXTRA_FORMS = set('''
appalled appalling attacking chinked clowning cursed accursed damned damning
disarming embattled enthralled fagged fouled fulfilled grizzled henpecked
instilling marred panicked rotted rotting sexed oversexed shitting sopping
tatting whirring whopping interbred inbred serrated
'''.split())


def _ing_stems(w):
    if not w.endswith('ing') or len(w) < 5:
        return []
    b = w[:-3]
    stems = [b, b + 'e']
    if len(b) >= 2 and b[-1] == b[-2]:          # stopping -> stop
        stems.append(b[:-1])
    if w.endswith('ying'):                       # dying -> die, lying -> lie
        stems.append(w[:-4] + 'ie')
    return [s for s in stems if len(s) >= 2]


def _ed_stems(w):
    if not w.endswith('ed') or len(w) < 4:
        return []
    b = w[:-2]
    stems = [b, w[:-1]]                          # walked -> walk, baked -> bake
    if len(b) >= 2 and b[-1] == b[-2]:           # stopped -> stop
        stems.append(b[:-1])
    if w.endswith('ied'):                        # carried -> carry
        stems.append(w[:-3] + 'y')
    return [s for s in stems if len(s) >= 3]


def _stem_form(w, words):
    return any(s in words for s in _ing_stems(w) + _ed_stems(w))


def verb_form_reason(w, words):
    """Returns why [w] is a 2nd/3rd/4th/5th verb form, or None if it is fine."""
    if w in KEEP:
        return None
    if w in IRREGULAR_FORMS:
        return 'irregular V2/V3'
    if w in IRREGULAR_PRESENT:
        return 'present-tense form (V5)'
    if w in EXTRA_FORMS:
        return 'participle'
    if _stem_form(w, words):
        return 'regular -ed/-ing'
    if w.startswith('un') and len(w) > 5:
        rest = w[2:]
        if rest not in KEEP and (rest in EXTRA_FORMS or _stem_form(rest, words)):
            return 'un- + participle'
    return None


def is_verb_form(w, words):
    return verb_form_reason(w, words) is not None
