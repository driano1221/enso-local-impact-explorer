"""Confere joins, referencia, cobertura e preservacao dos valores mensais."""
from pathlib import Path
import hashlib,json
import numpy as np
import pandas as pd
from integrar_mundial import enrich

ROOT=Path(__file__).resolve().parents[1]
WORLD=ROOT/'dados/mundial'
OUT=WORLD/'integracao'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

manifest=json.loads((OUT/'manifesto.json').read_text(encoding='utf-8'))
for path,expected in manifest['entradas_sha256'].items():assert sha(ROOT/path)==expected,path
for path,expected in manifest['saidas_sha256'].items():assert sha(OUT/path)==expected,path
cat=pd.read_csv(WORLD/'catalogo.csv',keep_default_na=False)
points=pd.read_csv(OUT/'pontos.csv',keep_default_na=False)
assert set(points.id)==set(cat.loc[cat.status.eq('aprovado_fonte'),'id'])
assert 'NA' in set(points.pais_iso2)
assert not points.inferencia_disponivel.any()
era5=pd.read_csv(WORLD/'cobertura_era5.csv',keep_default_na=False)
expected_era5=set(era5.loc[era5.status.eq('completo') & era5.id.isin(points.id),'id'])
assert set(points.loc[points.era5_disponivel,'id'])==expected_era5
enso=pd.read_csv(ROOT/'dados/enso.csv')
checked=0
for p in points.itertuples():
    path=OUT/p.arquivo
    assert sha(path)==p.sha256
    d=pd.read_csv(path,parse_dates=['data'])
    assert len(d)==p.registros and not d.duplicated(['id','fonte','data']).any()
    assert set(d.fonte)==set(p.fontes.split('|'))
    for source,g in d.groupby('fonte'):
        raw=pd.read_csv(WORLD/'mensal'/f'{source.lower()}_{p.id}.csv',parse_dates=['data'])
        both=g.merge(raw,on=['data','id','fonte'],validate='one_to_one',suffixes=('','_original'))
        assert len(both)==540
        for col in ['temperatura_c','precipitacao_mm_mes']:
            np.testing.assert_allclose(both[col],both[col+'_original'],rtol=0,atol=1e-10)
        # Julho e fevereiro cobrem referencias mensais diferentes; checagem independente.
        for month in [2,7]:
            baseline=raw[raw.data.dt.year.between(1991,2020)&raw.data.dt.month.eq(month)]
            assert len(baseline)==30
            part=g[g.data.dt.month.eq(month)]
            np.testing.assert_allclose(part.temperatura_referencia_c,baseline.temperatura_c.mean(),atol=1e-10)
            np.testing.assert_allclose(part.precipitacao_referencia_mm_mes,baseline.precipitacao_mm_mes.mean(),atol=1e-10)
        for index in ['ONI','RONI']:
            ref=enso[enso.indice.eq(index)].set_index('data_central').valor
            np.testing.assert_allclose(g[index],g.data.dt.strftime('%Y-%m-%d').map(ref))
    checked+=len(d)
assert checked==manifest['registros']==(len(points)+len(expected_era5))*540
# Uma falha de referencia deve interromper a integracao, nao preencher com media de29anos.
sample=pd.read_csv(WORLD/'mensal'/f'power_{points.id.iloc[0]}.csv',parse_dates=['data'])
bad=sample[sample.data.ne(pd.Timestamp('1991-02-01'))]
indices=enso.pivot(index='data_central',columns='indice',values='valor').reset_index().rename(columns={'data_central':'data'})
indices['data']=pd.to_datetime(indices.data)
try:enrich(bad,indices)
except AssertionError:pass
else:raise AssertionError('Referencia incompleta aceita')
(OUT/'verificacao.json').write_text(json.dumps(dict(pontos=len(points),registros=checked,
    dupla_fonte=len(expected_era5),apenas_power=int((~points.era5_disponivel).sum()),teste_referencia_incompleta='rejeitada',
    inferencia_mundial=False),indent=2)+'\n',encoding='utf-8')
print(f'PASS: {len(points)} pontos, {checked} registros; fonte ausente nao fabricada.')
