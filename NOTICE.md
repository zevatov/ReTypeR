# NOTICE

This document applies to the ReTypeR distribution and its bundled data.

## ReTypeR application code

Copyright (c) 2026 Stanislav

ReTypeR application code is licensed under the **MIT License** — see
[`LICENSE`](LICENSE) for the full license text.

## Bundled frequency & bigram data

The following bundled resources are **derivative works** of the FrequencyWords
project and are licensed under **CC-BY-SA-4.0**:

- `Sources/Resources/frequency_ru.txt`
- `Sources/Resources/frequency_en.txt`
- `Sources/Resources/bigram_ru.bin`
- `Sources/Resources/bigram_en.bin`

Source data:

- **FrequencyWords** by Hermit Dave — <https://github.com/hermitdave/FrequencyWords>
  (word lists; project code MIT, content CC-BY-SA-4.0).
- **OpenSubtitles 2018** corpus — <http://opus.nlpl.eu/OpenSubtitles2018.php>
  (upstream source corpus of the FrequencyWords 2018 content).

These data files are distributed under
[Creative Commons Attribution-ShareAlike 4.0](https://creativecommons.org/licenses/by-sa/4.0/).
Attribution and regeneration details:
[`Sources/Resources/FREQUENCY_DATA_LICENSE.md`](Sources/Resources/FREQUENCY_DATA_LICENSE.md)
(regeneration via [`scripts/generate_frequency_resources.py`](scripts/generate_frequency_resources.py)).

The CC-BY-SA-4.0 data and the MIT-licensed application code are separate,
independent works.
