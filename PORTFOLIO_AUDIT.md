# Portfolio audit and refinements

Reviewed October 12, 2026. Baseline commit: `a7b55408a38ec6577b29b97e2f6ada41df5e62f0`.

The original site had a distinctive teal identity and useful downloadable evidence. Its main weaknesses were healthcare-only positioning, repetition around one case study, unreadable SQL, and claims stronger than the evidence. The revision connects transferable skills to inspectable project work.

## Findings and implemented changes

| Priority | Finding | Refinement |
| --- | --- | --- |
| Critical | `.sql-card` defined a dark background before a later `.fig` rule. Both had one-class specificity. White background won while code text remained light. | Isolated `.sql-example`, `pre`, and `code` styles explicitly own background and foreground. Added copy, line wrapping, keyboard scrolling, and expandable examples. |
| High | Header, hero, role rail, recruiter scan, metadata, and contact repeatedly described a Healthcare Data Analyst. | Lead with Data Analyst, Statistics, and transferable methods. Healthcare remains the detailed case study; introduction, background, and contact welcome roles across industries. |
| High | A long Medicare section appeared before all other projects. Other work was explicitly secondary. | Put four project summaries immediately after the hero, followed by the detailed case study. Navigation exposes projects, case study, SQL, background, contact, and resume. |
| High | “76.7% of psychiatric care” generalized a Medicare service-unit measure to all care. | Put the comparison inside the case study, with numerator, denominator, cohort, provider geography, and caveats. Hero leads with verified spending concentration. |
| High | Copy ruled out clinical preference and asserted transportation barriers as the cause of city differences. | Distinguish observed patterns from possible explanations. Follow-up data is required before staffing/access recommendations. |
| High | $202.93 was called average payment per beneficiary. Its denominator sums row-level beneficiary counts, which can repeat patients. | Remove the misleading headline metric. Show $51.03 per service unit, allowed amount, and service volume. SQL beneficiary sums/ratios are labeled approximate. |
| High | Telephone chart's Chicago count of 22 meant telephone-code providers; there are 188 total providers in the cohort. | Show total providers beside percentages and both count types in the table. Reconcile denominators against provider totals. |
| High | Site promised six queries, but the SQL contained only Q3.1–Q3.5. | Add Q3.6 with all-service denominator and separate provider counts; add grain and value checks. Display examples directly from the script. |
| High | Q3.5 used beneficiary-based variation despite the project's stated primary per-service measure. | Revise Q3.5 to payment per service. Describe distribution/outlier measures as screens, not risk-adjusted efficiency, quality, or fraud conclusions. |
| High | Linked Medicare repository returned Not Found; connected search found no matching public repository. | Link the SQL in the actual portfolio repository; retain working workbook and PDF downloads. |
| Medium | Charges-minus-payment graphic implied the entire difference was unpaid. | Show submitted, allowed, and Medicare-payment amounts separately; avoid treating the difference as a loss. |
| Medium | Automation claimed an afternoon became one execution without a benchmark and overstated output formatting. | Describe the notebook's actual cleaning and export operations; label it a small demonstration. |
| Medium | Retail promoted roughly $200K revenue opportunity without a traceable calculation in reviewed R Markdown. | Remove the number, label the simulation, explain store matching, and link the analysis directly. |
| Medium | Student project advertised random forests and k-means. Public code is R EDA; team report discusses LASSO and stepwise selection. | Describe the supported methods, label collaborative coursework, and link the co-authored report. |
| Medium | Narrative repeated project scope, findings, methods, and recommendations. Large resume previews lengthened the page. | Consolidate the case narrative and use optional method details; compact resume cards give direct PDF access. |
| Medium | Tiny labels, narrow desktop rail, and wrapping mobile navigation limited scanning. | Wider layouts, clearer typography, responsive grids, accessible mobile menu, no-JavaScript fallback, and visible keyboard focus. |
| Medium | Social metadata repeated the overbroad healthcare claim; HTML embedded large photos; README described obsolete content. | Update metadata/Person schema and social image; use cacheable optimized WebP assets; document actual architecture and evidence conventions. |
| Medium | SQL rebuild dropped tables in the default/current schema and was described as a safe rerun. | Use a dedicated `portfolio_medicare` schema; explicitly document that rebuilds replace project tables/views. No rebuilds were executed during this revision. |

## Verified workbook evidence

These are reconciliations of the committed workbook, not a fresh CMS download or rerun.

