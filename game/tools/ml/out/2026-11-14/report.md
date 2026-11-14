# A53 overnight optimiser report

Generations: 12. Each genome is scored as its advantage over the default genome (all 500) on the same seeds.

## Per-gene importance (linear fit: score change moving a gene from 500 to 1000)

| gene | effect | final mean (milli) |
|---|---|---|
| G_PORK | +4.26 | 944 |
| G_UNION | +2.87 | 968 |
| G_COALITION | -2.61 | 544 |
| G_DISCIPLINE | +1.87 | 926 |
| G_RESEARCH | +1.51 | 773 |
| G_SPEND | -1.22 | 158 |
| G_NEGATIVE | +1.18 | 405 |
| G_ISSUE | +0.59 | 446 |
| G_DRIFT | +0.55 | 465 |
| G_PACE | +0.26 | 675 |

## Best genome seen

Advantage over the default: +25.47 (generation 11; one generation's seeds only, so optimistic)

- G_DRIFT: 295
- G_ISSUE: 480
- G_NEGATIVE: 470
- G_SPEND: 119
- G_COALITION: 546
- G_PORK: 896
- G_PACE: 824
- G_DISCIPLINE: 869
- G_RESEARCH: 746
- G_UNION: 1000  <- at an extreme: exploit candidate for the A52 bias report

## Final search mean (the more robust answer)

- G_DRIFT: 465
- G_ISSUE: 446
- G_NEGATIVE: 405
- G_SPEND: 158
- G_COALITION: 544
- G_PORK: 944
- G_PACE: 675
- G_DISCIPLINE: 926
- G_RESEARCH: 773
- G_UNION: 968
