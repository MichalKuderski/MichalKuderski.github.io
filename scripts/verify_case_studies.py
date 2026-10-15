"""Check the multipage portfolio and reconcile its retail claims to saved outputs."""
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit, unquote
from xml.etree import ElementTree as ET
from zipfile import ZipFile
import csv
import json
import hashlib

ROOT = Path(__file__).resolve().parents[1]


class Document(HTMLParser):
    def __init__(self):
        super().__init__(); self.ids=[]; self.refs=[]; self.h1=0; self.alts=[]
    def handle_starttag(self, tag, attrs):
        a=dict(attrs)
        if a.get('id'): self.ids.append(a['id'])
        if tag=='h1': self.h1+=1
        for attr in ['src','href']:
            if a.get(attr): self.refs.append(a[attr])
        if tag=='a' and a.get('target')=='_blank': assert 'noopener' in a.get('rel','').split()
        if tag=='img':
            self.alts.append(a.get('alt')); assert a.get('width') and a.get('height')


def main():
    pages={}
    for path in ROOT.rglob('*.html'):
        doc=Document(); doc.feed(path.read_text())
        assert doc.h1==1, path
        assert len(doc.ids)==len(set(doc.ids)), path
        assert all(doc.alts), path
        pages[path.resolve()]=doc
    for path,doc in pages.items():
        for ref in doc.refs:
            parsed=urlsplit(ref)
            if parsed.scheme or parsed.netloc: continue
            target=(path.parent/unquote(parsed.path)).resolve() if parsed.path else path
            assert target.is_relative_to(ROOT), f'Path leaves site: {ref}'
            assert target.is_file(), f'Broken asset: {path}: {ref}'
            if parsed.fragment and target in pages:
                assert unquote(parsed.fragment) in pages[target].ids, f'Broken anchor: {ref}'
    print(f'PASS: {len(pages)} pages, all relative assets and cross-page anchors, image alt/dimensions, external-link attributes')
    audit=json.loads((ROOT/'assets/projects/quantium/task1-validation.json').read_text())
    case=(ROOT/'projects/quantium.html').read_text()
    home=(ROOT/'index.html').read_text()
    assert audit['historical_task1_line_items']-audit['exact_duplicate_rows_removed']==audit['clean_chip_line_items']
    assert audit['clean_chip_line_items']==246739 and audit['unmatched_customer_rows']==0 and audit['join_row_inflation']==0
    assert '246,739' in case and '71,287' in case
    with (ROOT/'assets/projects/quantium/segment-results.csv').open() as handle: segments=list(csv.DictReader(handle))
    assert len(segments)==21
    assert abs(sum(float(r['sales']) for r in segments)-audit['clean_chip_sales'])<1e-6
    assert abs(sum(float(r['sales_share_pct']) for r in segments)-100)<1e-6
    for r in segments[:5]:
        assert f"${float(r['sales']):,.2f}" in case
        assert f"{float(r['sales_share_pct']):.2f}%" in case
    with (ROOT/'assets/projects/quantium/chips-trial-results.csv').open() as handle: results=list(csv.DictReader(handle))
    for r in results:
        assert f"${float(r['sales_actual']):,.2f}" in case
        assert f"${float(r['sales_expected']):,.2f}" in case
        assert f"{float(r['sales_gap_pct']):+.1f}%" in case
    assert not any(x in home for x in ['26.2%', '13.2%', '12.1%'])
    with (ROOT/'assets/projects/quantium/chips-matched-monthly-series.csv').open() as handle:
        rows=list(csv.DictReader(handle))
    assert len(rows)==36
    for r in results:
        sub=[x for x in rows if int(x['trial'])==int(r['trial'])]
        trial=[x for x in sub if x['period']=='Trial']
        assert len(sub)==12 and len(trial)==3
        for metric in ['sales','customers']:
            assert abs(sum(float(x[metric+'_actual']) for x in trial)-float(r[metric+'_actual']))<1e-6
            assert abs(sum(float(x[metric+'_scaled_control']) for x in trial)-float(r[metric+'_expected']))<1e-6
    for path in (ROOT/'assets/projects/quantium').glob('*.svg'):
        svg=ET.parse(path).getroot()
        assert svg.tag.endswith('svg') and not any(e.tag.endswith('script') for e in svg.iter())
    print('PASS: reconciled segment claims, separately labeled chip diagnostics, dates, cleaning counts, and SVG structure')
    with ZipFile(ROOT/'assets/projects/dreams/Capstone_Paper.docx') as z:
        for i,name in enumerate(['themes','pronouns','irr','diagnostics'],1):
            assert z.read(f'word/media/image{i}.png')==(ROOT/f'assets/projects/dreams/{name}-original.png').read_bytes()
    with ZipFile(ROOT/'assets/projects/quantium/original-chart-exports.zip') as z:
        assert len(z.namelist())==7 and all(x.endswith('.png') for x in z.namelist())
    dreams=(ROOT/'projects/dreaming.html').read_text()
    assert dreams.count('SIMULATION-ASSOCIATED ILLUSTRATION')==4
    assert 'empirical cultural findings remain unverified' in dreams
    assert 'greater relative first-person language in the American sample' not in home
    sim=(ROOT/'assets/projects/dreams/simulation_source_original.Rmd').read_text()
    assert 'rpois(1600' in sim and 'lda_mock' in sim and 'runif(' in sim
    inventory=json.loads((ROOT/'assets/projects/source-review.json').read_text())
    indexed={r['filename']:r for r in inventory['files']}
    for recovered,public in [('Honors SCP.Rmd','dreams/Updated_Code_original.Rmd'),('Complete_Quantium_code(1).Rmd','quantium/Complete_Quantium_code_original.Rmd')]:
        assert indexed[recovered]['sha256']==hashlib.sha256((ROOT/'assets/projects'/public).read_bytes()).hexdigest()
    assert not list(ROOT.rglob('Quantium-Code.pdf')) and not list(ROOT.rglob('Complete R Code #2.pdf'))
    print('PASS: CURE figures retain source identity with simulation labels; duplicates verified; private Quantium PDFs excluded')
    order=[home.index(f'id="project-{name}"') for name in ['medicare','retail','dreams','automation']]
    assert order==sorted(order)
    assert home.index('id="project-student"')>home.index('id="additional-title"')
    print('PASS: featured project priority and further-work placement')


if __name__=='__main__': main()
