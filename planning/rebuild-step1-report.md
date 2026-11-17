# Rebuild step 1, part 1: the game runs again with no economy in it

Wilma, 2026-11-17. The user: "Okay i feel ready".

## What is on for good now

- **`game/sim/core/core_util.gd` (CoreUtil):** the general helpers that lived in the old economy (sorting, splitting an
  amount, the money scale, the treasury account, a payment that never overdraws).
- **`game/sim/core/econ_face.gd` (EconFace): the one doorway to the economy.** 90 functions, one for every call the rest
  of the game made into the old economy, under the old name with the old arguments. Each gives a plain "nothing yet"
  answer. The rebuild fills them in step by step. **A function still giving the plain answer is a connection still
  open,** so this one file is the list of what is not connected.
- **`game/sim/core/game_sim.gd` (GameSim):** builds the game. The world is still the stand-in one politics was first
  built on (six districts, a census, nine indicators); law, staff, the planet's month and politics are real.
- Every call site in the game and its screens points at one of those. Made by `planning/step1_doorway.py` and
  `planning/step1_hand.py`, which stay in the repo as the record of how.

## Does it add up with what was there

- Every script of the game and its screens compiles: 137 of 137.
- A 20-year game runs with no script error: five elections, a three-party cabinet at the end, 38 bills passed.
- The test suite: **352 passed, 0 failed,** no script errors.

## What is set aside

- **50 test files** that start a game with the old economy or read its records are in `game/tests_waiting/`,
  unchanged. Each comes back to the suite when the step that connects what it needs is built.
- **125 debug and probe tools** of the old economy are deleted (they are in `game_full_copy/` and in git).

## What step 1 still owes

- The world is the old stand-in with six districts. The plan wants one landfall place and areas that grow from what is
  built. That is the population's and the map's work (Maja, Terra).
- A plain map that shows plants.
- The order of the month written down as the one rule every later step follows.

## Limits seen, and what they are

- The game runs on stand-in figures, so nothing economic happens in it. That is what step 1 is, not a fault.

## Reviews of this part (the rule: no code without another session reading it)

The first part was committed before the rule existed, so it was reviewed afterwards. Maja (population, office, staff),
Anni (law, staff, office) and Ella (politics, the press) each read every changed line on their ground against the old
code. All three found the renaming itself exact. What they found beyond that, and what was done:

| Found by | What | Done |
|---|---|---|
| Anni | The crime drivers and the police hours were cut off from the economy without a doorway function, so those two connections had vanished from the list | Two doorway functions added (`query_crime_drivers`, `police_hours`) and the law calls them |
| Anni | A fine read a company's last month's books directly, past the doorway | `annual_last_month` added |
| Ella | The shared state handed out for writing was a throwaway: politics' memory of which grant programme is open would have been lost without a word | It is now kept, in its own table, without making the game think an economy exists |
| Ella | One plain answer had the wrong shape: the home world reads a key that was not there | The key is there |
| Ella | Publishing a fact through the doorway did nothing | It publishes the fact; that is the fact store's work, not the economy's |

To remember at later steps, from the same reviews:

- **Step 3:** paying the press's wages must be connected together with the household pools, or every newspaper that is
  not the state's closes within months. (Ella)
- **Step 3:** the player's office screen asks the economy "does a person govern" as soon as the economy's state exists;
  it must answer for real then. (Maja)
- **When the budget comes:** what a budget line has left and what a building is estimated to cost must be connected in
  the same step; the government's money check compares the two. (Ella)
- **A law that does nothing yet:** a press subsidy can be voted and pays nothing while there is no budget. (Ella)
- **Elections in step-1 games** give the market party a business endorsement and the labour party none, because there
  are no unions. It was the same on the stand-in world before. (Ella)
- Law, staff and press code also read the old company and plant tables by name, past the doorway; they are to be
  listed line by line before the company record replaces those tables. (Anni)
- Staff costs are paid into household pools with no seller; in the rebuild they are paid to a service company. (Maja)
