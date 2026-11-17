"""Prepare the picture desk's reference-led prompts; does not generate images."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
REFERENCE = ROOT / "reference" / "style_reference_1.png"
STYLE = (
    "Asset: one ILLUSTRATIVE scene printed in an old newspaper, matching the supplied style_reference_1.png. "
    "The attached image is a STYLE REFERENCE ONLY: use the printed picture inside its border, never its headline, words, scene or historical subjects. "
    "Match coarse visible press dots and broken stippled ink, soft low-detail shapes, low contrast and uneven blotchy brownish-black ink on yellowed newsprint. "
    "The print process must visibly determine the image: broad simple masses and distant tiny people, no clean sharp rendering or detailed faces. "
    "One brownish-black ink only on aged paper, no other colours. A thin ruled border surrounds the illustration. "
    "Exactly ONE continuous scene inside ONE border: never split panels, diptychs, contact sheets, inset views or multiple angles on a page. "
    "Wide whole-scene composition, landscape 8:5, delivery 800 by 500 pixels. "
    "Setting: small plain colonial town with low buildings and late twentieth-century trucks, buses and equipment where appropriate. "
    "No aliens, spacecraft overhead, futuristic city, readable words, letters, numbers, logos, real-country flags or recognisable real people. "
    "Signs, papers and placards are blank or illegible. Nothing gory; accidents and storms show aftermath without injured people. "
)

def main():
    assert REFERENCE.is_file()
    entries = json.loads((ROOT / "images_wanted.json").read_text(encoding="utf-8"))["images"]
    prompts = []
    for item in entries:
        composition = ("Choose one different angle or moment. Deliver only that single view, wide with small people and no close faces; never combine views."
                       if item["file"].endswith("_2.png") else
                       "A wide establishing scene with figures small within the surroundings.")
        prompts.append(dict(item, reference="reference/style_reference_1.png",
                            prompt=STYLE + "Subject: " + item["show"] + " " + item.get("note", "") + " " + composition))
    result = dict(mode="built-in image_gen", user_style="ILLUSTRATIVE",
                  reference="reference/style_reference_1.png", images=prompts)
    (ROOT / "picture_prompts.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("Prepared %d reference-led picture prompts." % len(prompts))

if __name__ == "__main__":
    main()
