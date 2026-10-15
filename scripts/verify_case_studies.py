"""Check the multipage portfolio and reconcile its retail claims to saved outputs."""
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit, unquote
from xml.etree import ElementTree as ET
from zipfile import ZipFile
import csv
import json

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
    audit=json.loads((ROOT/'assets/projects/quantium/validation.json').read_text())
    case=(ROOT/'projects/quantium.html').read_text()
    home=(ROOT/'index.html').read_text()
    assert audit['source_rows']-audit['exact_duplicate_rows_removed']-audit['outlier_customer_rows_removed']==audit['cleaned_line_items']
    assert '264,833' in case and '263,125' in case
    for r in audit['results']:
        for number in ['sales_actual','sales_expected','sales_gap']:
            assert f"${r[number]:,.2f}" in case, (number,r)
        for number in ['sales_gap_pct','customers_gap_pct']:
            assert f"{r[number]:.1f}%" in case, (number,r)
        assert f"{r['sales_gap_pct']:.1f}%" in home
    with (ROOT/'assets/projects/quantium/matched-monthly-series.csv').open() as handle:
        rows=list(csv.DictReader(handle))
    assert len(rows)==36
    for r in audit['results']:
        sub=[x for x in rows if int(x['trial'])==r['trial']]
        trial=[x for x in sub if x['period']=='Trial']
        assert len(sub)==12 and len(trial)==3
        for metric in ['sales','customers']:
            assert abs(sum(float(x[metric+'_actual']) for x in trial)-r[metric+'_actual'])<1e-6
            assert abs(sum(float(x[metric+'_scaled_control']) for x in trial)-r[metric+'_expected'])<1e-6
    for path in (ROOT/'assets/projects/quantium').glob('*.svg'):
        svg=ET.parse(path).getroot()
        assert svg.tag.endswith('svg') and not any(e.tag.endswith('script') for e in svg.iter())
    print('PASS: displayed retail claims, chart values, trial dates, cleaning reconciliation, and SVG structure')
    with ZipFile(ROOT/'assets/projects/dreams/Capstone_Paper.docx') as z:
        for i,name in enumerate(['themes','pronouns','irr','diagnostics'],1):
            assert z.read(f'word/media/image{i}.png')==(ROOT/f'assets/projects/dreams/{name}-original.png').read_bytes()
    with ZipFile(ROOT/'assets/projects/quantium/original-chart-exports.zip') as z:
        assert len(z.namelist())==7 and all(x.endswith('.png') for x in z.namelist())
    print('PASS: four capstone figures match the source paper exactly; seven original retail chart exports retained')
    order=[home.index(f'id="project-{name}"') for name in ['medicare','retail','dreams','automation']]
    assert order==sorted(order)
    assert home.index('id="project-student"')>home.index('id="additional-title"')
    print('PASS: featured project priority and further-work placement')


if __name__=='__main__': main()
