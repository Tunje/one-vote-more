"""Print the next missing planned picture; refuse prompts made against an older brief."""
import json
from prepare_picture_prompts import ROOT, brief_fingerprint

manifest = json.loads((ROOT / "picture_prompts.json").read_text(encoding="utf-8"))
if manifest["brief_sha256"] != brief_fingerprint():
    raise SystemExit("BRIEF_CHANGED: reread the brief and rebuild the picture plan before generating.")

# Correct spaceflight subjects before continuing through remaining illustrations.
space = {"HOME_SANCTION", "HOME_EXPEDITION_SENT", "HOME_SHIP_BUILT", "HOME_SHIPPING_REFUSED", "ECON_SHIP_ARRIVED", "FEATURE_SHIP_DAY", "GENERIC_PORT"}
entries = sorted(manifest["images"], key=lambda r: r["for"] not in space)
missing = next((r for r in entries if not (ROOT / "images" / r["file"]).exists()), None)
print(json.dumps(missing))
