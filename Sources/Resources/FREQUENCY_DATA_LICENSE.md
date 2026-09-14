# Frequency & Bigram Data — Attribution and License

## Bundled data files

| File | Content |
|---|---|
| `frequency_ru.txt` | Top Russian words by frequency (one per line, descending) |
| `frequency_en.txt` | Top English words by frequency (one per line, descending) |
| `bigram_ru.bin` | 33×33 `uint16` little-endian char-bigram counts (Russian, «ё» normalized to «е») |
| `bigram_en.bin` | 26×26 `uint16` little-endian char-bigram counts (English) |

## Source

Derived from the **FrequencyWords** project by Hermit Dave:

- Repository: <https://github.com/hermitdave/FrequencyWords>
- Source corpus: OpenSubtitles 2018 (<http://opus.nlpl.eu/OpenSubtitles2018.php>)
- Files used: `content/2018/ru/ru_full.txt`, `content/2018/en/en_50k.txt`
- Transformation: filtering to pure-alphabet words, deduplication, lowercasing;
  integer-square-root compression of count-weighted char-bigram tallies into
  `uint16` grids. Lists are truncated only by the generator's `TOP_N` word cap
  (no byte-size budget). Current bundled sizes: ~57k Russian words
  (`frequency_ru.txt`) and ~46k English words (`frequency_en.txt`).
  Reproduce with [`scripts/generate_frequency_resources.py`](../../scripts/generate_frequency_resources.py).

## Licenses

- FrequencyWords **code**: MIT License — © Hermit Dave and contributors.
- FrequencyWords **content** (the word lists this app bundles, including our
  derived `frequency_*.txt` and `bigram_*.bin`): **CC-BY-SA-4.0**
  (<https://creativecommons.org/licenses/by-sa/4.0/>).

ReTypeR ships these derived files under CC-BY-SA-4.0, share-alike compatible
with the upstream project's terms. The ReTypeR application code itself is
licensed under the MIT License (see LICENSE in the repository root); these
data files are separate works.

## Regeneration

The resources are reproducible with:

```bash
scripts/generate_frequency_resources.py
```

(after downloading the two upstream `_50k.txt` files into `/tmp/freqwords/`).
