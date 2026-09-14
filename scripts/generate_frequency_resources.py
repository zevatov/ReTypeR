#!/usr/bin/env python3
"""Generates compact frequency + char-bigram resources for ReTypeR v1.3.2.

Inputs : /tmp/freqwords/{ru,en}_50k.txt  (hermitdave/FrequencyWords, content/2018)
Outputs: Sources/Resources/frequency_{ru,en}.txt  ("word rank" lines, 50k+ words)
         Sources/Resources/bigram_{ru,en}.bin     (uint16 LE counts, 33x33 / 26x26)

Also prints a validation table of bigram log-scores for key regression words.
"""
import math
import os
import sys
import urllib.request

SRC = "/tmp/freqwords"
OUT = os.path.join(os.path.dirname(__file__), "..", "Sources", "Resources")
TOP_N = 60_000
MAX_BYTES = 2 * 1024 * 1024  # 2 MB budget — fits 50k+ words

RU_ALPHABET = "абвгдеёжзийклмнопрстуфхцчшщъыьэюя"  # 33 (yo column normalized to е for bigrams)
EN_ALPHABET = "abcdefghijklmnopqrstuvwxyz"        # 26

# Additional Russian vocabulary: inflections, IT slang, colloquial & expressive words
EXTRA_RU_WORDS = [
    # Top function & common words
    "еще", "ещё", "ее", "её", "свое", "своё", "нее", "неё", "ща", "щас",
    # Key inflections that were missing in 13k dictionary
    "приложения", "приложение", "приложений", "приложению", "приложении",
    "разделяет", "разделение", "разделитель", "разделения", "разделяют",
    "предлоги", "предлог", "предлогов", "предлогами", "предлоге",
    "алгоритма", "алгоритм", "алгоритмы", "алгоритмов", "алгоритму",
    "сгенерировать", "генерация", "генерирует", "генерации",
    "раскладки", "раскладка", "раскладку", "раскладке", "раскладкой",
    "проблем", "проблема", "проблемы", "проблему", "проблемой", "проблемах",
    "потому", "откуда", "зачем", "наверное", "пожалуйста", "непонятно",
    "досюда", "поэтому", "отчего", "покуда", "потолок", "врядли", "наврядли",
    "сейчас", "сегодня", "наконец", "затем", "оттуда", "отсюда", "навсегда",
    "надеюсь", "пожалуй", "стало",
    # IT slang
    "енв", "енвешник", "деплой", "деплоить", "деплоя", "деплоит", "деплоим",
    "тг", "роадмап", "хендоф", "вайбкодер", "коммит", "коммитить", "коммита",
    "пуш", "пушить", "пуша", "мердж", "мерджить", "мерджа", "мерджим",
    "репо", "репозиторий", "репозитория", "конфиг", "конфига", "конфиги",
    "фронт", "бэк", "бэкенд", "фронтенд", "стейджинг", "прод", "проде",
    "скрипт", "скрипта", "скрипты", "таска", "таски", "тасок",
    "логи", "логов", "баг", "баги", "багов", "фикс", "фиксить", "пофиксить",
    "тест", "тесты", "тестов", "билд", "билдить", "билдит",
    "ветка", "ветки", "мастер", "мейн", "пулл", "реквест",
    # Expressive & colloquial
    "блять", "блядь", "ебаный", "ебаная", "ебаное", "ебаные", "ебанат", "ебаната",
    "ебу", "ебет", "ебут", "ебал", "ебала", "ебали", "сука", "сучка", "еблан",
    "нахуй", "похуй", "пизду", "пиздец", "ваще", "чет", "инфа", "алибабу", "делегируй",
    "ассет", "ассеты", "ассетов", "юзаю", "юзать", "юзаешь", "юзают",
    "плз", "спс", "норм", "ок", "хз", "го", "пздц", "кринж", "рофл", "краш",
    "пруф", "пруфы", "альт", "опшн", "шифт", "хоткей", "хоткеи", "шорткат"
]

# Additional modern English tech vocabulary
EXTRA_EN_WORDS = [
    "github", "repo", "dev", "app", "config", "bearer", "token", "build",
    "deploy", "commit", "merge", "push", "pull", "branch", "staging", "prod",
    "endpoint", "auth", "login", "regex", "uuid", "json", "yaml", "html", "css",
    "npm", "cd", "cli", "sdk", "api", "git", "ssh", "zsh", "bash", "curl", "sudo",
    "docker", "node", "vue", "react", "next", "vite", "rust", "cargo", "main",
    "dmg", "pkg", "pdf", "url", "ios", "xml", "csv", "sql", "zip", "iso"
]

