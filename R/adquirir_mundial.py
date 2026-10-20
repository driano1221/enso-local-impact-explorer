"""Acquire approved worldwide points; isolated snapshots and resumable coverage ledger."""
import argparse,calendar,concurrent.futures,datetime,hashlib,json,math,time
from pathlib import Path
import pandas as pd, requests
from email.utils import parsedate_to_datetime
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'dados/mundial';RAW=ROOT/'dados/originais/mundial_20261015';RAW.mkdir(parents=True,exist_ok=True)
MONTHS=pd.date_range('1981-01-01','2025-12-01',freq='MS')

def cooldown_seconds(item, now):
    """Honor Retry-After; absent headers use the provider's stated window."""
    retry=str(item.get('retry_after',''))
    try:return max(60,float(retry))
    except ValueError:
        try:return max(60,parsedate_to_datetime(retry).timestamp()-now)
        except (ValueError,TypeError,OverflowError):pass
    error=str(item.get('erro','')).lower()
    if 'month' in error:return 31*86400
    # Open-Meteo clears the daily counter at 00:00 UTC in its minutely callback.
    # Wait until 00:01 UTC, rather than adding 24 hours to the rejected request.
    if 'day' in error or 'daily' in error:return (math.floor(now/86400)+1)*86400+60-now
    if 'hour' in error:return 3600
    return 3600 # unknown scope: do not hammer the same quota
def parse(j,source):
    if source=='POWER':
        assert j['parameters']['T2M']['units']=='C' and j['parameters']['PRECTOTCORR']['units']=='mm/day'
        p=j['properties']['parameter'];fill=j['header'].get('fill_value',-999)
        def val(v):return float(v) if v is not None and float(v)!=fill else float('nan')
        rows=[]
        for d in MONTHS:
            k=d.strftime('%Y%m');t=val(p['T2M'].get(k));c=val(p['PRECTOTCORR'].get(k))
            assert not math.isfinite(t) or -90<t<65
            assert not math.isfinite(c) or c>=0
            rows.append(dict(data=d.strftime('%Y-%m-%d'),temperatura_c=t,precipitacao_mm_mes=c*calendar.monthrange(d.year,d.month)[1]))
        return pd.DataFrame(rows)
    assert j['utc_offset_seconds']==0 and j['daily_units']['temperature_2m_mean']=='°C' and j['daily_units']['precipitation_sum']=='mm'
    d=pd.DataFrame(dict(data=pd.to_datetime(j['daily']['time']),t=j['daily']['temperature_2m_mean'],p=j['daily']['precipitation_sum']))
    assert len(d)==16436 and not d.data.duplicated().any() and (d.data.diff().dropna()==pd.Timedelta(days=1)).all()
    assert ((d.t>-90)&(d.t<65)|d.t.isna()).all() and ((d.p>=0)|d.p.isna()).all()
    rows=[]
    for month,g in d.groupby(d.data.dt.to_period('M')):
        expected=calendar.monthrange(month.year,month.month)[1]
        assert len(g)==expected
        rows.append(dict(data=str(month)+'-01',temperatura_c=g.t.mean() if g.t.notna().all() else float('nan'),precipitacao_mm_mes=g.p.sum() if g.p.notna().all() else float('nan')))
    return pd.DataFrame(rows)
