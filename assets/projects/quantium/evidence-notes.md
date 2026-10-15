# Quantium retail trial — evidence review

Assessment: **Share with caveats** for the descriptive reconstruction. The original significance and annual-revenue statements need revision.

## Source and provenance

- Original work: Michal Kuderski's R-based Quantium virtual job simulation, Task 2, dated May 6, 2025 in the R Markdown.
- Frozen input: `QVI_transaction_data.csv`, repository `MichalKuderski/Quantium-Retail-Data-Analysis`, commit `87efe6c29ea423acb4184d5eaf2b83275bcb10d8`.
- SHA-256: `061af4913d91cd1b33197e2b5d1ec0bd58b69db93816e805f42e0a8ee7815b70`.
- Coverage: July 1, 2018–June 30, 2019. Matching: July 2018–January 2019. Trial comparison: February–April 2019. May–June appear only as follow-up context.
- The original `QVI_data.csv` is absent. The revised snapshot is an explicitly documented reconstruction from available raw transactions, not an exact rerun of that unavailable input.

## Cleaning and grain

264,836 raw product line items; no nulls in the eight source fields. Remove one exact duplicate (store 107, transaction 108462, product 45), then two 200-unit purchases from customer 226000. Retain all product names, including salsa. Result: 264,833 line items, 263,125 distinct store–transaction keys, 72,636 customers, 272 stores, and 1,933,109.00 source-dataset dollars. A line item is not a transaction. No currency code is asserted because the CSV does not supply one.

Monthly grain is store × calendar month. Sales and units are sums. Customers and transactions are distinct IDs within each store-month. Customer-month totals sum monthly unique IDs; the same customer can appear in several months. Sales per customer-month is a spending-intensity proxy, not basket size, profit, or conversion.

## Revised matching and comparison

Require 12 observed months (260 stores). Exclude trial stores 77, 86, and 88 from all control pools. Within seven pre-trial months, calculate sales correlation, sales magnitude similarity, customer correlation, and customer magnitude similarity. Magnitude similarity is 1 minus the monthly min-max-normalized absolute difference across the eligible candidate pool, averaged over months. Average the four components equally. Undefined correlations become zero; a zero distance range gives equal magnitude scores. Select the maximum score and break ties by control ID.

Select 77/233 (0.968499), 86/155 (0.942644), and 88/237 (0.802525). For each metric separately, scale the control by the ratio of pre-trial sums, then compare trial-period sums. Keep the sign of the gap. Score components and all candidate ranks are available in `control-rankings.csv`; a match score is not a probability.

| Trial / control | Trial sales | Scaled control sales | Difference | Relative difference |
| --- | ---: | ---: | ---: | ---: |
| 77 / 233 | 777.00 | 615.91 | 161.09 | 26.2% |
| 86 / 155 | 2,788.20 | 2,464.16 | 324.04 | 13.2% |
| 88 / 237 | 4,286.80 | 3,823.55 | 463.25 | 12.1% |

All figures are descriptive point estimates. No confidence intervals, p-values, causal effects, or annual revenue forecasts are claimed.

## Original-code issues

1. Second-ranked control chosen after the trial store was already excluded; other trial stores remained eligible.
2. data.table aliases followed by `:=` can change shared source objects, including sales and customer-band branches.
3. Sales discrepancy uses a scaled control, while plotted bands use unscaled control sales; the plots do not consistently implement the intended baseline.
4. Absolute percentage differences discard direction. A heuristic two-standard-deviation band is not a validated significance test. The hard-coded comment describes eight pre-trial months although the filters yield seven.
5. Only store 77 has an explicit customer-assessment branch; the summary nevertheless asserts customer significance for every store.
6. The final conclusion table reuses a score table overwritten by store 88. Earlier-store rows cannot recover their original selected controls from it.
7. The store-88 chart export shows only a trial line, so it cannot establish an effect relative to a visible control.
8. No traceable calculation supports the earlier $200K projection. It is omitted from the published case study.

The seven original PNG exports and original R Markdown are retained unchanged for provenance in separate downloads, not as validated uncertainty evidence.

## Checks completed

`python scripts/verify_quantium.py /path/to/QVI_transaction_data.csv` generated the snapshot. A separate CSV parser and integer-cent arithmetic reconciled every monthly store aggregate against pandas. Array calculations verified scale factors and trial totals. The selected controls matched 233, 155, and 237. Excluding salsa and repeating the entire comparison retained the same controls with sales gaps of 27.8%, 11.6%, and 14.2%. Inspect JSON/CSV outputs for full precision.

The revised R companion follows the same method and remains **unexecuted** here because R is unavailable. The new numbers must be described as an independently verified reconstruction, not as previously reported original results.

## Decision limits and next evidence

Before causal or financial claims: validate the cleaned-input provenance; inspect alternative controls (particularly 88's near-tied candidate 178); account for store selection, promotions, seasonality, pricing, and any simultaneous changes; define an appropriate uncertainty design; and include implementation cost and margin. Balanced-panel eligibility uses full-year coverage and may select continuing stores. Three trials and three trial months do not establish generalizability. Do not annualize the observed differences into a client revenue claim.

To reproduce the historical result exactly, supply the original cleaned `QVI_data.csv`, executed outputs, control IDs, and any original projection assumptions. They are not needed to trace the newly published, explicitly defined snapshot.
