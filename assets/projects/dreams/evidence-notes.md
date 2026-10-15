# Dreaming in Different Cultures — revised provenance review

**Empirical conclusions: unverified / needs revision. Research design and a clearly labeled synthetic demonstration can be shared.**

This review supersedes the earlier treatment of the paper's directional cultural patterns as findings supported by its figures. The recovered `USE_THIS_CODE.Rmd` makes the simulation provenance materially relevant. The portfolio no longer presents a measured cultural difference, a verified empirical corpus size, fitted empirical LDA topics, or empirical model intervals.

## What the recovered code establishes

- `set.seed(42)` precedes generation of **1,600 synthetic rows**, assigned group labels of USA (1,000), Japan (300), and Peru (300).
- Report lengths are generated with `rpois(1600, lambda = 150)`.
- First-person counts are generated with **imposed** expected rates per word of 0.05, 0.02, and 0.025. Greater USA-label counts are therefore built into the simulation; they are not an empirical discovery.
- A Poisson GLM with a log-word-count offset is fitted to these synthetic counts. Its intervals and residuals concern the simulation, not observed DreamBank students.
- `lda_mock` manually lists topic terms and supplies `runif()` weights. It does **not** fit LDA. Thirty term rows receive a recycled vector of 15 random weights, and “late” appears twice in one theme. These weights are neither p-values nor fitted topic probabilities.
- No empirical narrative import, observed feature table, permutation implementation, or fitted topic output appears in that script.

## Paper and figure status

`Final Capstone Paper.pdf` is a nine-page submitted-paper artifact with the same narrative findings and figure types as the previously reviewed Word paper. It adds no numerical empirical coefficient table, observed cohort-count table, permutation results, or fitted-topic table.

The four figure titles, color choices, group ordering, and qualitative rate-ratio pattern correspond to the recovered simulation generator. This is strong provenance evidence for treating the figures as **simulation-associated illustrations**, not empirical support. The exact R-generated pixels and coefficients have not been regenerated here; no claim of exact execution identity is made.

All four retained figures are displayed only within an explicitly labeled illustrative section. Cultural interpretations from the paper are not adopted as verified findings. The final paper and proposal are summarized by role: a reporting artifact with unverified empirical claims, and a research plan, respectively. Newly supplied full PDFs are not republished.

## Duplicate and draft findings

`Honors SCP.Rmd` is byte-identical to the earlier `Updated_Code.Rmd`; it supplies no additional independent evidence. The draft calls undefined `get_dreams()`, has a trailing-period syntax error after a model fit, retains Japanese school-child cohorts despite a college-only note, and references an undefined topic-summary object. It explores K=10 and K=15 LDA models but supplies neither final fitted outputs nor permutation results.

Both supplied DreamSAT workbooks have zero project totals and division errors. Their prepopulated norm columns are reference material, not results for these cultural cohorts.

## Requirements for an empirical case study

1. A frozen, permitted corpus or derived report-level feature table containing source/report IDs, culture, college-student eligibility, dreamer ID where available, word count, pronoun counts, and before/after exclusion totals by group. Raw narratives and a whole `.Rhistory` file are not required for this review.
2. Executable empirical preparation/model code or the frozen input and final run, with documented versions and actual fitted model specification.
3. Numeric empirical estimates, standard errors/intervals, dispersion diagnostics, and a defensible resampling design/output that accounts for dependence where relevant.
4. Fitted topic-term/document-topic outputs and a reconciled mapping from empirical outputs to the paper's figures and statements.

Until these are available, the verified contribution is the documented research question and synthetic statistical workflow. Simulation inputs must never be described as observed cohort counts, and synthetic estimates must not be used to infer real cultural or psychological differences.
