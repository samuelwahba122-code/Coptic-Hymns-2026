# Hymns App — Developer Manual

## Overview

Flutter app for hymns with:
- Audio playback
- Line-by-line synchronization
- PDF view

Offline, asset-based, JSON-driven. No backend.

---

## Project Structure

```
assets/
├── library.json
├── hymns/
├── audio/
├── lines/
└── pdf/
```

---

## Adding a New Hymn

### 1. Add Audio

```
assets/audio/<hymn_id>.mp3
```

---

### 2. Add PDF

```
assets/pdf/<hymn_id>.pdf
```

The PDF is required for:
- Extracting line images
- Display in the PDF screen

---

### 3. Extract Line Images from PDF (Python)

#### Requirements

- Python 3.9+
- Poppler installed (in PATH)
- Pillow + pdf2image

Install dependencies:

```
pip install pillow pdf2image
```

---

#### Python Script: extract_lines.py

```python
from pdf2image import convert_from_path
from PIL import Image
import os
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("--pdf", required=True)
parser.add_argument("--out", required=True)
args = parser.parse_args()

os.makedirs(args.out, exist_ok=True)

pages = convert_from_path(args.pdf, dpi=300)

line_index = 1

for page in pages:
    width, height = page.size
    line_height = height // 12

    for i in range(12):
        top = i * line_height
        bottom = top + line_height
        crop = page.crop((0, top, width, bottom))

        if crop.getbbox():
            crop.save(
                os.path.join(args.out, f"line_{line_index}.png")
            )
            line_index += 1
```

---

#### Run the Script

```
python extract_lines.py \
  --pdf assets/pdf/<hymn_id>.pdf \
  --out assets/lines/<hymn_id>
```
use the pop up window to detect the lines using [ button to increase sensitivity for more accurate lines.
Output:

```
assets/lines/<hymn_id>/
├── line_1.png
├── line_2.png
├── line_3.png
```

---

### 4. Create Hymn JSON

```
assets/hymns/<hymn_id>.json
```

```json
{
  "id": "<hymn_id>",
  "title": "Hymn Title",
  "audioAsset": "assets/audio/<hymn_id>.mp3",
  "pdfAsset": "assets/pdf/<hymn_id>.pdf",
  "lines": [
    {
      "index": 1,
      "startMs": 0,
      "endMs": 3000,
      "image": "assets/lines/<hymn_id>/line_1.png"
    }
  ]
}
```

---

## Audio Timing (Only Rule That Matters)

For each line:
- Listen to the audio
- When the line starts → `startMs`
- When the line ends → `endMs`
- Enter the values in milliseconds

No guessing. No formulas.

---

## Timing Rules

- `startMs < endMs`
- Lines must be ordered
- No overlapping ranges
- Silence between lines is allowed

---

## Register the Hymn

Edit:

```
assets/library.json
```

```json
{
  "id": "<hymn_id>",
  "title": "Hymn Title",
  "author": "Author",
  "jsonAsset": "assets/hymns/<hymn_id>.json"
}
```

---

## Rules for Contributors

- One hymn = one JSON
- Audio is never edited
- PDF is mandatory
- Line images must come from the PDF
- Timings come only from listening
- Always test playback

---

## Summary

1. Add MP3
2. Add PDF
3. Extract line images
4. Listen → input `startMs` / `endMs`
5. Register hymn

Done.
