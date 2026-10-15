"""Reconcile recovered Task 1 outputs and build aggregate-only portfolio evidence.

Usage: python scripts/review_quantium.py TRANSACTIONS.csv CUSTOMERS.csv
The original R outputs are reconciled separately from the deduplicated snapshot.
No customer identifiers or transaction rows are exported.
"""
from pathlib import Path
import hashlib
import importlib.util
import json
import sys
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/projects/quantium'


def aggregate(data):
    result = data.groupby(['LIFESTAGE', 'PREMIUM_CUSTOMER']).agg(
        sales=('TOT_SALES', 'sum'), customers=('LYLTY_CARD_NBR', 'nunique'),
        units=('PROD_QTY', 'sum'), product_line_items=('TOT_SALES', 'size')
    ).reset_index().sort_values(['sales', 'LIFESTAGE', 'PREMIUM_CUSTOMER'], ascending=[False, True, True])
    result['sales_share_pct'] = 100 * result.sales / result.sales.sum()
    result['customer_share_pct'] = 100 * result.customers / data.LYLTY_CARD_NBR.nunique()
    result['units_per_customer'] = result.units / result.customers
    result['sales_per_unit'] = result.sales / result.units
    return result


def main():
    transactions_path, customers_path = map(Path, sys.argv[1:3])
    t = pd.read_csv(transactions_path); customers = pd.read_csv(customers_path)
    assert customers.LYLTY_CARD_NBR.is_unique and not customers.isna().any().any()
    assert not t.isna().any().any()
    salsa = t.PROD_NAME.str.contains('salsa', case=False)
    chips = t[~salsa].copy()
    bulk = chips.loc[chips.PROD_QTY == 200, 'LYLTY_CARD_NBR'].unique()
    historical = chips[~chips.LYLTY_CARD_NBR.isin(bulk)].copy()
    clean = historical.drop_duplicates().copy()
    historical = historical.merge(customers, on='LYLTY_CARD_NBR', how='left', validate='many_to_one')
    clean = clean.merge(customers, on='LYLTY_CARD_NBR', how='left', validate='many_to_one')
    assert not historical.LIFESTAGE.isna().any() and not clean.LIFESTAGE.isna().any()
    observed = aggregate(historical); revised = aggregate(clean)
    # Values printed in Quantium-Code.pdf, page 17. Row-level samples stay private.
    pdf_top3 = [('OLDER FAMILIES','Budget',156863.75),
                ('YOUNG SINGLES/COUPLES','Mainstream',147582.20),
                ('RETIREES','Mainstream',145168.95)]
    for actual, expected in zip(observed.itertuples(), pdf_top3):
        assert (actual.LIFESTAGE,actual.PREMIUM_CUSTOMER)==expected[:2]
        assert abs(actual.sales-expected[2])<1e-8
    assert len(historical)==246740 and abs(historical.TOT_SALES.sum()-1805177.70)<1e-7
    assert len(clean)==246739 and abs(clean.TOT_SALES.sum()-1805171.70)<1e-7
    assert clean.LYLTY_CARD_NBR.nunique()==71287
    assert len(revised)==21 and abs(revised.sales_share_pct.sum()-100)<1e-8
    assert abs(revised.customer_share_pct.sum()-100)<1e-8
    assert abs(revised.units.sum()-clean.PROD_QTY.sum())<1e-8
    assert len(clean)==len(chips[~chips.LYLTY_CARD_NBR.isin(bulk)].drop_duplicates())
    observed.to_csv(OUT/'task1-historical-segments.csv',index=False,float_format='%.10f')
    revised.to_csv(OUT/'segment-results.csv',index=False,float_format='%.10f')
    clean['month'] = pd.to_datetime(clean.DATE,unit='D',origin='1899-12-30').dt.strftime('%Y-%m')
    spec = importlib.util.spec_from_file_location('trial', ROOT/'scripts/verify_quantium.py')
    trial = importlib.util.module_from_spec(spec); spec.loader.exec_module(trial)
    monthly = trial.summarize(clean)
    results, rankings, series, eligible = trial.compare(monthly)
    pd.DataFrame(results).to_csv(OUT/'chips-trial-results.csv',index=False,float_format='%.10f')
    pd.DataFrame(rankings).to_csv(OUT/'chips-control-rankings.csv',index=False,float_format='%.10f')
    pd.DataFrame(series).to_csv(OUT/'chips-matched-monthly-series.csv',index=False,float_format='%.10f')
    monthly.to_csv(OUT/'chips-monthly-store-metrics.csv',index=False,float_format='%.10f')
    audit = dict(source_commit='87efe6c29ea423acb4184d5eaf2b83275bcb10d8',
        transactions_sha256=hashlib.sha256(transactions_path.read_bytes()).hexdigest(),
        customers_sha256=hashlib.sha256(customers_path.read_bytes()).hexdigest(),
        raw_line_items=len(t), salsa_line_items_removed=int(salsa.sum()),
        bulk_customer_count=len(bulk), bulk_line_items_removed=len(chips)-len(historical),
        historical_task1_line_items=len(historical), historical_task1_sales=float(historical.TOT_SALES.sum()),
        exact_duplicate_rows_removed=len(historical)-len(clean), clean_chip_line_items=len(clean),
        clean_chip_sales=float(clean.TOT_SALES.sum()), distinct_customers=int(clean.LYLTY_CARD_NBR.nunique()),
        segments=len(revised), customer_key_unique=True, unmatched_customer_rows=0, join_row_inflation=0,
        top3_pdf_amounts_reconciled=True, top3_sales_share_pct=float(revised.sales_share_pct.head(3).sum()),
        chip_scope_revised_controls=[r['control'] for r in results], balanced_chip_stores=eligible,
        original_task2_controls_reported=[50,114,123], original_task2_summary_controls=[None,None,123],
        original_trial_effects='UNVERIFIED: no defensible original uplift estimates or significance outputs',
        reconstructed_comparisons='Reproduced diagnostic point estimates under revised matching; not historical trial effects',
        publication='Aggregate outputs only; Task 1 PDF contains customer identifiers. Original Quantium PDFs are not republished.')
    (OUT/'task1-validation.json').write_text(json.dumps(audit,indent=2)+'\n')
    plt.rcParams.update({'font.family':'DejaVu Sans','font.size':10,'svg.fonttype':'none',
                         'axes.spines.top':False,'axes.spines.right':False})
    top=revised.head(5)
    fig,ax=plt.subplots(figsize=(11.5,5.7))
    labels=[r.LIFESTAGE.title()+' / '+r.PREMIUM_CUSTOMER for r in top.itertuples()]
    ax.barh(range(5),top.sales,color='#0e6b5c',height=.56)
    ax.set_yticks(range(5),labels);ax.invert_yaxis();ax.set_xlim(0,190000)
    ax.set_xticks([0,50000,100000,150000],['0','50,000','100,000','150,000'])
    ax.set_xlabel('Chip sales (dataset dollars)');ax.grid(axis='x',color='#e2e7e3');ax.set_axisbelow(True)
    for i,r in enumerate(top.itertuples()):ax.text(r.sales+2300,i,f'${r.sales:,.0f}  ·  {r.sales_share_pct:.1f}%',va='center',fontsize=10)
    fig.suptitle('Chip sales by customer segment: five largest segments',x=.36,y=.97,ha='left',fontsize=15,weight='bold')
    fig.text(.36,.90,'July 2018–June 2019 · salsa and bulk buyer removed · one duplicate removed',fontsize=9)
    fig.text(.02,.025,'Source: repository CSVs, commit 87efe6c. Top three sales amounts match Task 1 PDF p.17. Descriptive sales, not profit or causal impact.',fontsize=9)
    fig.subplots_adjust(left=.36,right=.96,top=.82,bottom=.16)
    fig.savefig(OUT/'segment-sales.svg');fig.savefig(ROOT.parent/'review-20261015/segment-sales.png',dpi=110);plt.close(fig)
    print(json.dumps(audit,indent=2))


if __name__=='__main__': main()