EXCLUDE_EN_WORDS = set()


def ensure_corpus():
    os.makedirs(SRC, exist_ok=True)
    urls = {
        "ru": "https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/ru/ru_full.txt",
        "en": "https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/en/en_50k.txt",
    }
    for lang, url in urls.items():
        path = os.path.join(SRC, f"{lang}_full.txt" if lang == "ru" else f"{lang}_50k.txt")
        if not os.path.isfile(path) or os.path.getsize(path) < 1000:
            print(f"[download] Fetching {os.path.basename(path)} from {url}...")
            urllib.request.urlretrieve(url, path)
            print(f"[download] Saved to {path}")


def load_corpus(lang):
    """Returns list of (word, count) preserving file order (frequency desc)."""
    # Prefer _full.txt if present (e.g. for Russian to reach 50k+ pure-alpha words)
    path_full = os.path.join(SRC, f"{lang}_full.txt")
    path_50k = os.path.join(SRC, f"{lang}_50k.txt")
    path = path_full if os.path.isfile(path_full) else path_50k
    pairs = []
    with open(path, encoding="utf-8") as fh:
        for i, line in enumerate(fh):
            if i >= 65_000:  # Top 65k lines is plenty for 50k+ pure words
                break
            line = line.rstrip("\n")
            if not line:
                continue
            word, sep, cnt = line.rpartition(" ")
            if not sep or not cnt.isdigit():
                continue
            pairs.append((word.lower(), int(cnt)))
    return pairs


def filter_letters(pairs, alphabet_set, exclude_set=None):
    """Keep only pure-alphabet words (letters only, no digits/punct), dedup."""
    seen = set()
    out = []
    if exclude_set is None:
        exclude_set = set()
    for word, cnt in pairs:
        if word in seen or word in exclude_set:
            continue
        if not word or not all(ch in alphabet_set for ch in word):
            continue
        seen.add(word)
        out.append((word, cnt))
    return out


def write_frequency(lang, words):
    """Writes bare 'word' lines up to TOP_N and MAX_BYTES."""
    dest = os.path.join(OUT, f"frequency_{lang}.txt")
    kept = []
    used = 0
    for w in words:
        cost = len(w.encode("utf-8")) + 1
        if used + cost > MAX_BYTES:
            break
        kept.append(w)
        used += cost
    with open(dest, "w", encoding="utf-8") as fh:
        fh.write("\n".join(kept) + "\n")
    actual = os.path.getsize(dest)
    print(f"[freq] {lang}: kept {len(kept)} words, {actual} bytes (budget {MAX_BYTES})")
    return actual


def build_bigrams(pairs, alphabet, normalize=None):
    """Weighted char-bigram counts over the corpus (count-weighted)."""
    idx = {ch: i for i, ch in enumerate(alphabet)}
    n = len(alphabet)
    raw = [[0] * n for _ in range(n)]
    for word, cnt in pairs:
        if normalize:
            word = normalize(word)
        if len(word) < 2:
            continue
        prev = None
        for ch in word:
            cur = idx.get(ch)
            if cur is None:
                prev = None
                continue
            if prev is not None:
                raw[prev][cur] += cnt
            prev = cur
    counts = [[min(65535, math.isqrt(v)) for v in row] for row in raw]
    return counts


def write_bigram(lang, counts):
    import struct
    flat = [v for row in counts for v in row]
    data = struct.pack(f"<{len(flat)}H", *flat)
    dest = os.path.join(OUT, f"bigram_{lang}.bin")
    with open(dest, "wb") as fh:
        fh.write(data)
    print(f"[bigram] {lang}: {len(counts)}x{len(counts)} uint16, {len(data)} bytes")


class BigramScorer:
    def __init__(self, counts, alphabet, normalize=None):
        self.idx = {ch: i for i, ch in enumerate(alphabet)}
        self.counts = counts
        self.row_totals = [sum(row) for row in counts]
        self.v = len(alphabet)
        self.normalize = normalize

    def score(self, word):
        """Sum of log((c+1)/(rowTotal+V)); None when any char is outside alphabet."""
        if self.normalize:
            word = self.normalize(word)
        ids = []
        for ch in word:
            i = self.idx.get(ch)
            if i is None:
                return None
            ids.append(i)
        total = 0.0
        cells = []
        for a, b in zip(ids, ids[1:]):
            c = self.counts[a][b]
            cells.append(c)
            total += math.log((c + 1) / (self.row_totals[a] + self.v))
        return total, cells

    def stats(self, word):
        res = self.score(word)
        if res is None:
            return None
        total, cells = res
        k = max(1, len(word) - 1)
        return {
            "sum": total,
            "avg": total / k,
            "min_cell": min(cells) if cells else None,
            "zero_cells": sum(1 for c in cells if c == 0),
            "cells": cells,
        }


