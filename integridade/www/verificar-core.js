// Public Horizon over HTTPS is the trust boundary; this is not an independent node.
export async function sha256(bytes) {
  return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes)),b=>b.toString(16).padStart(2,'0')).join('');
}
export async function conferirProva(manifestBytes,indexBytes,tx,config) {
  const root=await sha256(manifestBytes);
  if(!/^[a-f0-9]{64}$/.test(config.sha256)||root!==config.sha256) throw Error('manifest');
  const memo=Array.from(Uint8Array.from(atob(tx.memo||''),c=>c.charCodeAt(0)),b=>b.toString(16).padStart(2,'0')).join('');
  if(tx.successful!==true||tx.hash!==config.transaction||tx.source_account!==config.account||tx.memo_type!=='hash'||memo!==root||!(Number(tx.ledger)>0)) throw Error('transaction');
  const manifest=JSON.parse(new TextDecoder().decode(manifestBytes));
  const item=manifest.files?.find(f=>f.path==='csv-index.json');
  if(manifest.schema!=='enso-public-bundle-v1'||!item||item.bytes!==indexBytes.byteLength||item.sha256!==await sha256(indexBytes)) throw Error('index');
  const index=JSON.parse(new TextDecoder().decode(indexBytes));
  if(index.schema!=='enso-csv-index-v1'||!index.entries) throw Error('schema');
  return {index,root,ledger:tx.ledger};
}
export async function conferirArquivo(bytes,expected) {
  if(!/^[a-f0-9]{64}$/.test(expected||'')) throw Error('query');
  const actual=await sha256(bytes);return {actual,expected,matches:actual===expected};
}
