"""Check portfolio structure and reconcile displayed figures with source evidence."""
from collections import defaultdict
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit, unquote
from xml.etree import ElementTree as ET
from zipfile import ZipFile
import json
import re

ROOT = Path(__file__).resolve().parents[1]


class Page(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.ids = []; self.refs = []; self.code = {}; self.code_id = None
        self.h1s = 0; self.json_ld = ''; self.in_json = False
        self.buttons = []; self.alts = []; self.downloads = []

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if a.get('id'): self.ids.append(a['id'])
        if tag == 'h1': self.h1s += 1
        for field in ('src', 'href'):
            if a.get(field): self.refs.append(a[field])
        if tag == 'a' and a.get('target') == '_blank':
            assert 'noopener' in a.get('rel', '').split(), a
        if tag == 'a' and 'download' in a: self.downloads.append(a['href'])
        if tag == 'img': self.alts.append(a.get('alt'))
        if tag == 'button': self.buttons.append(a)
        if tag == 'code' and a.get('id'):
            self.code_id = a['id']; self.code[self.code_id] = ''
        if tag == 'script' and a.get('type') == 'application/ld+json': self.in_json = True

    def handle_data(self, data):
        if self.code_id: self.code[self.code_id] += data
        if self.in_json: self.json_ld += data

    def handle_endtag(self, tag):
        if tag == 'code': self.code_id = None
        if tag == 'script': self.in_json = False


def workbook_rows(sheet_number):
    ns = {'s': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
    with ZipFile(ROOT / 'Medicare_Psychiatry_Analytics_IL_2023.xlsx') as archive:
        shared = []
        if 'xl/sharedStrings.xml' in archive.namelist():
            shared = [''.join(x.itertext()) for x in ET.fromstring(archive.read('xl/sharedStrings.xml'))]
        sheet = ET.fromstring(archive.read(f'xl/worksheets/sheet{sheet_number}.xml'))
        rows = []
        for row in sheet.findall('.//s:sheetData/s:row', ns):
            values = {}
            for cell in row:
                v = cell.find('s:v', ns); inline = cell.find('s:is', ns)
                value = v.text if v is not None else ''.join(inline.itertext()) if inline is not None else ''
                if cell.get('t') == 's': value = shared[int(value)]
                column = ''.join(filter(str.isalpha, cell.get('r')))
                values[column] = value
            rows.append(values)
        return rows


def luminance(color):
    channels = [int(color[i:i+2], 16) / 255 for i in (1, 3, 5)]
    linear = [c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4 for c in channels]
    return sum(c * w for c, w in zip(linear, (.2126, .7152, .0722)))


def contrast(a, b):
    x, y = sorted([luminance(a), luminance(b)], reverse=True)
    return (x + .05) / (y + .05)


def main():
    source = (ROOT / 'index.html').read_text()
    page = Page(); page.feed(source)
    assert page.h1s == 1, 'Use one clear primary heading'
    assert len(page.ids) == len(set(page.ids)), 'Duplicate element IDs'
    assert all(page.alts), 'Images need descriptive alt text'
    for ref in page.refs:
        parsed = urlsplit(ref)
        if parsed.scheme or parsed.netloc: continue
        if parsed.path:
            assert (ROOT / unquote(parsed.path)).is_file(), f'Missing local asset: {ref}'
        if parsed.fragment and not parsed.path:
            assert parsed.fragment in page.ids, f'Missing anchor: {ref}'
    json.loads(page.json_ld)
    assert not re.search(r'__[A-Z_]+__', source), 'Unresolved template token'
    for button in page.buttons:
        if 'data-copy' in button:
            assert button['data-copy'] in page.code and button.get('aria-label')
        if 'data-wrap' in button:
            assert button['data-wrap'] in page.ids and button.get('aria-pressed') == 'false'
    sql = (ROOT / 'medicare_analytics.sql').read_text()
    for key, code in page.code.items():
        assert code.strip() in sql, f'{key} differs from downloadable SQL'
    assert re.findall(r'-- QUERY (3\.\d)', sql) == [f'3.{i}' for i in range(1, 7)]
    print(f'HTML/assets: PASS ({len(page.ids)} unique IDs; {len(page.code)} source-matched SQL examples)')

    css = (ROOT / 'css/portfolio.css').read_text()
    screen_css = css.split('@media print', 1)[0]
    code_bg = re.search(r'--code:(#[0-9a-f]{6})', css).group(1)
    base_fg = re.search(r'\.sql-example code\{[^}]*color:(#[0-9a-f]{6})', screen_css).group(1)
    for kind, fg in [('base', base_fg), *re.findall(r'\.sql-example \.sql-(\w+)\{color:(#[0-9a-f]{6})', screen_css)]:
        ratio = contrast(fg, code_bg)
        assert ratio >= 4.5, f'{kind} code contrast only {ratio:.2f}:1'
        print(f'SQL {kind} contrast: PASS ({ratio:.2f}:1)')

    print_css = css[css.rfind('@media print'):]
    print_fg = re.search(r'\.sql-example code\{[^}]*color:(#[0-9a-f]{6})', print_css)
    if print_fg:
        for kind, fg in [('base', print_fg.group(1)), *re.findall(r'\.sql-example \.sql-(\w+)\{color:(#[0-9a-f]{6})', print_css)]:
            ratio = contrast(fg, '#ffffff')
            assert ratio >= 4.5, f'{kind} print contrast only {ratio:.2f}:1'
        print('Printed SQL contrast: PASS (text and all syntax colors on white)')

    summary = workbook_rows(2)[2]
    total_payment = float(summary['I']); units = float(summary['F'])
    assert round(total_payment / units, 2) == float(summary['K'])
    for val in [f'{units:,.0f}', f'${total_payment:,.2f}', f"${float(summary['G']):,.2f}", f"${float(summary['H']):,.2f}", f'${total_payment / units:.2f}']:
        assert val in source, f'Displayed summary differs from workbook: {val}'
    top = workbook_rows(3)[2:7]
    concentration = 100 * sum(float(row['H']) for row in top) / total_payment
    assert f'{concentration:.1f}%' in source
    for row in top:
        assert f"${float(row['H']):,.2f}" in source
    print(f'Workbook summary/payment concentration: PASS ({concentration:.1f}%)')

    cities = defaultdict(lambda: [0, 0])
    for row in workbook_rows(4)[2:]:
        cities[row['F']][0] += 1; cities[row['F']][1] += float(row['L'])
    selected = {'Elk Grove Village', 'Dekalb', 'Chicago', 'Morris', 'Pekin', 'Plainfield'}
    for row in workbook_rows(6)[2:]:
        if row['B'] not in selected: continue
        count, denominator = cities[row['B']]
        phone = float(row['D']); pct = round(100 * phone / denominator, 1)
        assert pct == float(row['F']), f"City denominator mismatch: {row['B']}"
        assert f'{pct}%' in source
        city = 'DeKalb' if row['B'] == 'Dekalb' else row['B']
        expected = f'<tr><th scope="row">{city}</th><td class="num">{count}</td><td class="num">{row["C"]}</td><td class="num">{phone:,.0f}</td><td class="num">{denominator:,.0f}</td><td class="num">{pct}%</td></tr>'
        assert expected in source, f'{city} table differs from workbook'
    print('Telephone shares/provider counts/denominators: PASS (six cities)')

    try:
        from pglast import parse_sql
    except ImportError:
        print('SQL syntax parsing: SKIPPED (optional pglast not installed)')
    else:
        count = len(parse_sql(sql))
        for snippet in page.code.values(): parse_sql(snippet)
        print(f'PostgreSQL syntax: PASS ({count} statements plus all displayed examples; not executed)')


if __name__ == '__main__':
    main()
