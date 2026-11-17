"""Create labelled contact sheets for reviewing the delivered picture library."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageOps

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "review"

def main():
    OUT.mkdir(exist_ok=True)
    wanted = json.loads((ROOT / "images_wanted.json").read_text(encoding="utf-8"))["images"]
    pictures = [r for r in wanted if (ROOT / "images" / r["file"]).is_file()]
    paths = []
    for start in range(0, len(pictures), 24):
        sheet = Image.new("RGB", (1120, 1260), "#e8e3d9")
        draw = ImageDraw.Draw(sheet)
        for index, request in enumerate(pictures[start:start + 24]):
            x, y = (index % 4) * 280, (index // 4) * 210
            with Image.open(ROOT / "images" / request["file"]) as source:
                thumb = ImageOps.contain(source.convert("RGB"), (272, 170), method=Image.Resampling.LANCZOS)
                sheet.paste(thumb, (x + 4, y + 4))
            name = request["file"]
            if len(name) > 38:
                split = name.rfind("_", 0, 38)
                name = name[:split] + "\n" + name[split + 1:]
            draw.multiline_text((x + 4, y + 177), name, fill="black", spacing=1)
        path = OUT / ("pictures_%02d.png" % (start // 24 + 1))
        sheet.save(path)
        paths.append(str(path))
    print(json.dumps(dict(pictures=len(pictures), sheets=paths)))

if __name__ == "__main__":
    main()
