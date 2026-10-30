"""Vietnamese words for things in a photo, mapped to the English word that appears in its tags.

The query parser is a 0.6B model; it turned "nước suối" into "water well" and "chai nước" into
"tea". Everyday words are looked up here first, which is instant and does not guess. Each phrase
maps to ONE term, because every term of a search must hold (AND), and a term matches when the
word is in the photo's tag text (see search_terms.has_term). So "ly nước" is "water", not
"cup" + "water": a tag that says "glass of water" has no "cup".

Words that are also a person's name or an everyday word once the accents are gone ("bạn" and
"bàn" are both "ban", "Bình", "Ly", "Hoa") are left out on purpose; they go to the model.
"""
from __future__ import annotations

import re
import unicodedata

# Folded (lower case, no accents) phrase -> English term. Longer phrases win over shorter ones.
LEXICON = {
    # drinks
    'nuoc suoi': 'water', 'ly nuoc suoi': 'water', 'chai nuoc suoi': 'bottle',
    'chai nuoc': 'bottle', 'binh nuoc': 'bottle', 'ly nuoc': 'water', 'coc nuoc': 'water',
    'nuoc': 'water', 'nuoc loc': 'water',
    'ca phe': 'coffee', 'cafe': 'coffee', 'coffee': 'coffee', 'ly ca phe': 'coffee',
    'coc ca phe': 'coffee', 'tra sua': 'tea', 'ly tra sua': 'tea', 'tra da': 'tea',
    'ly tra': 'tea', 'nuoc ngot': 'drink', 'bia': 'beer', 'ruou': 'wine',
    'coc': 'cup', 'chai': 'bottle',
    # food
    'banh kem': 'cake', 'banh sinh nhat': 'cake', 'banh mi': 'bread', 'pizza': 'pizza',
    'burger': 'sandwich', 'hamburger': 'sandwich', 'trai cay': 'fruit', 'chuoi': 'banana',
    'qua tao': 'apple', 'qua cam': 'orange', 'com': 'rice', 'do an': 'food', 'thuc an': 'food',
    'dia': 'plate', 'dua': 'chopsticks', 'thia': 'spoon', 'muong': 'spoon', 'nia': 'fork',
    # animals
    'con cho': 'dog', 'con meo': 'cat', 'meo': 'cat', 'con chim': 'bird', 'chim': 'bird',
    'con ngua': 'horse', 'con bo': 'cow', 'con ca': 'fish',
    # people
    'nguoi': 'person', 'em be': 'child', 'tre em': 'child', 'dan ong': 'man', 'dan ba': 'woman',
    # vehicles
    'xe may': 'motorcycle', 'xe dap': 'bicycle', 'xe hoi': 'car', 'o to': 'car',
    'xe buyt': 'bus', 'xe bus': 'bus', 'may bay': 'airplane', 'tau hoa': 'train',
    'xe tai': 'truck', 'thuyen': 'boat',
    # furniture and things
    'cai ban': 'table', 'ban an': 'table', 'ban lam viec': 'desk', 'ghe': 'chair',
    'sofa': 'couch', 'giuong': 'bed', 'tu lanh': 'refrigerator', 'may tinh': 'laptop',
    'laptop': 'laptop', 'dien thoai': 'phone', 'man hinh': 'screen', 'ban phim': 'keyboard',
    'tai nghe': 'headphones', 'sach': 'book', 'dong ho': 'clock', 'binh hoa': 'vase',
    'cua so': 'window', 'rem': 'curtain', 'chia khoa': 'keys', 'mat kinh': 'glasses',
    'kinh': 'glasses', 'non': 'hat', 'ao': 'shirt', 'giay': 'shoes', 'tui xach': 'handbag',
    'balo': 'backpack', 'cai du': 'umbrella',
    # places and scenery
    'toa nha': 'building', 'bai bien': 'beach', 'bong hoa': 'flowers', 'nui': 'mountain',
    'bau troi': 'sky', 'cay xanh': 'tree',
}

# Words that carry no object. What is left after the lexicon and these is sent to the model.
FILLERS = {
    'anh', 'hinh', 'buc', 'tam', 'cai', 'chiec', 'nhung', 'cac', 'mot', 'o', 'tai', 'trong',
    'tren', 'di', 'uong', 'an', 'bua', 'luc', 'tim', 'kiem', 'chup', 'co', 'la', 'va', 'cua',
    'toi', 'minh', 'quan', 'nha', 'hang', 'khi', 'de', 'thay', 'ra', 'duoc',
}


def fold(text: str) -> str:
    """Lower case, accents removed, anything that is not a letter or digit turned into a space."""
    text = unicodedata.normalize('NFD', text.lower().replace('đ', 'd'))
    text = ''.join(c for c in text if unicodedata.category(c) != 'Mn')
    return re.sub(r'[^a-z0-9]+', ' ', text).strip()


_PHRASES = sorted(LEXICON, key=lambda p: (-len(p.split()), -len(p)))


def lookup(text: str) -> tuple[list[str], str]:
    """Terms the lexicon finds in [text], and the folded words nothing explained."""
    rest = f' {fold(text)} '
    terms: list[str] = []
    for phrase in _PHRASES:
        needle = f' {phrase} '
        while needle in rest:
            terms.append(LEXICON[phrase])
            rest = rest.replace(needle, ' ', 1)
    left = [w for w in rest.split() if w not in FILLERS]
    return list(dict.fromkeys(terms)), ' '.join(left)
