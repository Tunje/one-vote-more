"""Normalize a generated source to the newspaper's delivery format, without replacing an asset."""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parent

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True)
    parser.add_argument("--name", required=True)
    args = parser.parse_args()
    requested = {r["file"] for r in json.loads((ROOT / "images_wanted.json").read_text(encoding="utf-8"))["images"]}
    if args.name not in requested or Path(args.name).name != args.name:
        raise ValueError("Destination must be a requested picture name")
    destination = ROOT / "images" / args.name
    destination.parent.mkdir(exist_ok=True)
    if destination.exists():
        print("Already present: " + args.name)
        return
    with Image.open(args.source) as original:
        # Preserve the reference's brown ink and aged paper. Converting to L
        # would discard the accepted printed illustration's palette.
        delivery = ImageOps.fit(original.convert("RGB"), (800, 500), method=Image.Resampling.LANCZOS)
        with destination.open("xb") as output:
            delivery.save(output, format="PNG")
    print("Saved " + args.name)

if __name__ == "__main__":
    main()
