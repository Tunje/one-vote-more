"""The user's correction on salaries, 2026-11-17: a salary is set on hire and then only climbs by the yearly raise.
usage: python planning/plan_salary_fix.py (repo root, once)"""
import io

Q = "No no,  the sallery is not fluent, they have a sallery set on hire then it climbs based on yearly upps set by goverment your fluid sallery is not what i said"


def patch(p, pairs, add_before=None):
    s = io.open(p, encoding="utf-8", newline="").read()
    crlf = "\r\n" in s
    s = s.replace("\r\n", "\n")
    for a, b in pairs:
        if a not in s:
            raise SystemExit("%s: missing %r" % (p, a[:60]))
        s = s.replace(a, b)
    if add_before:
        mark, text = add_before
        if s.count(mark) != 1:
            raise SystemExit("%s: mark" % p)
        s = s.replace(mark, text + mark)
    io.open(p, "w", encoding="utf-8", newline="").write(s.replace("\n", "\r\n") if crlf else s)


patch("planning/rebuild-company.md", [
    ("- **A salary is a price.** Price rules 1, 2 and 9 set it.",
     '''- **A salary is not fluid** (the user, correcting Wilma: "''' + Q + '''").
  - **A worker's salary is set when they are hired.** It is theirs from then on. The company does not move it up or
    down afterwards, whatever the labour market does.
  - **It climbs once a year** by the yearly raise. The government sets the raise's minimum (a lever, 2% to start); a
    company may give more. That is the "bonus" of the user's earlier sentence.
  - **What the three price rules move is the HIRING salary:** what a company offers a new hire this month ("that's
    fine for hiring"). People hired in different years at the same company are paid differently.
  - A worker who can get more elsewhere leaves for it; that is how an employed worker's pay changes otherwise.
  - So a company's record holds two things: its hiring salary per tier and area, and what each group of its staff is
    actually paid.'''),
    ("| 1 raise | its posts stay open, or its workers leave for better pay |", "| 1 raise the hiring salary | its posts stay open, or its workers leave for better pay |"),
    ("| 2 lower | more people apply at its salary than it has posts |", "| 2 lower the hiring salary | more people apply at its hiring salary than it has posts |"),
])
patch("planning/rebuild-step2-brief.md", [
    ("- **The yearly bonus** (Anni): the company's choice; when it gives one it is at least the government's minimum.",
     "- **The yearly raise** (corrected by the user after this brief was written): a salary is set on hire and climbs once\n  a year by the raise; the government sets its minimum; it is not the company's choice whether to give it. The three\n  price rules move only the hiring salary."),
])
p = "planning/MASTER-PLAN.md"
s = io.open(p, encoding="utf-8", newline="").read()
nl = "\r\n" if "\r\n" in s else "\n"
mark = "## 5. Immediate next steps"
add = nl.join(["### The rebuild: a salary is set on hire (the user, 2026-11-17, verbatim)", "",
               "Correcting the plan, which had the three price rules moving a company's salary for all its staff every month:", "",
               "> " + Q, "",
               "A worker's salary is set when they are hired and then climbs only by the yearly raise, whose minimum the government sets. The three price rules move only what a company offers a NEW hire. Corrected in [rebuild-company.md](rebuild-company.md) section 9.2. Context for the earlier quotes: \"the three rules for price should be applied here too\" and \"that's fine for hiring\" were about the hiring salary; \"every year a company can grant a bonus what the minimum of this is is up to the government\" is the yearly raise.", "", "", ""])
io.open(p, "w", encoding="utf-8", newline="").write(s.replace(mark, add + mark))
print("salary fix written")
