"""Reconstruct the retail snapshot independently of the original R Markdown.

Usage: python scripts/verify_quantium.py /path/to/QVI_transaction_data.csv
Dependencies: pandas, numpy, matplotlib. No customer-level data is exported.
The accompanying quantium_reanalysis.R implements the same revised method in R.
"""
from pathlib import Path
from collections import defaultdict
import csv
import hashlib
import json
import sys
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.ticker import StrMethodFormatter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/projects/quantium'
TRIALS = [77, 86, 88]


def summarize(frame):
    return frame.groupby(['STORE_NBR', 'month']).agg(
        sales=('TOT_SALES', 'sum'), customers=('LYLTY_CARD_NBR', 'nunique'),
        transactions=('TXN_ID', 'nunique'), units=('PROD_QTY', 'sum')
    ).reset_index().sort_values(['STORE_NBR', 'month'])


def compare(monthly):
    eligible = monthly.groupby('STORE_NBR').size().loc[lambda s: s == 12].index
    pre = monthly[(monthly.month < '2019-02') & monthly.STORE_NBR.isin(eligible)]
    candidates = [int(i) for i in eligible if i not in TRIALS]
    results, rankings, series = [], [], []
    for trial in TRIALS:
        scores = pd.DataFrame(index=candidates)
        for metric in ['sales', 'customers']:
            wide = pre.pivot(index='month', columns='STORE_NBR', values=metric)
            distances = wide[candidates].subtract(wide[trial], axis=0).abs()
            span = distances.max(axis=1) - distances.min(axis=1)
            magnitude = 1 - distances.sub(distances.min(axis=1), axis=0).div(span.replace(0, np.nan), axis=0)
            magnitude.loc[span == 0] = 1
            scores[metric + '_correlation'] = wide[candidates].corrwith(wide[trial]).fillna(0)
            scores[metric + '_magnitude'] = magnitude.mean()
        scores['score'] = scores.mean(axis=1)
        scores.index.name = 'control'
        scores = scores.reset_index().sort_values(['score', 'control'], ascending=[False, True])
        control = int(scores.iloc[0].control)
        rankings.extend(dict(trial=trial, rank=i+1, **row) for i, row in enumerate(scores.to_dict('records')))
        row = dict(trial=trial, control=control, score=float(scores.iloc[0].score))
        both = monthly[monthly.STORE_NBR.isin([trial, control])].pivot(index='month', columns='STORE_NBR')
        for metric in ['sales', 'customers']:
            scale = both.loc[both.index < '2019-02', (metric, trial)].sum() / both.loc[both.index < '2019-02', (metric, control)].sum()
            actual = both.loc[(both.index >= '2019-02') & (both.index <= '2019-04'), (metric, trial)].sum()
            expected = both.loc[(both.index >= '2019-02') & (both.index <= '2019-04'), (metric, control)].sum() * scale
            row.update({metric + '_scale': float(scale), metric + '_actual': float(actual),
                        metric + '_expected': float(expected), metric + '_gap': float(actual - expected),
                        metric + '_gap_pct': float((actual / expected - 1) * 100)})
        row['spend_per_customer_gap_pct'] = float(((row['sales_actual']/row['customers_actual']) / (row['sales_expected']/row['customers_expected']) - 1) * 100)
        results.append(row)
        for month in both.index:
            record = dict(trial=trial, control=control, month=month,
                          period='Pre-trial' if month < '2019-02' else 'Trial' if month <= '2019-04' else 'Follow-up')
            for metric in ['sales', 'customers']:
                record[metric + '_actual'] = float(both.loc[month, (metric, trial)])
                record[metric + '_scaled_control'] = float(both.loc[month, (metric, control)] * row[metric + '_scale'])
            series.append(record)
    return results, rankings, series, len(eligible)


