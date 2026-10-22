import {conferirProva,conferirArquivo} from './verificar-core.js';
function iniciarVerificacao(){
  const box=document.getElementById('verificar-dados');if(!box)return;
  const en=document.documentElement.lang.startsWith('en'),result=box.querySelector('[data-proof-result]');
  const file=box.querySelector('input[type=file]'),kind=box.querySelector('select'),button=box.querySelector('[data-proof-check]');
  let query=null,proof=null,epoch=0;
  const say=(text,state='pending')=>{result.textContent=text;result.dataset.state=state;};
  const base=new URL('./csv-r14/',import.meta.url);
  async function get(path,binary=false) {
    const response=await fetch(new URL(path,base),{cache:'no-store'});
    if(!response.ok)throw Error('network');return binary?response.arrayBuffer():response.json();
  }
  async function load() {
    const config=await get('proof.json');
    if(!/^[a-f0-9]{64}$/.test(config.transaction)||!/^G[A-Z2-7]{55}$/.test(config.account))throw Error('config');
    const endpoint='https://horizon-testnet.stellar.org';
    box.querySelector('[data-manifest-sha]').textContent=config.sha256;
    const publicLink=box.querySelector('[data-transaction]');publicLink.href=endpoint+'/transactions/'+config.transaction;publicLink.hidden=false;
    const responses=await Promise.all([fetch(endpoint),fetch(endpoint+'/transactions/'+config.transaction)]);
    if(responses.some(r=>!r.ok))throw Error('network');
    const [network,tx]=await Promise.all(responses.map(r=>r.json()));
    if(network.network_passphrase!=='Test SDF Network ; September 2015')throw Error('network');
    const checked=await conferirProva(await get('manifest.json',true),await get('csv-index.json',true),tx,config);
    box.querySelector('[data-manifest-sha]').textContent=checked.root;
    const link=box.querySelector('[data-transaction]');link.href=endpoint+'/transactions/'+config.transaction;link.hidden=false;
    box.querySelector('[data-network-status]').textContent=(en?'Confirmed on Stellar Testnet · ledger ':'Confirmado na Stellar Testnet · ledger ')+checked.ledger;
    return checked;
  }
  Shiny.addCustomMessageHandler('enso-proof-query',value=>{
    query=value;epoch++;file.value='';say(en?'Download a CSV for this query, choose the file and verify it.':'Baixe um CSV desta consulta, escolha o arquivo e confira.');
    box.querySelector('[data-file-sha]').textContent='—';box.querySelector('[data-expected-sha]').textContent='—';
  });
  const reset=()=>{epoch++;say(en?'File selection changed. Verify it to obtain a result.':'O arquivo ou tipo mudou. Verifique para obter um resultado.');box.querySelector('[data-file-sha]').textContent='—';box.querySelector('[data-expected-sha]').textContent='—';};
  file.addEventListener('change',reset);kind.addEventListener('change',reset);
  box.addEventListener('toggle',async()=>{if(!box.open||proof)return;try{proof=await load();}catch{box.querySelector('[data-network-status]').textContent=en?'Network confirmation unavailable.':'Confirmação da rede indisponível.';}});
  box.querySelectorAll('[data-download]').forEach(b=>b.addEventListener('click',()=>document.getElementById(b.dataset.download)?.click()));
  button.addEventListener('click',async()=>{
    const selected=file.files?.[0],selection=query&&{...query},token=++epoch;
    if(selection && (selection.id!==document.getElementById('cidade')?.value || selection.season!==document.getElementById('estacao')?.value || selection.variable!==document.getElementById('variavel')?.value)){
      say(en?'Wait for the selected query to finish updating.':'Aguarde a atualização da consulta selecionada.');return;
    }
    if(!selected||!selection){say(en?'Choose a CSV file first.':'Escolha primeiro um arquivo CSV.');return;}
    if(selected.size>20*1024*1024){say(en?'This file is larger than the supported CSV exports.':'Este arquivo excede o tamanho dos CSVs aceitos.','error');return;}
    button.disabled=kind.disabled=file.disabled=true;box.querySelector('[data-network-status]').textContent=en?'Checking the public network…':'Consultando a rede pública…';say(en?'Checking the network and the file…':'Conferindo a rede e o arquivo…');
    const type=kind.value;
    try {
      // Recheck the public receipt on each explicit verification, never claim offline confirmation.
      proof=await load();
      const key=type==='mensal'?[selection.lang,selection.id,'mensal'].join('|'):[selection.lang,selection.id,selection.season,selection.variable,'serie'].join('|');
      const verified=await conferirArquivo(await selected.arrayBuffer(),proof.index.entries[key]);
      if(token!==epoch)return;
      say(verified.matches?(en?'The file matches the recorded CSV for this query.':'O arquivo corresponde ao CSV registrado desta consulta.'):
        (en?'This file does not match. It may be altered, from another query or in a different format.':'Este arquivo não corresponde. Pode ter sido alterado, ser de outra consulta ou estar em outro formato.'),verified.matches?'valid':'error');
      box.querySelector('[data-file-sha]').textContent=verified.actual;
      box.querySelector('[data-expected-sha]').textContent=verified.expected;
    } catch(error) {
      if(token===epoch)say(en?'Verification was not completed. Check the network, the file type and the selected query. No validity claim was made.':'A verificação não foi concluída. Confira a conexão, o tipo de arquivo e a consulta selecionada. O arquivo não foi declarado válido.','error');
    } finally {button.disabled=kind.disabled=file.disabled=false;}
  });
  // Local summaries are rendered after DOMContentLoaded; delegate their links too.
  document.addEventListener('click',event=>{
    const link=event.target.closest('a[href="#verificar-dados"],a[href="#enso-historico"]');
    if(!link)return;
    const target=document.querySelector(link.getAttribute('href'));if(!target)return;
    event.preventDefault();target.open=true;
    target.scrollIntoView({block:'start',behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'instant':'smooth'});
    target.querySelector('summary')?.focus({preventScroll:true});
  });
}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',iniciarVerificacao,{once:true});
else iniciarVerificacao();
