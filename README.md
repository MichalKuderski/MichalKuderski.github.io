# Michal Kuderski — Data Analyst Portfolio

Live site: https://michalkuderski.github.io/

A static portfolio presenting spending analysis, retail trials, reporting automation, statistical research, classification, and ANOVA simulation. Built with semantic HTML, responsive CSS, and optional JavaScript. No external fonts, analytics trackers, package install, build step, or server runtime is required.

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