def acquire(r,source):
    name=f'{source.lower()}_{r.id}.json';path=RAW/name;meta=RAW/(name+'.metadata.json')
    url=(f'https://power.larc.nasa.gov/api/temporal/monthly/point?parameters=T2M,PRECTOTCORR&community=AG&latitude={r.latitude}&longitude={r.longitude}&start=1981&end=2025&format=JSON' if source=='POWER' else f'https://archive-api.open-meteo.com/v1/archive?latitude={r.latitude}&longitude={r.longitude}&start_date=1981-01-01&end_date=2025-12-31&daily=temperature_2m_mean,precipitation_sum&models=era5&timezone=UTC&elevation=nan&cell_selection=nearest&temperature_unit=celsius&precipitation_unit=mm')
    result=dict(id=r.id,cidade=r.cidade,pais_iso2=r.pais_iso2,fonte=source,status='falha',url=url)
    try:
        if path.exists():
            b=path.read_bytes();m=json.loads(meta.read_text());assert m['url']==url and m['sha256']==hashlib.sha256(b).hexdigest()
        else:
            response=requests.get(url,timeout=120)
            if response.status_code==429:
                return dict(result,status='limite_provedor',erro=response.text[:500],retry_after=response.headers.get('Retry-After',''))
            response.raise_for_status();b=response.content;j=json.loads(b);d=parse(j,source)
            tmp=path.with_suffix('.part');tmp.write_bytes(b);tmp.replace(path)
            meta.write_text(json.dumps(dict(url=url,sha256=hashlib.sha256(b).hexdigest(),consultado_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),latitude_pedida=r.latitude,longitude_pedida=r.longitude,calendario='LST' if source=='POWER' else 'UTC',licenca='NASA POWER attribution' if source=='POWER' else 'CC BY 4.0; Open-Meteo/ECMWF/Copernicus'),indent=2),encoding='utf-8')
        j=json.loads(b);d=parse(j,source);assert len(d)==540 and not d.data.duplicated().any()
        d['id']=r.id;d['fonte']=source
        folder=OUT/'mensal';folder.mkdir(exist_ok=True);d.to_csv(folder/f'{source.lower()}_{r.id}.csv',index=False)
        return dict(result,status='completo' if d[['temperatura_c','precipitacao_mm_mes']].notna().all().all() else 'incompleto',meses=540,temperatura_validos=int(d.temperatura_c.notna().sum()),chuva_validos=int(d.precipitacao_mm_mes.notna().sum()),sha256=hashlib.sha256(b).hexdigest(),latitude_retornada=j.get('latitude'),longitude_retornada=j.get('longitude'))
    except Exception as e:return dict(result,erro=str(e))
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--fonte',choices=['POWER','ERA5'],default='POWER');parser.add_argument('--limite',type=int,default=10000);args=parser.parse_args()
    cat=pd.read_csv(OUT/'catalogo.csv',keep_default_na=False);valid=cat[cat.status=='aprovado_fonte'].copy()
    # Country-balanced ordering: first city of every entity before second/third.
    valid['rodada']=valid.groupby('pais_iso2').cumcount();valid=valid.sort_values(['rodada','pais_iso2'])
    ledger=OUT/f'cobertura_{args.fonte.lower()}.csv'
    previous=pd.read_csv(ledger,keep_default_na=False).to_dict('records') if ledger.exists() else []
    results={x['id']:x for x in previous}; todo=[r for r in valid.itertuples() if results.get(r.id,{}).get('status') not in ['completo','incompleto']][:args.limite]
    def save():
        pd.DataFrame(list(results.values())).to_csv(ledger,index=False)
    if args.fonte=='POWER':
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            futures={pool.submit(acquire,r,args.fonte):r.id for r in todo}
            for i,f in enumerate(concurrent.futures.as_completed(futures),1):
                item=f.result();results[item['id']]=item;save()
                if i%20==0 or item['status']!='completo':print(json.dumps(dict(progresso=i,total=len(todo),**item),ensure_ascii=True),flush=True)
                if item['status']=='limite_provedor':
                    for pending in futures:pending.cancel()
                    break
    else:
        pause=OUT/'era5_pausa.json'
        if pause.exists() and json.loads(pause.read_text())['retomar_epoch']>time.time():
            print('ERA5: pausa do provedor ainda vigente; nenhuma requisicao enviada.',flush=True)
            todo=[]
        for r in todo:
            item=acquire(r,args.fonte);results[item['id']]=item;save()
            if item['status']=='limite_provedor':
                now=time.time();resume=now+cooldown_seconds(item,now)
                pause.write_text(json.dumps(dict(retomar_epoch=resume,retomar_utc=datetime.datetime.fromtimestamp(resume,datetime.timezone.utc).isoformat(),motivo=item.get('erro'),retry_after=item.get('retry_after')),indent=2),encoding='utf-8')
                print(json.dumps(item,ensure_ascii=True),flush=True)
                break
            print(json.dumps(item,ensure_ascii=True),flush=True)
            time.sleep(35) # long historical requests count as multiple quota units
    queue=[]
    cat=pd.read_csv(OUT/'catalogo.csv',keep_default_na=False) # catalog may gain approved complements during a long batch
    for source in ['POWER','ERA5']:
        path=OUT/f'cobertura_{source.lower()}.csv'
        coverage=pd.read_csv(path,keep_default_na=False).set_index('id') if path.exists() else pd.DataFrame()
        for r in cat.itertuples():
            state=coverage.loc[r.id,'status'] if r.id in coverage.index else ('pendente_aquisicao' if r.status=='aprovado_fonte' else 'aguardando_revisao_catalogo')
            if r.status=='referencia_nao_urbana':state='fora_escopo_urbano_cache_preservado'
            queue.append(dict(id=r.id,cidade=r.cidade,pais_iso2=r.pais_iso2,fonte=source,status=state,meses=int(float(coverage.loc[r.id,'meses'])) if r.id in coverage.index and 'meses' in coverage.columns and str(coverage.loc[r.id,'meses']) else 0))
    pd.DataFrame(queue).to_csv(OUT/'fila_cobertura.csv',index=False)
    print(json.dumps(dict(fonte=args.fonte,alvos=len(valid),registrados=len(results),status=pd.Series([r['status'] for r in results.values()]).value_counts().to_dict())),flush=True)
if __name__=='__main__':main()
