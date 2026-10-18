"""Build the English preview from approved sources; never edit the Portuguese app.

Edit idiomas/en*.tsv, not generated files in prototipo_mundial_en.
The build changes presentation strings and export labels, never climate calculations.
"""
from pathlib import Path
import hashlib, json, re, shutil

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'prototipo_mundial_en'

def dictionary(name):
    rows = [line.split('\t', 1) for line in (ROOT/'idiomas'/name).read_text(encoding='utf-8').splitlines() if line]
    assert all(len(row) == 2 for row in rows)
    assert len({row[0] for row in rows}) == len(rows), 'Duplicate translation'
    return dict(rows)

def main():
    words, assets = dictionary('en.tsv'), dictionary('en-assets.tsv')
    source = ROOT/'prototipo_mundial'
    before = {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
              for folder in ['prototipo_mundial', 'prototipo_revisado']
              for p in (ROOT/folder).rglob('*') if p.is_file()}
    OUT.mkdir(exist_ok=True)
    shutil.copytree(source/'www', OUT/'www', dirs_exist_ok=True)
    shutil.copytree(ROOT/'prototipo_revisado/www', OUT/'www/aprovado-en', dirs_exist_ok=True)
    # Exact R string literals only: identifiers, numeric values and formulas stay unchanged.
    def translate_r(text):
        def replace(m):
            raw=m.group(0); key=raw[1:-1]
            return json.dumps(words[key], ensure_ascii=False) if key in words else raw
        return re.sub(r'"(?:\\.|[^"\\])*"', replace, text)
    for name in ['app.R','layout.R']:
        text=translate_r((source/name).read_text(encoding='utf-8'))
        if name=='app.R':
            text=text.replace('source("../prototipo_revisado/comparacao.R",', 'source("comparacao_en.R",')
            text=text.replace('normalizePath("../prototipo_revisado/www")', 'normalizePath("www/aprovado-en")')
            text=text.replace('nomes_paises <- jsonlite::fromJSON("paises-pt.json")','nomes_paises <- list()')
            text=text.replace('decimal.mark=","','decimal.mark="."')
            text=text.replace('tolower(rotulos_estacao[[input$estacao]])','rotulos_estacao[[input$estacao]]')
            text=text.replace('source("layout.R",', 'source("../idiomas/exports_en.R", encoding="UTF-8", local=TRUE)\nsource("layout.R",')
        (OUT/name).write_text(text,encoding='utf-8')
    comparison=translate_r((ROOT/'prototipo_revisado/comparacao.R').read_text(encoding='utf-8'))
    # Only the plot helper is needed; avoid copying unused pilot logic into this build.
    comparison=comparison[comparison.index('grafico_fontes <-'):comparison.index('\nrespostas_locais <-')]
    comparison=comparison.replace('separators = ",."','separators = ".,"')
    comparison=comparison.replace('Histórico de POWER e ERA5 nos mesmos anos. Valores e referências disponíveis ao tocar nas linhas e no CSV.', 'Historical POWER and ERA5 records for the same years. Values and references are available on the lines and in the CSV.')
    (OUT/'comparacao_en.R').write_text(comparison,encoding='utf-8')
    pattern=re.compile('|'.join(re.escape(k) for k in sorted(assets,key=len,reverse=True)))
    files=['consulta-diagrama.html','enso.html','mundial.js','globo.js',
           'aprovado-en/pacifico.js','aprovado-en/pacifico-model.js','aprovado-en/terra.js','aprovado-en/atlas.js']
    for name in files:
        path=OUT/'www'/name; text=path.read_text(encoding='utf-8')
        text=pattern.sub(lambda m: assets[m[0]].replace("'", "\\'") if path.suffix=='.js' else assets[m[0]],text)
        if name=='aprovado-en/atlas.js':
            text=text.replace("'temperatura'", "'temperature'").replace("'chuva'", "'rainfall'")
        path.write_text(text,encoding='utf-8')
    after={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in before}
    assert before==after, 'Approved source files changed during build'
    manifest={'source_sha256':before,'translation_sha256':{name:hashlib.sha256((ROOT/'idiomas'/name).read_bytes()).hexdigest() for name in ['en.tsv','en-assets.tsv','exports_en.R']},'output':'prototipo_mundial_en','source_files_preserved':len(before)}
    (OUT/'build.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    print(f'English build ready; {len(before)} approved source files preserved.')

if __name__=='__main__': main()
