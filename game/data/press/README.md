# Newspaper articles: brief for the writer

You are writing newspaper articles for a game. This file tells you everything you need. You do not need to read any
other file in the project except `wanted.json` in this folder.

## The game, in a few lines

A colony of a few thousand people on another planet, founded under a charter from a distant home world. Ships from
the home world call about every two years; nothing reaches or leaves the colony in between. The colony has a
Colonial Assembly, parties, a First Minister, unions, companies and a public sector. It is a political game: the
player leads a party. Technology is roughly late twentieth century: trucks, buses, power plants, mines, farms,
bakeries, a port. No aliens, no magic, no faster-than-light news. The tone of the game is dry and a little wry.

The colony has several newspapers. Each month a paper reports what happened. Today every kind of event has one
flat sentence. You are writing proper articles to replace those sentences.

## What to write

`wanted.json` lists every article that is wanted, most important first (`priority` 1 is the most wanted). Work
down the list in that order. For each entry, write ONE file into the folder `articles/`, named exactly as the
entry's `file` field says. Skip an entry if its file already exists. You may stop anywhere; the game uses what
is there and falls back to its old sentence for the rest.

Each entry tells you:

- `event`: the kind of thing that happened, and `about`: what that means in plain words.
- `flavour`: which kind of paper is writing (see "The five papers").
- `stance`: how this article treats `{target}`, the person or body mainly responsible for the event
  (see "Stance").
- `kind`: where on the page it goes and how long it is (see "Kinds").
- `placeholders`: the only blanks you may use (see "Blanks").
- `must_name`: the blanks EVERY variant must use (see "Name who it is about"), and `holds`: what the event's own
  blanks hold.
- `variants`: how many different versions to write.

## The file format

Each file is JSON, UTF-8, exactly this shape:

```json
{
  "event": "POL_SCANDAL_REVEALED",
  "flavour": "TABLOID",
  "stance": "AGAINST",
  "kind": "LEAD",
  "variants": [
    {"headline": "…", "sub": "…", "body": "…"},
    {"headline": "…", "sub": "…", "body": "…"},
    {"headline": "…", "sub": "…", "body": "…"}
  ]
}
```

- `event`, `flavour`, `stance`, `kind` are copied from the entry in `wanted.json`.
- `headline`: up to 60 characters. No full stop at the end.
- `sub`: one sentence under the headline, up to 140 characters. For a BRIEF, leave it as an empty string.
- `body`: the article. Separate paragraphs with `\n\n`. Plain text only: no Markdown, no HTML, no bullet lists.
- Write exactly as many variants as the entry asks for.

## Blanks

The game fills in blanks written in curly braces, like `{first_minister}`. You may use ONLY the names listed in
the entry's `placeholders`. If you use any other name in braces, the file is rejected. Do not write literal curly
braces for any other purpose.

What the common blanks hold:

- `{paper}`: the name of the newspaper printing this.
- `{month}`, `{year}`: when it is printed, for example "March" and "Year 14".
- `{colony}`: the name of the colony.
- `{target}`: the person or body mainly responsible for the event: "the government", a minister's name, a
  company's name, a union's name, "the home world". Write so the sentence reads correctly whichever of those it is.
- `{first_minister}`: the First Minister's name. `{governing_party}`: the name of the party leading the government.
- `{months_running}`: a number, how many months this story has been going on. `{first_reported}`: when this paper
  first reported it, for example "March of Year 12". These two exist only for FOLLOWUP and RETURN articles.
- `{district}`, `{season}`: a district's name; the season's name.

The other blanks belong to the event and mean what their names say (`{party}`, `{leader}`, `{employer}`, `{yes}`
and `{no}` for vote counts, and so on). They hold a name or a number. If you are not sure whether a blank holds a
name or a number, do not use it.

Rules for blanks:

- Every variant must make sense with any reasonable value in each blank. Do not assume a party's politics, a
  person's sex, or a company's trade.
