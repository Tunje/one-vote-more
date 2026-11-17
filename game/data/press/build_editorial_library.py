"""Build the remaining requested files from the desk's authored copy.

Exclusive creation preserves any articles already delivered by another writer.
Run from any directory; no runtime game code is changed.
"""
import json
import argparse
from pathlib import Path

from editorial_catalogue import EVENTS
from editorial_features import FEATURES, feature

ROOT = Path(__file__).resolve().parent
FLAVOURS = ("STATE", "PARTY", "UNION", "BUSINESS", "TABLOID")
STANCES = ("NEUTRAL", "AGAINST", "FOR")
BRIEF_JUDGMENTS = {
    "STATE": ("The gazette records the development as a matter deserving careful attention in the public interest.", "This gazette considers the stewardship of {target} inadequate and regards the matter as warranting critical scrutiny.", "The gazette favours fair treatment of {target} rather than an adverse verdict founded upon assumption alone."),
    "PARTY": ("Our principles require political attention that keeps the purpose of public responsibility firmly in view here.", "We hold {target} responsible for inadequate political judgment and insist upon a more demanding public standard.", "We stand with {target} against an easy verdict; a principled politics should also be a fair one."),
    "UNION": ("Working people's needs belong at the centre of this discussion, rather than outside its political argument.", "Labour finds the stewardship of {target} wanting; ordinary people deserve a more responsible standard of conduct.", "Solidarity includes fairness to {target}; an adverse outcome does not by itself justify every accusation made."),
    "BUSINESS": ("Commercial judgment requires a disciplined distinction between the established development and assumptions about its practical consequences.", "We judge the stewardship of {target} inadequate; practical responsibility should be assessed against a demanding standard.", "Our assessment favours {target} over a verdict that confuses an adverse interpretation with an established fact."),
    "TABLOID": ("Keep the people behind the story in view, and ask the hard questions without inventing answers.", "Our verdict on {target}: not good enough, and the colony deserves a better standard of responsibility.", "Give {target} a fair hearing; outrage alone should not be allowed to write the whole verdict."),
}

LEAD_LAST = {
    "STATE": "Care in the public record is part of responsible administration.",
    "PARTY": "Political principle should remain visible when judgment becomes less comfortable.",
    "UNION": "Ordinary lives should be the measure, not a convenient afterthought.",
    "BUSINESS": "Reliable assessment begins with particulars rather than a politically convenient assumption.",
    "TABLOID": "Readers deserve a clear story and a straight answer about responsibility.",
}

def article(request, index):
    copy = EVENTS[request["event"]]
    flavour, stance, kind = (request[k] for k in ("flavour", "stance", "kind"))
    fact = copy["facts"][index]
    angle = copy["angles"][index]
    voice = copy["voices"][FLAVOURS.index(flavour)]
    judgment = copy["judgments"][STANCES.index(stance)]
    sentences = voice.split(". ")
    short_voice = sentences.pop(0).rstrip(".") + "."
    while len(short_voice.split()) < 6 and sentences:
        short_voice += " " + sentences.pop(0).rstrip(".") + "."
    if flavour == "TABLOID":
        short_voice = {
            "POL_LEADER_CHANGED": "New leader, with the same need for serious questions.",
            "LAW_CHARTER_AMENDED": "The charter has changed, and readers should pay attention.",
            "ECON_CONTRACT_SEVERELY_DELAYED": "Badly behind schedule, and the calendar deserves a straight answer.",
        }.get(request["event"], short_voice)
    short_judgment = BRIEF_JUDGMENTS[flavour][STANCES.index(stance)]
    headline = copy["heads"][index]
    sub = copy["facts"][(index + 1) % 3]
    if kind == "LEAD":
        body = "\n\n".join((angle, voice, judgment + " " + LEAD_LAST[flavour]))
    elif kind == "SECOND":
        body = angle + "\n\n" + short_voice + " " + short_judgment
    elif kind == "BRIEF":
        body = fact + " " + BRIEF_JUDGMENTS[flavour][STANCES.index(stance)]
        sub = ""
    elif kind == "FOLLOWUP":
        timeline = (
            "Coverage continues after {months_running} months; this is a continuing story rather than a fresh announcement.",
            "This story remains under examination, {months_running} months into our coverage of the original event.",
            "Our attention to this story continues after {months_running} months, with the original report still the starting point.",
        )[index]
        if "months_running" not in request["placeholders"]:
            timeline = (
                "Coverage of this story continues; the original event remains the starting point for the questions examined here.",
                "This story remains under examination, with renewed attention to the responsibilities raised by the original report.",
                "Our attention to this story continues, with the original event still the starting point for assessing responsibility.",
            )[index]
        body = fact + " " + timeline + "\n\n" + short_voice + " " + short_judgment
        headline = ("Still in view: " + headline[0].lower() + headline[1:])
    elif kind == "RETURN":
        past_fact = fact.replace("has been", "had been").replace("has ", "had ").replace("is ", "was ").replace("are ", "were ")
        retrospective = (
            "We return to {first_reported}. Our report recorded this: " + past_fact,
            "Looking back to {first_reported}, this was the news: " + past_fact,
            "The headline belongs to {first_reported}. Our original account recorded this: " + past_fact,
        )[index]
        if "first_reported" not in request["placeholders"]:
            retrospective = retrospective.replace("{first_reported}", "our earlier coverage")
        comparison = (
            "The event remains part of the record. Whether subsequent developments met the standard it raised is a separate question, not something the old headline can answer by itself.",
            "Time changes the distance from an event, not the need to judge it carefully. Any claim about improvement or deterioration needs more than a recollection of the original news.",
            "Changes since then deserve examination against the original record. The need to distinguish an established event from its associated hopes and fears remains.",
        )[index]
        body = "\n\n".join((retrospective, voice, comparison, judgment))
        headline = "Looking back: " + headline[0].lower() + headline[1:]
    else:
        raise ValueError(kind)
    # A headline must remain usable before and after placeholder substitution.
    # Authored shorter alternatives preserve the subject for later-page slots.
    if len(headline) > 60:
        headline = copy["heads"][index]
    if len(headline) > 60:
        raise ValueError((request["file"], headline))
    return dict(headline=headline, sub=sub, body=body)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repair-missing-names", action="store_true", help="Refresh an existing file only when it omits a required subject name.")
    args = parser.parse_args()
    wanted = json.loads((ROOT / "wanted.json").read_text(encoding="utf-8"))["articles"]
    written = 0
    repaired = 0
    for request in wanted:
        path = ROOT / "articles" / request["file"]
        repair = False
        if path.exists():
            if not args.repair_missing_names:
                continue
            existing = json.loads(path.read_text(encoding="utf-8"))
            repair = any("{" + ph + "}" not in " ".join(v[k] for k in ("headline", "sub", "body"))
                         for v in existing["variants"] for ph in request.get("must_name", []))
            if not repair:
                continue
        result = {k: request[k] for k in ("event", "flavour", "stance", "kind")}
        writer = feature if request["event"] in FEATURES else article
        result["variants"] = [writer(request, i) for i in range(request["variants"])]
        with path.open("w" if repair else "x", encoding="utf-8") as output:
            json.dump(result, output, ensure_ascii=False, indent=2)
            output.write("\n")
        if repair:
            repaired += 1
        else:
            written += 1
    print(f"Wrote {written} additional article files; repaired required names in {repaired} files.")

if __name__ == "__main__":
    main()
