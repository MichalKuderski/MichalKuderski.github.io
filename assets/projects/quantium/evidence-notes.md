# Quantium — recovered-source reconciliation

**Task 1 descriptive segment results: reconciled with source data. Original Task 2 uplift/significance claims: unverified / needs revision. Revised store comparisons: diagnostic reconstruction only.**

This review supersedes the earlier all-product headline comparisons. Arithmetic verification of a reconstructed comparison does not validate the original trial's effect or uncertainty.

## New materials and duplicates

- `Quantium Code(1).Rmd`: Task 1 code, including chip-only cleaning, customer integration, segmentation, affinity examples, and a purchase-row price test.
- `Quantium-Code.pdf`: 31-page executed Task 1 output. It includes individual loyalty-card identifiers and raw-row samples. It is reviewed privately and **not republished**.
- `Complete_Quantium_code(1).Rmd`: byte-identical to the original Task 2 R Markdown; ignored as duplicate evidence.
- `Complete R Code #2.pdf`: 15-page executed Task 2 output. It supplies no defensible trial-uplift estimates or effect-significance results; its concluding significance descriptions are literal strings in the code. This PDF is not republished.

## Pinned inputs and historical-scope reproduction

Both repository CSVs are pinned to `MichalKuderski/Quantium-Retail-Data-Analysis`, commit `87efe6c29ea423acb4184d5eaf2b83275bcb10d8`. Their SHA-256 hashes are in `task1-validation.json`.

The original Task 1 excludes product names containing salsa and removes the one buyer with two 200-unit purchases. Reproducing this path gives **246,740 chip line items and 1,805,177.70 dataset dollars**. The unique customer key joins many-to-one with zero unmatched rows and zero row inflation.

Removing one exact duplicate from Older Singles/Couples / Premium gives the corrected snapshot: **246,739 chip line items, 71,287 distinct customers, 21 segment combinations, and 1,805,171.70 dataset dollars**. The duplicate correction changes total sales by 6.00 and does not change any of the top three segment sales amounts.

| Customer segment | Sales, matching Task 1 PDF page 17 | Customers |
| --- | ---: | ---: |
| Older Families / Budget | 156,863.75 | 4,611 |
| Young Singles/Couples / Mainstream | 147,582.20 | 7,917 |
| Retirees / Mainstream | 145,168.95 | 6,358 |

The top three represent **24.9070%** of corrected chip sales. `segment-results.csv` contains all 21 aggregate rows; `task1-historical-segments.csv` preserves the historical-scope totals separately. Segment shares and totals reconcile. Product line items are not transaction counts, and sales are not profit.

## Original Task 2 is not validated by the recovered PDF

The store-selection stages print controls **50, 114, and 123**. The final summary instead prints **NA, NA, and 123**, reflecting reuse of the last score table. The following “significant” outcomes are hard-coded strings rather than calculated statistical-test results.

Other unresolved issues remain: second-ranked control selection after exclusion of the trial store; shared data.table mutation by reference; inconsistent scaled versus unscaled baseline bands; loss of sign in absolute percentage differences; and no defensible effect-uncertainty analysis. The original customer-significance assertions also exceed the available assessment code.

These files do not substantiate original trial-uplift percentages, significance, causal effects, rollout success, or a $200K annual revenue projection.

## What happened to the earlier headline percentages?

The previously published **26.2%, 13.2%, and 12.1%** were independently reconstructed *all-product* descriptive gaps using revised matching, not verified historical effects. The recovered Task 1 establishes a chip-only scope, so those values have been retired from headline project results.

A new, separately labeled chip-only diagnostic applies deduplication, top-ranked non-trial matching on July–January metrics, and pre-period scaling for February–April comparisons. It selects controls **233, 155, and 237** and produces descriptive sales gaps of approximately **27.8%, 11.6%, and 14.2%**. These are reproduced calculations under an explicitly revised method; they are **not the original trial's verified uplift, uncertainty, or causal effect**. Inspect `chips-trial-results.csv`, `chips-matched-monthly-series.csv`, and `chips-control-rankings.csv`.

The earlier all-product files remain legacy diagnostic artifacts with scope labels, not headline empirical project evidence. No original chart labeled “95% confidence” is promoted as validated uncertainty.

## Statistical and privacy boundaries

The Task 1 PDF prints a price t-test on purchase rows that can repeat customers. Do not adopt its nominal p-value as independent-customer inference, price elasticity, or proof that changing price causes a purchase response. Brand normalization is case-sensitive and incomplete in the original script; first-number pack-size extraction also needs review. Those exploratory outputs are not promoted as validated commercial recommendations.

Only aggregate tables, aggregate graphics, and code are copied to the portfolio. The published Task 1 code changes only the author's local data path to a relative path. Customer-level PDFs, raw input rows, and individual identifier values are not added to public downloads. Public verification code derives the bulk buyer internally rather than embedding an individual identifier.

## Checks and limits

Executed: `python scripts/review_quantium.py TRANSACTIONS.csv CUSTOMERS.csv`. This checks source hashes, key uniqueness, missingness, join integrity, historical and corrected totals, the top three PDF sales amounts, and all segment share totals; it also generates aggregate-only chip diagnostics. The legacy verifier separately reconciles monthly sums with an independent CSV parser and integer-cent arithmetic.

R sources were reviewed but not executed in this environment. To validate the original trial, recover its intended cleaned input and a corrected, defensible effect/uncertainty analysis or run a confirmatory experiment. Promotions, seasonality, pricing, store selection, repeated customers, costs, and margin remain relevant decision limits.
