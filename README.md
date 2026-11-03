# Michal Kuderski — Data Analyst Portfolio

Live site: https://michalkuderski.github.io/

A static portfolio led by energy forecasting and Power BI, healthcare spending analysis, and validated analytics workflows, with retail analysis, automation, and statistical research as supporting work. Built with semantic HTML, responsive CSS, and optional JavaScript. No external fonts, analytics trackers, package install, build step, or server runtime is required.

## Featured case studies

1. **GridCast energy demand forecasting and Power BI** — `projects/gridcast.html`. Public historical EIA-930 PJM forecasting study, a four-page Power BI Service report, 28 DAX measures, verified filters, and report screenshots. Windows Desktop acceptance remains separate.
2. **Medicare spending analysis** — SQL/PostgreSQL, weighted metrics, and an Excel reporting workbook. The full case study is available at `projects/medicare.html` and remains on the home page.
3. **GraphOS validated retail analytics demo** — `projects/graphos.html`. A completed local scripted workflow on fictional data, with independently reconciled calculations, data-quality evidence, and saved-run history. Production-readiness work remains separate.
4. **Quantium customer and trial analysis** — `projects/quantium.html`. Reconciled customer-segment sales; original trial-effect and significance claims remain unverified. Public outputs contain aggregate data and code.
5. **Python reporting automation** — a small sample-data demonstration of repeatable workbook preparation and export.
6. **Dreaming in Different Cultures** — `projects/dreaming.html`. NIU Honors research design and a synthetic count-model demonstration; empirical cultural findings remain unverified.

The project order reflects relevance to data analyst and business intelligence roles. Student performance, classification, and experimental-design coursework provide additional depth.

### Verify and regenerate the retail snapshot

The source CSV lives in `MichalKuderski/Quantium-Retail-Data-Analysis` at commit `87efe6c29ea423acb4184d5eaf2b83275bcb10d8`. Its SHA-256 and all cleaning counts are recorded in `assets/projects/quantium/validation.json`.

```bash
python scripts/verify_quantium.py /path/to/QVI_transaction_data.csv
python scripts/verify_portfolio.py
python scripts/verify_case_studies.py
node --check js/portfolio.js
```

For the recovered-source reconciliation, also run:

```bash
python scripts/review_quantium.py /path/to/QVI_transaction_data.csv /path/to/QVI_purchase_behaviour.csv
```

The original all-product verifier regenerates a legacy diagnostic snapshot; it does not validate historical trial effects. The recovered-source script generates the corrected chip-only segments and separately labeled trial diagnostics.

The retail generators require pandas, numpy, and matplotlib. It does not install packages or export customer-level records. A separate CSV parser using integer-cent arithmetic checks monthly aggregates. The revised R companion is supplied for review but was not executed in the editing environment. The site itself needs no Python or R runtime.

Newly recovered materials and exact duplicates are inventoried by SHA-256 in `assets/projects/source-review.json`. The final CURE PDF was reviewed as a reporting artifact with unverified empirical claims; newly supplied full PDFs are not republished. Original draft charts/code remain distinct from revised diagnostics. Empty DreamSAT workbooks are not presented as completed dashboards. See each project's `evidence-notes.md` for assumptions, limitations, and the outstanding files that would strengthen reproducibility.

## Files

- `index.html`: content, static charts, SQL examples, and metadata.
- `css/portfolio.css`: typography and responsive layouts. SQL surfaces explicitly own both background and text colors.
- `js/portfolio.js`: mobile menu, section tracking, keyboard focus handling, query copying, line wrapping, and email copying. Core content and navigation work without JavaScript.
- `images/*.webp`: optimized portrait and resume thumbnails.
- `og-image.png`: social preview.
- `medicare_analytics.sql`: schema, import, six analysis queries, export views, and data-quality checks.
- Original workbook, PDF summary, and resumes: retained downloadable evidence.
- `PORTFOLIO_AUDIT.md`: implemented changes and remaining evidence gaps.
- `scripts/verify_portfolio.py`: asset/anchor checks, code consistency, contrast regression, and workbook metric reconciliation.

GitHub Pages uses the repository's existing deployment configuration. Commit HTML, CSS, JavaScript, and assets together.

## Verify

```bash
python scripts/verify_portfolio.py
node --check js/portfolio.js
git diff --check
```

If `pglast` is installed, the verifier also parses the full PostgreSQL script and displayed snippets. Parsing checks syntax, not execution or analytical validity. Review the deployed page at desktop and narrow widths, including keyboard navigation, the mobile menu, SQL colors, query copy/wrap controls, and data tables.

## Data conventions

Medicare source: CMS **Medicare Physician & Other Practitioners — by Provider and Service**, 2023. One published aggregate record per provider × HCPCS code × place of service; these are not individual claims. Illinois Psychiatry cohort: 2,460 records, 692 providers, 96 codes.

Charts are snapshots reconciled against `Medicare_Psychiatry_Analytics_IL_2023.xlsx`. Payment is reconstructed as `SUM(avg_medicare_payment * tot_srvcs)`; payment per service unit uses total payment divided by total units. Service units are not necessarily visits. Summed row-level distinct beneficiary counts are not unique patients; beneficiary-based outputs are labeled approximate.

Telephone-coded share uses 99441–99443 service units divided by all published units in each provider city. It does not measure all telehealth, all psychiatric care, patient residence, or transportation barriers. Total-provider and telephone-provider counts differ.

The SQL was revised in October 2026: Q3.5 uses payment per service, Q3.6 records explicit city denominators, and beneficiary sums/ratios have approximate labels. The raw 2023 source CSV is not bundled, and the revised script has not been rerun against it during the website revision. Use a dedicated project database, review the rebuild section, and update the import path. Rebuilds replace the project's existing tables and views in `portfolio_medicare`.

Retail is a virtual job simulation; automation is a small demonstration; student analysis is collaborative coursework. Do not claim client revenue, measured time savings, causal effects, or sole authorship without evidence.

## Contact

- Email: mkuderski21@gmail.com
- LinkedIn: https://www.linkedin.com/in/michal-kuderski-4b10a8230/
- GitHub: https://github.com/MichalKuderski

Original R Markdown source keeps its existing whitespace for provenance. The `.nojekyll` setting preserves its YAML headers in public downloads.