def norm_ru(word):
    return word.replace("ё", "е")


def main():
    ensure_corpus()
    os.makedirs(OUT, exist_ok=True)
    ru_alpha_set = set(RU_ALPHABET)
    en_alpha_set = set(EN_ALPHABET)

    corpora = {}
    for lang, alpha_set, extra_words, exclude_set, syn_count in [
        ("ru", ru_alpha_set, EXTRA_RU_WORDS, set(), 40_000),
        ("en", en_alpha_set, EXTRA_EN_WORDS, EXCLUDE_EN_WORDS, 80_000)
    ]:
        pairs = load_corpus(lang)
        counts = {}
        for w, cnt in pairs:
            counts[w] = cnt
        for w in extra_words:
            w_lower = w.lower()
            if all(c in alpha_set for c in w_lower):
                counts[w_lower] = max(counts.get(w_lower, 0), syn_count)
        sorted_pairs = sorted(counts.items(), key=lambda x: x[1], reverse=True)
        filtered = filter_letters(sorted_pairs, alpha_set, exclude_set=exclude_set)
        print(f"[corpus] {lang}: {len(pairs)} raw + {len(extra_words)} extra -> {len(filtered)} pure-alpha unique")
        corpora[lang] = filtered
        write_frequency(lang, [w for w, _ in filtered[:TOP_N]])

    ru_counts = build_bigrams(corpora["ru"], RU_ALPHABET, normalize=norm_ru)
    en_counts = build_bigrams(corpora["en"], EN_ALPHABET)
    write_bigram("ru", ru_counts)
    write_bigram("en", en_counts)

    # Validation table: verify that bigram scoring remains sound
    ru_scorer = BigramScorer(ru_counts, RU_ALPHABET, normalize=norm_ru)
    en_scorer = BigramScorer(en_counts, EN_ALPHABET)

    print("\n=== RU candidates (want weakValid: yes*) ===")
    for w in ["хиросмс", "локалхост", "ассетов", "запусти",
              "проверимж", "проверимх", "проверимъ", "белзимитные",
              "тг", "кл", "ис", "еще"]:
        s = ru_scorer.stats(w)
        print(f"  {w:14s} " + (f"avg={s['avg']:7.2f} sum={s['sum']:8.2f} "
                               f"min={s['min_cell']:6d} zeros={s['zero_cells']} cells={s['cells']}"
                               if s else "OUT-OF-ALPHABET"))

    print("\n=== RU glue-garbage (must NOT pass bigram gate) ===")
    for w in ["ключмоделей", "клю", "чмоделей", "укфащч", "яумфещм",
              "сыросыс", "гыфс"]:
        s = ru_scorer.stats(w)
        print(f"  {w:14s} " + (f"avg={s['avg']:7.2f} sum={s['sum']:8.2f} "
                               f"min={s['min_cell']:6d} zeros={s['zero_cells']} cells={s['cells']}"
                               if s else "OUT-OF-ALPHABET"))

    print("\n=== EN originals (must stay invalid) ===")
    for w in ["bhjcvc", "erafox", "ghbdtn", "kjrfk", "jcn", "rk", "xvjltktq",
              "zevatov", "usac", "kjrfkxjcn", "fcctnjd", "pfgecnb",
              "tpkbvbnyst", "tcgkfnyst", "vjltkb", "tcnm"]:
        s = en_scorer.stats(w)
        print(f"  {w:14s} " + (f"avg={s['avg']:7.2f} sum={s['sum']:8.2f} "
                               f"min={s['min_cell']:6d} zeros={s['zero_cells']} cells={s['cells']}"
                               if s else "OUT-OF-ALPHABET"))

    print("\n=== Sanity: real words score high ===")
    for lang, sc, ws in (("ru", ru_scorer, ["привет", "модели", "бесплатные"]),
                         ("en", en_scorer, ["hello", "world", "models"])):
        for w in ws:
            s = sc.stats(w)
            print(f"  {lang} {w:12s} avg={s['avg']:7.2f} sum={s['sum']:8.2f}")


if __name__ == "__main__":
    sys.exit(main())

