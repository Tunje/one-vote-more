"""One-off editorial batch. Existing articles are never overwritten."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent

# Each row is a separately written angle: headline, deck, opening, context,
# closing, and the brief version. Stance paragraphs express judgments only.
COPY = {
    "STATE": [
        ("Food shortage leaves residents hungry", "Food provision is an urgent public concern in {colony}.",
         "There is insufficient food in {colony}, and residents are going hungry. The matter requires the attention of {target}. The immediate distinction is between describing a shortage and ensuring that people have enough to eat.",
         "An account of the position should distinguish what is known from what is proposed. Hunger is established; the causes, the duration and the means of remedy should not be presumed from that fact alone. Public discussion would benefit from observing this distinction.",
         "For the purposes of this gazette, the test of any response is straightforward: whether adequate food becomes available to those who need it. A satisfactory explanation cannot itself constitute a meal.",
         "Food is insufficient in {colony}, and residents are going hungry. Adequate provision must be the immediate public priority."),
        ("Adequate food remains the essential test", "Residents need food, whatever account is given of the shortage.",
         "The food shortage in {colony} has a direct human consequence: people are hungry. Any assessment of {target} should begin with that circumstance, rather than with the relative merits of the language used to describe it.",
         "Food provision is a basic condition of the colony's affairs. It should therefore be possible to discuss the present deficiency plainly, without treating either alarm or reassurance as evidence. The fact of hunger warrants attention in its own right.",
         "Readers should judge proposed remedies by their bearing on actual provision. Administrative completeness and practical sufficiency are different measures; only the latter can establish that the central difficulty has been addressed.",
         "Residents of {colony} are hungry because there is not enough food. The practical measure of a remedy is adequate provision."),
        ("Gazette records insufficient food supply", "The shortage must be assessed by its consequences for residents.",
         "This newspaper records that food is insufficient in {colony} and that people are going hungry. It is an unwelcome entry in the public record, and an important matter for {target} to address.",
         "There is no advantage in allowing formal terminology to obscure the condition being recorded. A shortage means that the available food does not meet people's needs. Its seriousness does not depend upon whether a more comfortable description can be found.",
         "The public interest calls for clear information and practical attention. Neither a presumption of recovery nor a presumption about the cause follows from the report. What does follow is the necessity of taking hunger seriously.",
         "The gazette records insufficient food and hunger in {colony}. Clear information is necessary; practical provision is the essential objective."),
    ],
    "PARTY": [
        ("A political argument must end in food", "Hunger puts the purpose of public life in plain view.",
         "People in {colony} are going hungry. There is not enough food. Every political argument about this shortage ought to start there, including the argument over what should be expected of {target}.",
         "Our position is plain: a colony is a common undertaking, and the ability of its people to eat belongs at the centre of its politics. Fine distinctions between competing programmes are worth making only if they help us confront that obligation.",
         "Readers need not surrender their principles to recognise hunger. On the contrary, this is where principles acquire meaning. The measure of a political position is what it asks us to do for people, especially when the subject is less comfortable than a campaign speech.",
         "There is not enough food in {colony}. People are hungry, and the political debate must answer that simple, urgent fact."),
        ("Principles belong at the dinner table", "A shortage tests what political commitments actually mean.",
         "What is a political principle worth to someone who is hungry? The question is unavoidable in {colony}, where food is insufficient. It is also the question by which we judge {target}.",
         "We believe public life should concern itself with the conditions in which people live. Hunger belongs in that discussion without qualification. It should not have to compete for moral importance with the convenience of a political argument.",
         "There will always be room to dispute the proper means of securing enough food. There should be no need to dispute the end. A political movement worthy of support must be able to connect its convictions to that most ordinary requirement of daily life.",
         "Food is insufficient and people are hungry in {colony}. Political principles should be judged by what they mean for those people."),
        ("Hunger is a question for public life", "People need enough to eat before rhetoric can satisfy anyone.",
         "The shortage of food in {colony} is leaving people hungry. That fact deserves more than a place among the subjects politicians find convenient to discuss. It demands a serious reckoning with {target}.",
         "For this paper, politics is about the terms on which we live together. Food is among the most basic of those terms. No political vocabulary is so elevated that it can make hunger a secondary concern.",
         "Our readers can disagree about policy while insisting upon that common standard. Conviction should make the demand for adequate food stronger, not turn the people who need it into scenery for an argument. The purpose of taking a side is to stand for something that matters.",
         "People are going hungry in {colony} because food is insufficient. Any political argument should keep their needs at its centre."),
    ],
    "UNION": [
        ("A wage cannot feed you without food", "The shortage puts a basic need ahead of every fine argument.",
         "People in {colony} are going hungry because there is not enough food. For working people, that is the beginning of the story. It should be the beginning of the reckoning with {target}, too.",
         "A pay packet matters because of what it lets a household obtain. Food is the most basic test. Whatever arguments are made about the shortage, workers should not be asked to mistake a discussion of their needs for the meeting of those needs.",
         "Solidarity means keeping the hungry person in view. It means judging an answer by whether it helps people eat, rather than by whether it sounds impressive at a meeting. There is nothing complicated about the standard, however difficult the work of meeting it may be.",
         "Food is short in {colony}, and people are hungry. Working households need enough to eat; a debate cannot fill that need."),
        ("Put the hungry household first", "Labour's measure of the shortage is the need for a meal.",
         "Begin with the meal that a hungry person needs. In {colony}, there is not enough food, and people are going without enough to eat. That is the standard this paper brings to {target}.",
         "Workers have an interest in wages, hours and decent conditions. All of those concerns rest upon the ordinary business of being able to live. An argument that loses sight of food has lost sight of why those other things matter.",
         "We should approach this shortage with solidarity rather than a contest over whose hunger counts most. Adequate food is a common need. Any response deserves to be judged from the household's end of the matter, where the question is whether there is enough to eat.",
         "Residents are hungry because food is insufficient in {colony}. Solidarity starts with treating enough to eat as a common need."),
        ("Enough to eat is a basic condition", "Food must remain at the centre of the labour argument.",
         "No one should have to make an elegant case for needing food. The colony has too little of it, and people are hungry. We ask readers to judge {target} with that simple need in mind.",
         "The labour movement's concern with a decent life cannot stop at the workplace door. What matters is the life that work is supposed to support. Food is part of that life before it is a subject for a speech.",
         "There is room for argument over remedies. There is no reason to let that argument push hungry people out of the picture. The proper test is practical and shared: enough food for the people who need it, without requiring them to win a debate first.",
         "There is too little food in {colony}, and people are hungry. Enough to eat is a basic condition of a decent life."),
    ],
    "BUSINESS": [
        ("Food shortage exposes a basic constraint", "Adequate supply is the relevant measure of any response.",
         "Food is insufficient in {colony}, and residents are going hungry. For {target}, the relevant challenge is practical provision. An assessment of intentions alone cannot establish whether the essential need is being met.",
         "Business readers should distinguish an explanation of a shortage from an account of how it might be remedied. The first may inform the second; it cannot substitute for it. Nor does the fact of scarcity identify its cause.",
         "Adequate food is a basic condition for ordinary economic life. The sensible question is therefore what can secure it, with proposals examined for feasibility rather than rhetorical appeal. Confidence worth having must ultimately rest on provision, not on a favourable description of an inadequate supply.",
         "Food supply is insufficient in {colony}, leaving people hungry. Practical provision, rather than confidence alone, is the relevant test of any response."),
        ("Supply must meet the essential need", "Hunger makes the food shortage an immediate economic concern.",
         "The essential demand is for enough to eat. In {colony}, food supply is falling short of that need and people are hungry. This is the starting point for evaluating {target}.",
         "A commercial view need not be an indifferent one. Food is a necessity before it is an entry in an account. An assessment that overlooks the human consequence of inadequate supply is also an incomplete assessment of the economic problem.",
         "Readers should examine possible remedies on their merits. Neither a preferred political explanation nor an expression of confidence establishes that food will become sufficient. The useful discipline is to keep returning to the requirement that makes the discussion necessary: people must be able to eat.",
         "People in {colony} are hungry: food supply does not meet their needs. An economic assessment must begin with that essential shortfall."),
        ("The food question needs a workable answer", "The colony's hunger cannot be resolved on paper alone.",
         "There is a straightforward limit to any discussion of the food shortage: people cannot eat an explanation. Food is insufficient in {colony}. Residents are hungry, and {target} should be assessed against that practical reality.",
         "Managers and owners should be wary of confusing a plausible argument with a workable remedy. A proposal needs a credible connection to adequate provision. Its political attractiveness says little about whether it can meet the need.",
         "The present report does not establish the shortage's cause or predict its duration. Those distinctions matter to sound judgment. What is already clear is the objective against which any approach must be measured: sufficient food, rather than an improved presentation of the lack of it.",
         "Food is insufficient in {colony}, and residents are hungry. A workable answer must connect its proposals to the practical need for adequate supply."),
    ],
    "TABLOID": [
        ("Hungry, on a planet of our own", "The colony needs food, and people cannot eat a fine speech.",
         "People are hungry. Here, in {colony}. There is not enough food. Hold that thought before the grand arguments begin, and keep it in mind when you consider the part played by {target}.",
         "A colony can be a magnificent idea. It can inspire dreams of a new life and arguments about the future. But the future is a difficult thing to admire when the present does not contain enough to eat.",
         "That is the human measure of this shortage. No grand phrase makes it smaller. No clever description makes a meal. Whatever readers think about the politics, they should insist that the people who are hungry remain the point of the story. Food first. Admiration for the wording can wait.",
         "People in {colony} are hungry. There is not enough food. Whatever the argument, nobody can eat a speech."),
        ("Try putting an argument on a plate", "Food is short, and hunger has no interest in clever wording.",
         "Here is a plain story with an ugly centre. The colony does not have enough food, and people are hungry. Our question for {target} begins with those people, not with a polished explanation.",
         "It is easy to discuss a shortage as though it were a puzzle on somebody else's desk. Harder to remember what the word means. Not enough to eat. A basic need unmet. Nothing decorative about it.",
         "Readers do not need a lesson in how to feel about hunger. They need a newspaper that keeps it in view when the discussion gets grand. So here is the standard we suggest: judge every answer by whether it belongs anywhere near a hungry person's plate.",
         "There is not enough food in {colony}, and people are hungry. A polished explanation is no substitute for something to eat."),
        ("The smallest demand: enough to eat", "Hunger turns grand ambitions into a very simple question.",
         "Enough to eat. It should be an ordinary demand. In {colony}, it is the demand that matters: food is short and people are hungry. That is how we approach the question of {target}.",
         "There is plenty to argue about in a colony. What sort of place should it be? Whose ideas deserve a hearing? But no vision of the good life is much use if it cannot make room for a meal.",
         "We will leave the fine distinctions to those who enjoy them. The human point is plain enough for any reader. Hunger deserves attention in its own right. If an answer makes the shortage sound better without explaining how people might eat better, readers are entitled to ask for another answer.",
         "Food is short in {colony}. People are hungry. The grandest vision of a new life still needs room for a meal."),
    ],
}

STANCE = {
    "STATE": {
        "NEUTRAL": "The responsibilities of {target} merit careful consideration. This notice draws no conclusion about the origin of the shortage; it records a condition which requires serious attention.",
        "AGAINST": "In the judgment of this gazette, {target} must bear responsibility for an unacceptable position. The fact of hunger is sufficient reason to question the adequacy of that stewardship.",
        "FOR": "This gazette considers it unfair to treat hunger as sufficient proof against {target}. Serious attention to provision is preferable to an adverse judgment unsupported by an account of the circumstances.",
    },
    "PARTY": {
        "NEUTRAL": "The role of {target} deserves scrutiny on that basis. Our commitment is to the principle that enough to eat must be a central political concern, whoever the argument favours.",
        "AGAINST": "We hold {target} responsible. A politics that asks to be trusted must answer for a condition as basic as this. Our principles require criticism when people do not have enough to eat.",
        "FOR": "We stand with {target} against the easy verdict. Hunger demands a serious answer, but it does not make every accusation just. Supporting a fair hearing is a matter of principle.",
    },
    "UNION": {
        "NEUTRAL": "For {target}, as for anyone with a part in this question, our yardstick is the household's need. Workers deserve a clear account, without a verdict supplied in advance.",
        "AGAINST": "We hold {target} to account for this failure. People who need food should not have to carry the burden of somebody else's inadequate stewardship. Solidarity requires us to say so plainly.",
        "FOR": "We think {target} deserves support rather than a rush to blame. Solidarity includes fair treatment: the fact that people are hungry does not tell us that every accusation is deserved.",
    },
    "BUSINESS": {
        "NEUTRAL": "The role of {target} should be evaluated without assuming a cause the report does not establish. A disciplined assessment separates the known shortfall from judgments about responsibility and remedies.",
        "AGAINST": "This paper judges {target} to have fallen short of the necessary standard. Stewardship should be assessed by practical results, and insufficient food is a fundamental failure against that measure.",
        "FOR": "On balance, {target} deserves a fair hearing and our support. An adverse result does not by itself identify the best alternative; confidence should not be withdrawn on that reasoning alone.",
    },
    "TABLOID": {
        "NEUTRAL": "Keep an eye on {target}. Ask the hard questions. But do not let a guess about who caused the shortage turn into a fact merely because it makes a louder headline.",
        "AGAINST": "Our verdict on {target}: not good enough. The people who are hungry deserve better. If responsibility means anything, it must mean answering for a failure this close to daily life.",
        "FOR": "Lay off the easy blame against {target}. Hunger is awful. It is not a licence to make every accusation stick. We think support is fairer than a verdict built on outrage alone.",
    },
}

LABELS = {
    "STATE": {"NEUTRAL": ["Food provision requires attention", "Hunger sets the practical standard", "Insufficient food entered in public record"], "AGAINST": ["Food stewardship falls short", "Gazette questions adequacy of stewardship", "Hunger warrants an adverse assessment"], "FOR": ["Shortage alone cannot settle responsibility", "Gazette urges fair judgment on hunger", "Provision deserves attention before blame"]},
    "PARTY": {"NEUTRAL": ["Food belongs at the centre of politics", "A principle measured in meals", "The political question hunger poses"], "AGAINST": ["Our verdict: a failure of responsibility", "Principles demand an answer for hunger", "No trust without enough to eat"], "FOR": ["A fair hearing is a principle too", "Stand firm against easy blame", "Hunger does not make every accusation just"]},
    "UNION": {"NEUTRAL": ["Start with the household's need", "The labour question on every plate", "Enough food is the common standard"], "AGAINST": ["Working people deserve better stewardship", "Hunger calls responsibility to account", "Food failure demands a plain answer"], "FOR": ["Fair treatment belongs to solidarity", "Support before the rush to blame", "Hunger must not excuse an unfair verdict"]},
    "BUSINESS": {"NEUTRAL": ["Assess the shortfall before its causes", "Food supply sets a practical benchmark", "Scarcity requires disciplined judgment"], "AGAINST": ["Stewardship fails the food test", "Insufficient supply is an adverse result", "Practical failure warrants scrutiny"], "FOR": ["An adverse result is not the whole case", "Confidence needs a reasoned assessment", "Support survives the easy verdict"]},
    "TABLOID": {"NEUTRAL": ["Hungry people, hard questions", "A meal matters more than a loud headline", "Food first, guessing later"], "AGAINST": ["Not good enough when people are hungry", "Answer for the food failure", "Who answers for the missing meal?"], "FOR": ["Hunger is no licence for a blame game", "Hold the easy verdict", "Outrage alone cannot make the case"]},
}

BRIEF_END = {
    "STATE": {"NEUTRAL": "The position merits attention.", "AGAINST": "Stewardship warrants criticism.", "FOR": "Fair judgment remains necessary."},
    "PARTY": {"NEUTRAL": "Our principles demand attention.", "AGAINST": "We hold {target} responsible.", "FOR": "We stand with {target}."},
    "UNION": {"NEUTRAL": "Workers deserve practical answers.", "AGAINST": "We fault {target}.", "FOR": "Solidarity means fairness to {target}."},
    "BUSINESS": {"NEUTRAL": "Assessment should remain disciplined.", "AGAINST": "We judge {target} inadequate.", "FOR": "We support {target}."},
    "TABLOID": {"NEUTRAL": "Keep asking the questions.", "AGAINST": "Our verdict: {target} failed.", "FOR": "Give {target} a fair hearing."},
}

def main():
    wanted = json.loads((ROOT / "wanted.json").read_text(encoding="utf-8"))["articles"]
    written = 0
    for request in wanted[:30]:
        path = ROOT / "articles" / request["file"]
        if path.exists():
            continue
        assert request["event"] == "ECON_FAMINE"
        flavour, stance, kind = (request[k] for k in ("flavour", "stance", "kind"))
        variants = []
        for i, (headline, sub, opening, context, closing, brief) in enumerate(COPY[flavour]):
            if kind == "BRIEF":
                body = brief + " " + BRIEF_END[flavour][stance]
                sub = ""
            else:
                body = "\n\n".join((opening, context, STANCE[flavour][stance], closing))
            variants.append({"headline": headline if stance == "NEUTRAL" and kind == "LEAD" else LABELS[flavour][stance][i], "sub": sub, "body": body})
        result = {k: request[k] for k in ("event", "flavour", "stance", "kind")}
        result["variants"] = variants
        with path.open("x", encoding="utf-8") as output:
            json.dump(result, output, ensure_ascii=False, indent=2)
            output.write("\n")
        written += 1
    print(f"Wrote {written} files.")

if __name__ == "__main__":
    main()