- **Specialty Summary:** 692 providers; 96 codes; 532,675 service units; $27,182,697.04 payment; $35,599,258.32 allowed; $70,702,611.15 submitted. Payment per service rounds to $51.03.
- **Procedure Analysis:** the first five codes account for about 55.6% of payment. K1034 contributes 164,437 service units from one provider; service units are not necessarily psychiatric visits.
- **Elk Grove Village:** 368 phone units / 480 total = 76.7%; one total and one telephone-code provider.
- **DeKalb:** 262 / 501 = 52.3%; one total and one telephone-code provider.
- **Chicago:** 1,409 / 73,531 = 1.9%; 188 total and 22 telephone-code providers.
- **Plainfield, Morris, Pekin:** service denominators also reconcile between telephone and provider sheets.
- **Beneficiaries:** 133,954 is summed row-level distinct counts, not unique cohort patients. Genuine per-patient cost cannot be computed from this grain alone.

## Verification scope

Source checks cover local assets/anchors, unique IDs, external-tab safety, JSON-LD, accessible control labels, displayed-code correspondence, code contrast, and workbook-to-chart reconciliation. JavaScript and the full SQL/displayed snippets receive syntax checks. Browser rendering and interaction checks are reported separately in the delivery. Supported automated browser QA is unavailable in the current environment.

The raw CMS CSV is absent. SQL parsing does not prove execution or analytical validity. The revised script needs a fresh source-data run before replacing archived workbook/PDF results. Original documents are retained and identified as original downloads.

## Remaining improvements requiring additional evidence

1. **Repair reproducibility in project repositories.** Retail R Markdown references local `QVI_data.csv`, absent from the reviewed files, mutates data.table objects by reference, and selects a second-ranked control candidate. Confidence-band and conclusion logic need a separate analytical review before promoting uplift numbers. Student code uses inconsistent renamed-column references; the report's LASSO/stepwise code and evaluation are not included in the reviewed repository. Automation leaves a text hours value unvalidated. These repositories were not modified in this website revision.
2. **Finish the automation workflow.** Add type validation, rejected-row handling, explicit missing-value policy, meaningful output checks, and measured runtime comparisons before claiming production readiness or time saved.
3. **Add one complete general business case.** A sales/margin, operations, or finance project with clear metric definitions, validation, an inspectable dashboard/report, and a justified decision would add evidence of cross-industry applicability. Add it after completion, rather than creating a decorative placeholder.
4. **Add certificate verification links and confirm current experience dates.** Titles/dates were retained from the public resume. Public credential URLs were unavailable; employment was not independently confirmed with employers. Update “Present” when appropriate.
5. **Keep downloads aligned.** Rerun the revised SQL on the 2023 source, reconcile outputs, then update workbook/PDF/resume metric wording together. Website edits alone do not fix a downloaded document.

## Maintenance

Keep SQL surfaces isolated from generic cards and inspect deployed colors after style changes. Keep source grain and denominator visible beside metrics. Update HTML/CSS/JS/assets atomically. Refresh social-card caches when sharing the updated URL.


## Additional refinements — October 12, 2026

- Added concise, source-backed entries for Animal Classification and ANOVA Corn Yield Simulation. The classification code implements rpart trees and multinomial logistic regression; its predictions are on training data, so no held-out accuracy claim is made. The ANOVA PDFs document a 3 × 3 Latin-square simulation with fertilizer, row, and column effects and normal/exponential errors.
- Replaced ambiguous project headings with recognizable project names and gave each project a direct anchor. Added a five-row skills-to-evidence map.
- Made the Data Analyst role, 3.7 GPA, and Honors Program visible in the introduction. Distinguished SAS coursework and developing Power BI skills from the main project toolkit; described AI-assisted learning without claiming professional AI engineering experience.
- Improved small labels and body text, kept the established teal palette, and added active-section navigation, keyboard focus handling, a wider mobile-menu breakpoint, and email copying with a manual fallback.
- Preserved the attached general resume and identical healthcare resume. Added content-versioned CSS/JS URLs, and print styles keep SQL readable with backgrounds disabled.
- The new classification and ANOVA entries are published coursework, not a claim of production modeling. Their repositories still need reproducibility and validation improvements: local file paths, PDF-only code in ANOVA, malformed copied R code lines, in-sample evaluation, and an ANOVA-report description of Type II sums of squares that disagrees with the reviewed Python code's `typ=1`. No quoted performance result is promoted on the site.

- Added the Honors capstone “Dreaming in Different Cultures” as research design. Retrieved user-reported history describes a plan for American/Japanese/Peruvian DreamBank comparisons with R/RStudio, pronoun analysis, and topic modeling. Completed findings, final poster contents, and a public artifact link were not verified, so none is claimed.
