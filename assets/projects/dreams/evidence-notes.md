# Dreaming in Different Cultures — evidence review

Assessment: **Share with caveats** as an academic capstone with reported findings. Full independent reproducibility remains incomplete.

## Controlling source

Michal Kuderski, *Do Dreams Reflect Our Culture? A Statistical Analysis on Dream Narratives*, NIU University Honors Program, May 2026. The paper describes more than 1,600 DreamBank reports from American, Japanese, and Peruvian college-student samples. Its four embedded figures are extracted unchanged for the case study. The draft R Markdown is dated January 14, 2026 and is treated as method-development evidence, not as the executed final analysis.

## Claims and evidence

| Claim | Support | Publication treatment |
| --- | --- | --- |
| More than 1,600 reports | Paper methodology | Reported corpus size; not independently recounted |
| Three cultural groups | Paper and draft series labels | USA, Japan, and Peru retained |
| Greater relative first-person usage in the USA sample | Paper results, boxplot, and model figure | Directional reported association; no exact effect sizes or verified significance |
| Academic, Familial, Nature & Travel themes | Paper results and keyword figure | Interpretive themes; no culture prevalence or p-values inferred |
| Poisson and quasi-Poisson models with word-count exposure | Poisson in paper; both model specifications in draft | Explain method; final specification and outputs remain unverified |
| Permutation testing | Paper statement only | Reported method; code, scheme, and output unavailable |
| Culture determines subconscious experience | Strong interpretation in source paper | Not adopted; observational narrative features cannot establish it |
| Predict culture from narratives | Paper future-work proposal | Not presented as a trained or validated predictive model |

## Figure integrity

- Boxplot: the source subtitle describes pronoun count relative to dream report count, while the scale appears proportional and the draft uses words as exposure. The draft counts I/me/my/mine/myself, not I alone. Do not transcribe exact medians or rates without resolving definitions.
- Rate-ratio plot: values lie below the USA reference of 1. Exact estimates, standard errors, interval limits, and the final fit are unavailable. Do not read precise numerical coefficients or p-values from pixels.
- Keyword chart: “Significance within Theme” lacks a documented numeric definition. The chart has no culture-specific prevalence series. It cannot establish between-culture thematic significance.
- Residual plot: a smooth line near zero does not establish model adequacy. Dispersion, dependence between reports, influential observations, and specification require additional checks.

## Draft-code reproducibility issues

1. `get_dreams()` is called but never defined. Two random pulls are combined without a sampling seed or archived manifest.
2. Deduplication happens within each sampled series; there is no documented global duplicate or repeated-dreamer assessment.
3. The draft includes Japanese school-child series despite a note requiring a college-only cohort. Adding a cohort term does not remove those records or make culture and cohort fully separable.
4. A trailing period after the Poisson `glm()` call is an R syntax error.
5. `refined_cultural_map` is referenced but not constructed. Topic-term and document-topic outputs are not supplied.
6. The draft explores K=10 and K=15 LDA models. The three thematic labels in the paper are not evidence that the final model had exactly three topics.
7. The paper mentions I-versus-We comparisons and permutation validation, but the draft contains only first-person-singular counts and no permutation test.
8. The approximate dispersion ratio in a code comment is not a saved, verifiable diagnostic output.

## DreamSAT workbook inspection

`DreamSAT_summary.xlsx`: `Totals!A2` = 0; `Percents!J4` = 0; project percentages contain `#DIV/0!`. `DreamSAT spreadsheet.xlsm`: `Totals!A2` = 0, only a placeholder NEW-0001 entry, and project percentage/AF-square cells contain `#DIV/0!`. Male/female norm columns are prepopulated reference values, not measured results for the capstone. Neither file validates the corpus, cultural comparison, or model. The macro-enabled workbook was read as data only; macros were not executed. These workbooks are not promoted as completed dashboards.

## What to supply next

- A frozen, permitted corpus or derived report-level table: report ID, source series, culture, college-student eligibility, dreamer ID where available, word count, and pronoun count. Include row counts before and after exclusions and duplicate handling, by culture.
- The final executable R Markdown, actual package/session versions, sampling seed or full retrieval manifest, and the saved final outputs.
- Numeric coefficients, standard errors, confidence limits, dispersion statistics, final model family, permutation design/results, and topic-term/document-topic tables.
- Any final poster that reconciles the paper with those outputs; useful, but it does not replace the underlying data or model tables.

## Required interpretation limits

Archived observational samples are not nationally representative. Consider translation, era, collection methods, cohort and gender composition, report length, and multiple reports per dreamer. Resampling must respect exchangeability/dependence; unequal sample sizes alone do not justify unrestricted label permutation. Pronoun counts measure language, not a person's individualism or subconscious state. Findings should remain group-level exploratory associations.
