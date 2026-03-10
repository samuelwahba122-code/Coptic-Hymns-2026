import json
import re
from pathlib import Path

# =========================================================
# CONFIG
# =========================================================

BASE_DIR = Path(__file__).parent

INPUT_FILE = BASE_DIR / "faietafenf.txt"
OUTPUT_FILE = BASE_DIR / "faietafenf.json"

HYMN_ID = "faietafenf"
TITLE = "Fai Etaf Enf"
MS_PER_LINE = 4000

# keep these fields in JSON for debugging
KEEP_DEBUG_FIELDS = True

# =========================================================
# HAZZAT MAPPING
# =========================================================
# Based on the mapping you sent.
# These are characters that are strong Hazzat/music indicators.
# We do NOT blindly classify everything with these chars as hazzat,
# but skipping them during alignment is cheap.

HAZZAT_CHARS = set(
    "ZXCVBNM"      # high notes / note groups
    "zxcvbnm"      # normal note groups
    "qwertyu"      # short notes
    "sdfgh"        # note extenders
    "ASDFG"        # vibrated notes
    "ajJ"          # abrupt / fast marks
    ".+-"          # pause / tone up / tone down
    "0123456789"   # repeat counts
    "!@#%^&"       # mark numbers
    "()[]{},"      # grouping punctuation seen in mixed notation
)

# punctuation allowed in transliterated Coptic / mixed text
NEUTRAL_CHARS = set("`';:=/\\|?_~")


# =========================================================
# HELPERS
# =========================================================

def normalize_spaces(s: str) -> str:
    return re.sub(r"[ \t]+", " ", s).strip()


def safe_read_text(file_path: Path) -> str:
    """
    Read text file safely. Tries utf-8 first, then cp1252.
    Also replaces NBSP.
    """
    try:
        raw = file_path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        raw = file_path.read_text(encoding="cp1252")

    raw = raw.replace("\xa0", " ")
    raw = raw.replace("\r\n", "\n").replace("\r", "\n")
    return raw


def compact_with_positions(s: str):
    """
    Remove spaces but keep mapping to original indexes.
    Returns:
      chars: list of non-space chars
      pos:   original indexes of those chars
    """
    chars = []
    pos = []
    for i, ch in enumerate(s):
        if not ch.isspace():
            chars.append(ch)
            pos.append(i)
    return chars, pos


# =========================================================
# INPUT PARSER
# =========================================================

def parse_numbered_pairs_file(file_path: Path):
    """
    Reads file entries like:

    1) mixed: E;bezz ]zz`aznazzctacd.zzw ...
       coptic: E;be ]`anactacic ...

    2) mixed: ...
       coptic: ...

    Supports:
    - 1) or 1.
    - multiline mixed/coptic blocks until next entry
    """

    raw = safe_read_text(file_path)

    entry_start_re = re.compile(
        r"^\s*(\d+)\s*[\)\.]\s*mixed\s*:\s*(.*)$",
        re.IGNORECASE
    )
    coptic_re = re.compile(
        r"^\s*coptic\s*:\s*(.*)$",
        re.IGNORECASE
    )

    entries = []
    current = None
    current_mode = None  # "mixed" or "coptic"

    for line in raw.split("\n"):
        start_match = entry_start_re.match(line)
        coptic_match = coptic_re.match(line)

        if start_match:
            if current:
                current["mixed"] = normalize_spaces("\n".join(current["mixed"]))
                current["coptic"] = normalize_spaces("\n".join(current["coptic"]))
                entries.append(current)

            current = {
                "sourceIndex": int(start_match.group(1)),
                "mixed": [start_match.group(2).strip()],
                "coptic": []
            }
            current_mode = "mixed"
            continue

        if coptic_match:
            if current is None:
                continue

            current["coptic"].append(coptic_match.group(1).strip())
            current_mode = "coptic"
            continue

        if current is not None:
            stripped = line.strip()
            if not stripped:
                continue

            if current_mode == "mixed":
                current["mixed"].append(stripped)
            elif current_mode == "coptic":
                current["coptic"].append(stripped)

    if current:
        current["mixed"] = normalize_spaces("\n".join(current["mixed"]))
        current["coptic"] = normalize_spaces("\n".join(current["coptic"]))
        entries.append(current)

    entries.sort(key=lambda x: x["sourceIndex"])
    return entries


# =========================================================
# ALIGNMENT
# =========================================================

def skip_cost(ch: str) -> int:
    """
    Cost of skipping a mixed character as Hazzat.

    Lower = more likely Hazzat
    Higher = more likely real Coptic/transliteration text
    """
    if ch in HAZZAT_CHARS:
        return 0

    if ch in NEUTRAL_CHARS:
        return 1

    # punctuation commonly surrounding Hazzat
    if ch in "._-+()[]{},":
        return 0

    # spaces are handled before alignment, but just in case
    if ch.isspace():
        return 0

    # letters could be either coptic transliteration or hazzat text
    # make skipping them more expensive so matching is preferred
    return 3


