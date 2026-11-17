"""Prepare the picture desk's reference-led prompts; does not generate images."""
import json
import hashlib
from pathlib import Path
from picture_scenes import SCENES

ROOT = Path(__file__).resolve().parent
COMMON = (
    "Asset: ONE ILLUSTRATIVE old-newspaper picture, landscape 8:5, delivery 800 by 500 pixels. "
    "The supplied image is a PRINT-TREATMENT REFERENCE ONLY. Do not copy its scene, people, architecture, framing, layout or historical setting. "
    "Use the subject and framing specified below. Include only objects belonging to that scene; do not add a town-square backdrop, crowd, trucks or buses unless requested. "
    "Exactly one continuous composition: no panels, montage, insets, contact sheets or multiple views. "
    "The game is set in a modest colony ON ANOTHER PLANET, with late twentieth-century technology on the ground. "
    "No aliens or futuristic city. No readable words, letters, numbers, logos, real-country flags or recognisable real people. "
    "Any papers, signs and labels must be blank or illegible. Nothing gory, no visibly injured people. "
)
SPACE_EVENTS = {"HOME_SANCTION", "HOME_EXPEDITION_SENT", "HOME_SHIP_BUILT", "HOME_SHIPPING_REFUSED", "ECON_SHIP_ARRIVED", "FEATURE_SHIP_DAY", "GENERIC_PORT"}
SPACE_RULE = (
    "Home-world ships are always interplanetary SPACECRAFT and the port is a dry inland landing field with warehouses, never a harbour. "
    "No sea-going ships, nautical vessels, water docks, seaport cranes, sails or ocean backdrops for spacecraft or port subjects. "
)
PRINT_STYLE = (
    "Match style_reference_1.png only in coarse visible press dots, broken stippled ink, soft low-detail shapes, low contrast and uneven blotchy printing. "
    "Use one brownish-black ink on aged yellowed newsprint, no other colours, with a thin ruled border. "
    "Broad printed masses rather than sharp naturalistic detail. "
)
ENGRAVED_STYLE = (
    "Match style_reference_2.png only in its drawn black-line engraving treatment: black ink lines on white paper, shading entirely through fine hatch and crosshatch marks. "
    "No grey fills, colour, sepia, smooth tonal rendering or press-dot texture. Edges fade into open white paper; no hard frame. "
    "Draw the actual requested subject, not the reference's kiosk, customers, historic costumes or composition. "
)

def brief_fingerprint():
    digest = hashlib.sha256()
    for name in ("README.md", "images_wanted.json"):
        digest.update((ROOT / name).read_bytes())
    return digest.hexdigest()

def main():
    entries = json.loads((ROOT / "images_wanted.json").read_text(encoding="utf-8"))["images"]
    prompts = []
    for item in entries:
        index = 1 if item["file"].endswith("_2.png") else 0
        reference = "reference/style_reference_%d.png" % (index + 1)
        assert (ROOT / reference).is_file()
        scene = SCENES[item["for"]][index]
        prompts.append(dict(item, reference=reference, composition=scene,
                            prompt=COMMON + (SPACE_RULE if item["for"] in SPACE_EVENTS else "") +
                            (ENGRAVED_STYLE if index else PRINT_STYLE) + "Subject and framing: " + scene))
    result = dict(mode="built-in image_gen", user_style="ILLUSTRATIVE",
                  brief_sha256=brief_fingerprint(), images=prompts)
    temporary = ROOT / "picture_prompts.json.tmp"
    temporary.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(ROOT / "picture_prompts.json")
    print("Prepared %d reference-led picture prompts." % len(prompts))

if __name__ == "__main__":
    main()