def independent_csv_check(path, monthly):
    # Separate parser and integer-cent arithmetic check the pandas aggregation.
    seen, totals = set(), defaultdict(lambda: [0, set(), set(), 0])
    from datetime import datetime, timedelta
    from decimal import Decimal
    with path.open(newline='') as handle:
        bulk_customers = {r['LYLTY_CARD_NBR'] for r in csv.DictReader(handle) if int(r['PROD_QTY']) == 200}
    with path.open(newline='') as handle:
        for raw in csv.DictReader(handle):
            key = tuple(raw.values())
            if key in seen: continue
            seen.add(key)
            if raw['LYLTY_CARD_NBR'] in bulk_customers: continue
            month = (datetime(1899, 12, 30) + timedelta(days=int(raw['DATE']))).strftime('%Y-%m')
            bucket = totals[(int(raw['STORE_NBR']), month)]
            bucket[0] += int(Decimal(raw['TOT_SALES']) * 100)
            bucket[1].add(raw['LYLTY_CARD_NBR']); bucket[2].add(raw['TXN_ID'])
            bucket[3] += int(raw['PROD_QTY'])
    for r in monthly.itertuples():
        check = totals[(r.STORE_NBR, r.month)]
        assert round(r.sales * 100) == check[0]
        assert r.customers == len(check[1]) and r.transactions == len(check[2]) and r.units == check[3]
    assert len(totals) == len(monthly)


def charts(results, series):
    plt.rcParams.update({'font.family': 'DejaVu Sans', 'font.size': 10,
                         'axes.spines.top': False, 'axes.spines.right': False,
                         'axes.labelcolor': '#152823', 'text.color': '#152823',
                         'xtick.color': '#52645d', 'ytick.color': '#52645d',
                         'svg.fonttype': 'none'})
    actual_color, control_color = '#0e6b5c', '#59645f'
    for metric, label in [('sales', 'Sales (dataset dollars)'), ('customers', 'Monthly unique customers')]:
        fig, axes = plt.subplots(3, 1, figsize=(11.5, 9), sharex=True)
        fig.suptitle('Monthly ' + ('sales' if metric == 'sales' else 'customer counts') + ': trial and scaled control', x=.09, y=.985, ha='left', fontsize=16, weight='bold')
        fig.text(.09, .948, 'July 2018–June 2019 · grey area: February–April trial · scale fitted on July–January only', fontsize=10)
        for ax, result in zip(axes, results):
            rows = [r for r in series if r['trial'] == result['trial']]
            ax.axvspan(6.5, 9.5, color='#e8ece8', zorder=0)
            ax.plot(range(12), [r[metric+'_actual'] for r in rows], '-o', color=actual_color, markersize=4, linewidth=2, label=f"Trial {result['trial']}")
            ax.plot(range(12), [r[metric+'_scaled_control'] for r in rows], '--s', color=control_color, markersize=3.5, markerfacecolor='white', linewidth=1.6, label=f"Scaled control {result['control']}")
            ax.set_ylabel(label, fontsize=9); ax.set_ylim(bottom=0)
            ax.yaxis.set_major_formatter(StrMethodFormatter('{x:,.0f}'))
            ax.grid(axis='y', color='#e2e7e3', linewidth=.7); ax.set_axisbelow(True)
            ax.set_title(f"Store {result['trial']} · trial-period gap {result[metric+'_gap_pct']:+.1f}%", loc='left', fontsize=11)
            ax.legend(loc='lower right', bbox_to_anchor=(1, 1.015), frameon=False, ncol=2, fontsize=9)
        axes[-1].set_xticks(range(12), ['Jul 18','Aug','Sep','Oct','Nov','Dec','Jan 19','Feb','Mar','Apr','May','Jun'])
        fig.text(.09, .016, 'Descriptive matched-store reconstruction; no confidence intervals or causal effect claim. Source: repository CSV, 87efe6c.', fontsize=9)
        fig.subplots_adjust(left=.09, right=.98, top=.89, bottom=.075, hspace=.45)
        fig.savefig(OUT / (metric + '-monthly.svg')); plt.close(fig)
    fig, ax = plt.subplots(figsize=(10.5, 4.8))
    y = np.arange(3)
    ax.barh(y-.17, [r['sales_gap_pct'] for r in results], height=.29, color=actual_color, label='Sales')
    ax.barh(y+.17, [r['customers_gap_pct'] for r in results], height=.29, color='white', edgecolor=control_color, linewidth=1.5, label='Customer-month counts')
    for i,r in enumerate(results):
        for delta,key in [(-.17,'sales_gap_pct'),(.17,'customers_gap_pct')]:
            ax.text(r[key]+.4,i+delta,f"+{r[key]:.1f}%",va='center',fontsize=11)
    ax.set_yticks(y,[f"Trial {r['trial']} / control {r['control']}" for r in results]); ax.invert_yaxis()
    ax.set_xlim(0,32); ax.set_xlabel('Difference from pre-trial-scaled control (%)')
    ax.grid(axis='x',color='#e2e7e3'); ax.set_axisbelow(True)
    ax.legend(loc='lower right',frameon=False)
    fig.suptitle('Trial-period differences by matched store',x=.23,y=.98,ha='left',fontsize=16,weight='bold')
    fig.text(.23,.9,'February–April 2019 · customer counts sum monthly uniques; people may recur across months',fontsize=9)
    fig.text(.03,.02,'Point estimates only. These differences are observed comparisons, not validated causal uplift or realized revenue.',fontsize=9)
    fig.subplots_adjust(left=.23,right=.96,top=.82,bottom=.16)
    fig.savefig(OUT/'trial-comparison.svg'); plt.close(fig)