def split_mixed_with_coptic_dp(mixed: str, coptic: str):
    """
    Align coptic to mixed using dynamic programming.

    Idea:
    - mixed line contains both coptic chars and hazzat chars
    - coptic line is the truth
    - match coptic chars in order
    - any skipped mixed chars become hazzat

    Returns alternating segments:
    [
      {"type": "coptic", "value": "..."},
      {"type": "hazzat", "value": "..."},
      ...
    ]
    """

    mixed = mixed.rstrip()
    coptic = normalize_spaces(coptic)

    if not mixed:
        return []

    if not coptic:
        return [{"type": "hazzat", "value": mixed}]

    mchars, mpos = compact_with_positions(mixed)
    cchars, _ = compact_with_positions(coptic)

    M = len(mchars)
    C = len(cchars)

    INF = 10**9

    dp = [[INF] * (C + 1) for _ in range(M + 1)]
    parent = [[None] * (C + 1) for _ in range(M + 1)]

    dp[0][0] = 0

    for i in range(M + 1):
        for j in range(C + 1):
            cur = dp[i][j]
            if cur >= INF:
                continue

            # option 1: skip mixed char => hazzat
            if i < M:
                cost = cur + skip_cost(mchars[i])
                if cost < dp[i + 1][j]:
                    dp[i + 1][j] = cost
                    parent[i + 1][j] = ("skip", i, j)

            # option 2: match mixed char with coptic char
            if i < M and j < C and mchars[i] == cchars[j]:
                cost = cur
                if cost < dp[i + 1][j + 1]:
                    dp[i + 1][j + 1] = cost
                    parent[i + 1][j + 1] = ("match", i, j)

    # if full coptic line could not be aligned, fallback
    if dp[M][C] >= INF:
        return [{"type": "hazzat", "value": mixed}]

    matched_compact_indexes = set()

    i, j = M, C
    while i > 0 or j > 0:
        p = parent[i][j]
        if p is None:
            break
        action, pi, pj = p
        if action == "match":
            matched_compact_indexes.add(pi)
        i, j = pi, pj

    labels = ["hazzat"] * len(mixed)

    # mark matched original positions as coptic
    for compact_idx, orig_idx in enumerate(mpos):
        if compact_idx in matched_compact_indexes:
            labels[orig_idx] = "coptic"

    # assign spaces between two coptic chars as coptic too
    for idx, ch in enumerate(mixed):
        if ch.isspace():
            left = idx - 1
            right = idx + 1
            left_type = labels[left] if left >= 0 else None
            right_type = labels[right] if right < len(labels) else None
            if left_type == "coptic" and right_type == "coptic":
                labels[idx] = "coptic"

    # collapse to segments
    segments = []
    current_type = labels[0]
    current_chars = [mixed[0]]

    for idx in range(1, len(mixed)):
        seg_type = labels[idx]
        ch = mixed[idx]

        if seg_type == current_type:
            current_chars.append(ch)
        else:
            value = "".join(current_chars).strip()
            if value:
                segments.append({
                    "type": current_type,
                    "value": value
                })
            current_type = seg_type
            current_chars = [ch]

    value = "".join(current_chars).strip()
    if value:
        segments.append({
            "type": current_type,
            "value": value
        })

    # merge consecutive same-type segments
    merged = []
    for seg in segments:
        if not merged:
            merged.append(seg)
        elif merged[-1]["type"] == seg["type"]:
            merged[-1]["value"] += " " + seg["value"]
        else:
            merged.append(seg)

    return merged


# =========================================================
# BUILD JSON
# =========================================================

def build_json_from_pairs_file(
    hymn_id: str,
    title: str,
    input_file: Path,
    ms_per_line: int = 4000,
    keep_debug_fields: bool = True
):
    pairs = parse_numbered_pairs_file(input_file)

    line_objects = []

    for idx, pair in enumerate(pairs, start=1):
        mixed_line = pair["mixed"]
        coptic_line = pair["coptic"]

        segments = split_mixed_with_coptic_dp(mixed_line, coptic_line)

        line_obj = {
            "i": idx,
            "segments": segments,
            "s": (idx - 1) * ms_per_line,
            "e": idx * ms_per_line
        }

        if keep_debug_fields:
            line_obj["sourceIndex"] = pair["sourceIndex"]
            line_obj["mixed"] = mixed_line
            line_obj["coptic"] = coptic_line

        line_objects.append(line_obj)

    return {
        "id": hymn_id,
        "title": title,
        "fontFamily": "HazzatFont",
        "pdfAsset": "",
        "audio": "",
        "lines": line_objects
    }


# =========================================================
# MAIN
# =========================================================

if __name__ == "__main__":
    hymn_json = build_json_from_pairs_file(
        hymn_id=HYMN_ID,
        title=TITLE,
        input_file=INPUT_FILE,
        ms_per_line=MS_PER_LINE,
        keep_debug_fields=KEEP_DEBUG_FIELDS
    )

    OUTPUT_FILE.write_text(
        json.dumps(hymn_json, indent=2, ensure_ascii=False),
        encoding="utf-8"
    )

    print(f"Created: {OUTPUT_FILE}")