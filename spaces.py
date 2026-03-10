import json
from pathlib import Path

# automatically locate hymns folder
INPUT_DIR = Path("assets") / "hymns"

if not INPUT_DIR.exists():
    print("Cannot find assets/hymns folder.")
    print("Current directory:", Path.cwd())
    exit()

# Set to True if you want to overwrite the original files
OVERWRITE = False

# If OVERWRITE = False, edited files will be saved here
OUTPUT_DIR = Path(r"C:\Users\samue\Desktop\hymn_app\assets\fixed_hymns")


def fix_segments_in_lines(lines: list) -> None:
    """
    Add one trailing space to every segment value if it does not already end with a space.
    Works for franco, coptic, and hazzat.
    """
    for line in lines:
        if not isinstance(line, dict):
            continue

        segments = line.get("segments", [])
        if not isinstance(segments, list):
            continue

        for seg in segments:
            if not isinstance(seg, dict):
                continue

            value = seg.get("value")
            if not isinstance(value, str):
                continue

            if value == "":
                continue

            if not value.endswith(" "):
                seg["value"] = value + " "


def add_trailing_space_to_segments(data):
    """
    Supports both:
    1. Root object with "lines"
    2. Root list of line objects
    """
    if isinstance(data, dict):
        lines = data.get("lines", [])
        if isinstance(lines, list):
            fix_segments_in_lines(lines)
        return data

    elif isinstance(data, list):
        fix_segments_in_lines(data)
        return data

    else:
        return data


def process_file(json_path: Path, output_path: Path) -> None:
    with json_path.open("r", encoding="utf-8") as f:
        data = json.load(f)

    fixed = add_trailing_space_to_segments(data)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as f:
        json.dump(fixed, f, ensure_ascii=False, indent=2)

    print(f"Saved: {output_path}")


def main():
    if not INPUT_DIR.exists():
        print(f"Input folder not found: {INPUT_DIR}")
        return

    json_files = sorted(INPUT_DIR.glob("*.json"))
    if not json_files:
        print(f"No JSON files found in: {INPUT_DIR}")
        return

    for json_file in json_files:
        try:
            if OVERWRITE:
                out_path = json_file
            else:
                out_path = OUTPUT_DIR / json_file.name

            process_file(json_file, out_path)

        except Exception as e:
            print(f"Error in {json_file.name}: {e}")

    print("Done.")


if __name__ == "__main__":
    main()