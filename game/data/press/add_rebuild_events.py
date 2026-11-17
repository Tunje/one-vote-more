"""Adds the news the rebuilt economy publishes to wanted.json, in the same shape as every other event: 75 articles
each (five flavours x three stances x five kinds), each naming who it is about where the news has someone to name.
Safe to run again: an event already in the list is left alone.
usage: python -I game/data/press/add_rebuild_events.py   (from the repo root)"""
import io
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
BASE = ["paper", "month", "year", "colony", "target", "first_minister", "governing_party"]

# event: (about, extra placeholders, must_name, holds)
EVENTS = {
    "ECON_IMPORT_ARRIVED": (
        "Goods ordered from the home world have been landed at the port, a full round trip after they were ordered, and paid for on the dock. {company} is who ordered them, {good} is what came, {qty} is how much.",
        ["company", "good", "qty"], ["company"],
        {"company": "the name of the company that ordered the goods", "good": "what was landed, for example \"food\" or \"building material\"", "qty": "a number: how many units were landed"}),
    "ECON_PURSE_SHORT": (
        "The government could not pay its bills in full this month: state wages, the unemployment benefit and pensions were all paid short, each by the same share. {due} is what was owed, {paid} is what was paid.",
        ["due", "paid"], [],
        {"due": "a sum of money: what the government owed this month", "paid": "a sum of money: what it actually paid"}),
    "ECON_GRANT_PROGRAMME_ENDED": (
        "A government grant programme for people starting a business has ended: its time ran out, its money was spent, or the government closed it. {programme} is which one, {paid} is how many grants it paid, {refused} is how many it refused.",
        ["programme", "paid", "refused"], ["programme"],
        {"programme": "the programme, for example \"the family farm grant\"", "paid": "a number: grants paid", "refused": "a number: applications refused"}),
    "COMP_COMPANY_PLANNED": (
        "A settler has put their household's savings into a plan to start a company. {founder} is who, {business} is what they plan, {district} is where.",
        ["founder", "business", "district"], ["founder"],
        {"founder": "the founder's name", "business": "what they plan, for example \"a family farm\"", "district": "the name of the place"}),
    "COMP_PLAN_ABANDONED": (
        "A plan to start a company has been given up before it opened. The builder keeps what it was paid, and any grant is owed back. {founder} is whose plan it was, {business} is what it was to be, {why} is the reason.",
        ["founder", "business", "why"], ["founder"],
        {"founder": "the founder's name", "business": "what was planned, for example \"a family farm\"", "why": "a short reason, for example \"the work is no longer there\""}),
    "ECON_CONTRACT_AWARDED": (
        "A building contract has been signed. {builder} is the building company that won it, {project} is what will be built, {price} is the price agreed.",
        ["builder", "project", "price"], ["builder", "project"],
        {"builder": "the building company's name", "project": "what is to be built, for example \"a family farm for the Okafor household\"", "price": "a sum of money"}),
    "ECON_PROJECT_COMPLETED": (
        "A building has been finished and handed over; it opens next month. {builder} is who built it, {project} is what it is.",
        ["builder", "project"], ["builder", "project"],
        {"builder": "the building company's name", "project": "what was built, for example \"a family farm for the Okafor household\""}),
    "ECON_PROJECT_CANCELLED": (
        "A building job has been cancelled part-way: the client gave up the plan. {builder} is the builder, {project} is what was being built, {why} is the reason.",
        ["builder", "project", "why"], ["builder", "project"],
        {"builder": "the building company's name", "project": "what was being built", "why": "a short reason"}),
    "ECON_CONTRACT_PAYMENT_MISSED": (
        "A client has not paid its builder for work done. After three missed months the builder stops work. {builder} is who is owed, {client} is who owes, {owed} is how much.",
        ["builder", "client", "owed"], ["builder", "client"],
        {"builder": "the building company's name", "client": "the name of the client who has not paid", "owed": "a sum of money"}),
    "ECON_FOOD_SCARCE": (
        "There is not enough food to buy: shops and farms are sold out, and people with money in hand go without. {short} is how many meals could not be had this month.",
        ["short"], [],
        {"short": "a number: meals that could not be bought because there was none"}),
    "ECON_FOOD_UNAFFORDABLE": (
        "There is food for sale but people cannot pay for it: households are going hungry beside full shelves. {short} is how many meals went unbought for want of money.",
        ["short"], [],
        {"short": "a number: meals that went unbought because people could not pay"}),
    "ECON_MIGRANTS_ARRIVED": (
        "New settlers have landed from the ship in port. {migrants} is how many, {district} is where they landed.",
        ["migrants", "district"], [],
        {"migrants": "a number: settlers who arrived", "district": "the name of the place they landed"}),
    "ECON_EMIGRATION": (
        "People have left the colony on the ship in port: young adults with no work, and families with no home. {left} is how many.",
        ["left"], [],
        {"left": "a number: people who left"}),
}


def main():
    path = HERE / "wanted.json"
    doc = json.load(io.open(path, encoding="utf-8"))
    arts = doc["articles"]
    have = {a["event"] for a in arts}
    template = [a for a in arts if a["event"] == "ECON_PANDEMIC"]   # the five flavours x three stances x five kinds
    assert len(template) == 75
    prio = max(a["priority"] for a in arts)
    added = 0
    for ev, (about, extra, must, holds) in EVENTS.items():
        if ev in have:
            continue
        for t in template:
            prio += 1
            arts.append({"file": "%s__%s__%s__%s.json" % (ev, t["flavour"], t["stance"], t["kind"]), "priority": prio,
                         "event": ev, "about": about, "flavour": t["flavour"], "stance": t["stance"], "kind": t["kind"],
                         "placeholders": BASE + extra, "variants": t["variants"], "must_name": list(must), "holds": dict(holds)})
            added += 1
    io.open(path, "w", encoding="utf-8", newline="\n").write(json.dumps(doc, indent=1, ensure_ascii=False) + "\n")
    print("added %d wanted articles; the list now has %d" % (added, len(arts)))


if __name__ == "__main__":
    main()
