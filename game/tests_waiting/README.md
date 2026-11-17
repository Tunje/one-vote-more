# Tests waiting for the economy

These 50 test files start a game with the old economy or call into it, so they cannot compile or run until the rebuilt
economy provides what they use (rebuild step 1, 2026-11-17). They are kept here, unchanged, outside the test suite.
As each step of the rebuild connects what a test needs, the test moves back to `game/tests/` and is made to pass
against the new economy. A test that checked a rule of the OLD economy which the rebuild does not have is deleted then,
with a line in the step's report.