def main():
    path = Path(sys.argv[1]); OUT.mkdir(parents=True, exist_ok=True)
    raw = pd.read_csv(path)
    assert raw.columns.tolist() == ['DATE','STORE_NBR','LYLTY_CARD_NBR','TXN_ID','PROD_NBR','PROD_NAME','PROD_QTY','TOT_SALES']
    assert not raw.isna().any().any()
    deduped = raw.drop_duplicates()
    bulk_customers = deduped.loc[deduped.PROD_QTY == 200, 'LYLTY_CARD_NBR'].unique()
    clean = deduped[~deduped.LYLTY_CARD_NBR.isin(bulk_customers)].copy()
    clean['month'] = pd.to_datetime(clean.DATE, unit='D', origin='1899-12-30').dt.strftime('%Y-%m')
    assert sorted(clean.month.unique()) == pd.period_range('2018-07', '2019-06', freq='M').astype(str).tolist()
    monthly = summarize(clean)
    independent_csv_check(path, monthly)
    results, rankings, series, eligible = compare(monthly)
    chips = clean[~clean.PROD_NAME.str.contains('salsa', case=False)]
    sensitivity, _, _, _ = compare(summarize(chips))
    assert [r['control'] for r in results] == [233,155,237]
    # Independently verify the ranking maximum, scales, and trial totals with arrays.
    for r in results:
        for metric in ['sales','customers']:
            a = monthly[monthly.STORE_NBR == r['trial']].sort_values('month')[metric].to_numpy()
            c = monthly[monthly.STORE_NBR == r['control']].sort_values('month')[metric].to_numpy()
            scale = sum(a[:7])/sum(c[:7]); expected = sum(c[7:10])*scale
            assert np.isclose(r[metric+'_expected'], expected)
            assert np.isclose(r[metric+'_actual'], sum(a[7:10]))
    monthly.to_csv(OUT/'monthly-store-metrics.csv', index=False, float_format='%.10f')
    pd.DataFrame(results).to_csv(OUT/'trial-results.csv',index=False,float_format='%.10f')
    pd.DataFrame(rankings).to_csv(OUT/'control-rankings.csv',index=False,float_format='%.10f')
    pd.DataFrame(series).to_csv(OUT/'matched-monthly-series.csv',index=False,float_format='%.10f')
    pd.DataFrame(sensitivity).to_csv(OUT/'sensitivity-excluding-salsa.csv',index=False,float_format='%.10f')
    audit = dict(source_commit='87efe6c29ea423acb4184d5eaf2b83275bcb10d8',
                 source_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                 source_rows=len(raw), exact_duplicate_rows_removed=len(raw)-len(deduped),
                 outlier_customer_count=len(bulk_customers), outlier_customer_rows_removed=len(deduped)-len(clean),
                 cleaned_line_items=len(clean), distinct_store_transaction_keys=len(clean[['STORE_NBR','TXN_ID']].drop_duplicates()),
                 unique_customers=int(clean.LYLTY_CARD_NBR.nunique()), stores=int(clean.STORE_NBR.nunique()),
                 balanced_stores=eligible, pre_trial_months=7, trial_months=3,
                 cleaned_total_sales=float(clean.TOT_SALES.sum()),
                 independent_integer_cent_aggregation='PASS', results=results, sensitivity_excluding_salsa=sensitivity,
                 scope='Legacy all-product diagnostic, including salsa; retired as headline project evidence after Task 1 recovery.',
                 original_trial_effects='UNVERIFIED; this reconstruction does not validate the historical trial effects.',
                 inference='Descriptive point estimates; no validated significance or causal interpretation.',
                 executed='Python independent reconstruction; companion R code not executed in this environment.')
    (OUT/'validation.json').write_text(json.dumps(audit,indent=2)+'\n')
    charts(results,series)
    print(json.dumps(audit,indent=2))


if __name__ == '__main__': main()