- Never use "he" or "she" for a blank that holds a person. Repeat the name, or use the office ("the First
  Minister", "the leader").
- You do not have to use every blank. Use `{target}` at least once in every LEAD and SECOND.

## Name who it is about

An article says WHO. Never write "a company", "a party", "a party leader", "a union" or "a building project"
when the entry gives you a blank that holds the name. A reader must learn from the headline or the first
sentence which company went under, which party split, who the new leader is.

- Every variant must use every blank listed in the entry's `must_name`, at least once, in the headline, the sub
  or the body. Put the name early: in the headline where it fits, otherwise in the first sentence.
- `holds` tells you what each of the event's own blanks contains, so you know how it reads in a sentence.
- `{target}` is not a substitute: it is who the paper holds responsible, which may be the government and not the
  company or party the event is about.
- An article that does not name who it is about is rejected by `check.py`, and the game does not print it.

Files written before this rule fail the check. Rewrite every file `check.py` reports.

## The hard rule: invent nothing that can be checked

The game knows what happened. You do not. So an article may NOT state any fact that is not in the entry's `about`
line or in a blank: no numbers, no names of people, places, companies, parties or laws, no dates, no causes, no
quotes from named people, no "sources say" with a specific claim.

What you may add freely: the paper's opinion, colour, and unnamed voices ("a baker in the queue", "one member of
the assembly who asked not to be named"), as long as what they say is feeling and opinion, not a new fact.

## The five papers

- `STATE`: the official gazette. Measured, formal, a little stiff. Leads with what was decided and by whom. Avoids
  blame. Dull on purpose, and trusted for it.
- `PARTY`: a party's own paper. Openly partisan and righteous. Its side is principled; the other side is cynical.
- `UNION`: a labour paper. Sees every event through wages, jobs, safety and who pays. Plain words, solidarity,
  suspicion of owners and ministers alike.
- `BUSINESS`: a paper for owners and managers. Sees every event through costs, prices, credit and confidence.
  Cool, numerate in tone (but invent no numbers), impatient with politics.
- `TABLOID`: sells copies. Short sentences. Outrage, pity and gossip. Loud headlines. Finds the human victim or
  the villain in everything.

## Stance

- `NEUTRAL`: report it straight, in that paper's voice.
- `AGAINST`: `{target}` is to blame, or handled it badly, or cannot be trusted.
- `FOR`: `{target}` did the right thing, or is being treated unfairly, or the alternative would be worse.

The same event must read differently in each stance. A STATE paper that is AGAINST still sounds like a gazette:
it regrets, it notes, it "understands that questions are being asked".

## Kinds

- `LEAD`: the main story of the front page. 120 to 180 words, three or four paragraphs.
- `SECOND`: a second story. 60 to 90 words, two paragraphs.
- `BRIEF`: a short item. 20 to 35 words, one paragraph, no `sub`.
- `FOLLOWUP`: the story is still going on. 40 to 70 words. It must not read like first news: say it continues,
  use `{months_running}`, and you may refer back with `{first_reported}`.
- `RETURN`: the paper comes back to the story after a long time or on its anniversary. 90 to 140 words. Look
  back: what was said then, what has and has not changed, using `{first_reported}`.
- `FEATURE`: a piece that needs no event, for quiet months. 150 to 220 words.

## Variety

The whole point is that a paper should not read the same twice. Within one file, make the variants differ in how
they open, in their angle, and in their headline's shape, not just in a few swapped words. Across files, do not
reuse stock phrases.

## Pictures

The front page has a large space beside the main headline. `images_wanted.json` lists the pictures wanted for
it. They are generic: a picture stands for a kind of event, not for one particular event, so it must fit any
time that kind of thing happens. For each entry make ONE image and save it into the folder `images/` under
exactly the entry's `file` name. Skip an entry whose file already exists.

Each entry has `for` (the kind of event or feature it illustrates), `show` (what the picture shows) and sometimes a
`note`.

Every picture:

- PNG, 800 pixels wide and 500 high, landscape.
- ILLUSTRATIVE (the user's word), and the user's own example of it is `reference/style_reference_1.png`: a
  picture as it was PRINTED in an old newspaper. Look at that file before making anything. What it shows:
  - coarse print: the picture is made of the press's dots and ink, soft and grainy, with little fine detail;
  - one ink on aged newsprint: a brownish-black ink on yellowed paper, no other colour;
  - low contrast, with the ink a little uneven and blotchy;
  - a wide view of a whole scene (a square full of people, buildings behind, a row of cars in front), nobody close
    up, no face you could recognise;
  - a thin ruled border round the picture.
- NOT photo-realistic, not a clean modern photograph, not sharp. An earlier version of this brief said "press
  photograph" and prompts were written as "photorealistic"; that was wrong (Wilma's wording, not the user's) and is
  withdrawn. Every prompt that says "photorealistic", "photograph" or "documentary photograph" must be rewritten to
  give the printed-in-an-old-newspaper look of the reference before any picture is made.
- The setting is a small, plain colonial town of roughly late-twentieth-century technology: low buildings,
  trucks and buses, a small port, wide skies. It may show two moons in the sky. No aliens, no spacecraft
  overhead, no futuristic city.
- No words, letters or numbers anywhere in the picture: placards, signs and documents are blank or
  illegible. No logos or flags of any real country, company or party.
- No real, recognisable person. People are ordinary and unposed, mostly seen from a distance, from behind or in
  groups.
- Nothing gory. An accident or a storm shows the aftermath, not the injured.

## Checking your work

Run `python check.py` in this folder. It reads the two lists and every file in `articles/` and `images/` and reports any file
that is misnamed, malformed, too long or too short, or uses a blank it may not use. Fix what it reports. It also
prints how many of the wanted articles exist.
