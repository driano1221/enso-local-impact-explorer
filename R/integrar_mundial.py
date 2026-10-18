"""Prepara dados mundiais para consumo sob demanda, sem inferencia ou rede."""
from pathlib import Path
import hashlib
import json
import pandas as pd
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
WORLD = ROOT / 'dados/mundial'
OUT = WORLD / 'integracao'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def enrich(d, enso):
    d = d.copy()
    d['data'] = pd.to_datetime(d['data'])
    assert not d.duplicated(['id', 'fonte', 'data']).any()
    d['mes'] = d.data.dt.month
    base = d[d.data.dt.year.between(1991, 2020)]
    refs = base.groupby(['id','fonte','mes']).agg(
        temperatura_referencia_c=('temperatura_c','mean'),
        precipitacao_referencia_mm_mes=('precipitacao_mm_mes','mean'),
        n_temperatura=('temperatura_c','count'), n_chuva=('precipitacao_mm_mes','count')).reset_index()
    assert refs.n_temperatura.eq(30).all() and refs.n_chuva.eq(30).all()
    d = d.merge(refs, on=['id','fonte','mes'], validate='many_to_one')
    d['temperatura_anomalia_c'] = d.temperatura_c - d.temperatura_referencia_c
    d['precipitacao_anomalia_mm_mes'] = d.precipitacao_mm_mes - d.precipitacao_referencia_mm_mes
    d = d.merge(enso, on='data', how='left', validate='many_to_one')
    assert not d[['ONI','RONI']].isna().any().any()
    return d.sort_values(['fonte','data']).drop(columns=['n_temperatura','n_chuva'])

def main():
    cat = pd.read_csv(WORLD/'catalogo.csv', keep_default_na=False)
    cat = cat[cat.status.eq('aprovado_fonte')].copy()
    assert not cat.id.duplicated().any()
    enso = pd.read_csv(ROOT/'dados/enso.csv', parse_dates=['data_central'])
    assert not enso.duplicated(['data_central','indice']).any()
    indices = enso.pivot(index='data_central',columns='indice',values='valor').reset_index().rename(columns={'data_central':'data'})
    coverage = pd.concat([pd.read_csv(WORLD/f'cobertura_{f}.csv',keep_default_na=False) for f in ['power','era5']],ignore_index=True)
    assert not coverage.duplicated(['id','fonte']).any()
    coverage = coverage[coverage.id.isin(cat.id) & coverage.status.eq('completo')]
    assert set(coverage[coverage.fonte.eq('POWER')].id) == set(cat.id)
    OUT.mkdir(exist_ok=True)
    (OUT/'pontos').mkdir(exist_ok=True)
    entries, provenance, inputs = [], [], {}
    expected = pd.date_range('1981-01-01','2025-12-01',freq='MS')
    for city in cat.itertuples():
        frames = []
        available = coverage[coverage.id.eq(city.id)]
        for row in available.itertuples():
            path = WORLD/'mensal'/f'{row.fonte.lower()}_{city.id}.csv'
            data = pd.read_csv(path,parse_dates=['data'])
            assert list(data.data) == list(expected) and data.id.eq(city.id).all() and data.fonte.eq(row.fonte).all()
            assert np.isfinite(data[['temperatura_c','precipitacao_mm_mes']]).all().all()
            inputs[path.relative_to(ROOT).as_posix()] = sha(path)
            frames.append(data)
            provenance.append(dict(id=city.id,fonte=row.fonte,url=row.url,sha256_original=row.sha256,
                                   sha256_mensal=inputs[path.relative_to(ROOT).as_posix()],
                                   calendario='LST' if row.fonte=='POWER' else 'UTC',
                                   status='exploratorio; sem validacao observacional mundial'))
        result = enrich(pd.concat(frames,ignore_index=True), indices)
        path = OUT/'pontos'/f'{city.id}.csv'
        temp = path.with_suffix('.tmp')
        result.to_csv(temp,index=False,date_format='%Y-%m-%d')
        temp.replace(path)
        entries.append(dict(id=city.id,cidade=city.cidade,pais=city.pais,pais_iso2=city.pais_iso2,
                            latitude=city.latitude,longitude=city.longitude,
                            fontes='|'.join(sorted(available.fonte)),era5_disponivel='ERA5' in set(available.fonte),
                            registros=len(result),arquivo=f'pontos/{city.id}.csv',sha256=sha(path),
                            inferencia_disponivel=False))
    pd.DataFrame(entries).to_csv(OUT/'pontos.csv',index=False)
    pd.DataFrame(provenance).to_csv(OUT/'fontes.csv',index=False)
    inputs.update({p.relative_to(ROOT).as_posix():sha(p) for p in [WORLD/'catalogo.csv',ROOT/'dados/enso.csv',WORLD/'cobertura_power.csv',WORLD/'cobertura_era5.csv']})
    manifest = dict(pontos=len(entries),fontes_ponto=len(provenance),registros=sum(e['registros'] for e in entries),
                    referencia='1991-2020 por fonte/ponto/mes; 30 observacoes obrigatorias',
                    periodo='1981-2025',indices='ONI/RONI centrados; retrospectivo, nao previsao',
                    limite='POWER LST e ERA5 UTC; nao substituir snapshots locais do piloto; sem modelos mundiais',
                    entradas_sha256=inputs,
                    saidas_sha256={n:sha(OUT/n) for n in ['pontos.csv','fontes.csv']})
    (OUT/'manifesto.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in manifest.items() if not k.endswith('sha256')},ensure_ascii=False))

if __name__ == '__main__':
    main()
