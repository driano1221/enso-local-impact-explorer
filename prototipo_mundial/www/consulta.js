(() => {
  'use strict';
  document.addEventListener('DOMContentLoaded', () => {
    const en=document.documentElement.lang.startsWith('en'), status=document.getElementById('consulta-feedback');
    const shell=document.querySelector('.exploracao'), year=document.getElementById('ano-inspecao'), readout=document.getElementById('ano-valores');
    let ready=null,idle=false,pending=true,signature='',lastYear='',timer;
    const selected=()=>Object.fromEntries(['pais','cidade','estacao','variavel','escala'].map(id=>[id,id==='escala'?document.querySelector('input[name=escala]:checked')?.value:document.getElementById(id)?.value]));
    const same=(a,b)=>a&&Object.keys(b).every(k=>a[k]===b[k]);
    function waiting(){
      pending=true;shell.classList.add('consulta-atualizando');shell.setAttribute('aria-busy','true');
      document.getElementById('enso-assistente')?.setAttribute('inert','');
      status.dataset.state='waiting';status.textContent=en?'Updating the selected query…':'Atualizando o recorte selecionado…';
    }
    function settle(){
      clearTimeout(timer);timer=setTimeout(()=>{
        if(!idle||!same(ready,selected())||document.querySelector('.exploracao .recalculating'))return;
        pending=false;shell.classList.remove('consulta-atualizando');shell.setAttribute('aria-busy','false');
        document.getElementById('enso-assistente')?.removeAttribute('inert');
        status.dataset.state='ready';status.textContent=en?'Query updated · inspect a year below the chart':'Consulta atualizada · explore um ano abaixo do gráfico';
        bindCharts();
      },80);
    }
    document.addEventListener('change',e=>{if(['pais','cidade','variavel','estacao','escala'].includes(e.target.id)||e.target.name==='escala')waiting();});
    jQuery(document).on('shiny:busy',()=>{idle=false;}).on('shiny:idle',()=>{idle=true;settle();})
      .on('shiny:value',()=>{if(pending)settle();});
    Shiny.addCustomMessageHandler('consulta-pronta',value=>{ready=value;settle();});
    function inspect(value){
      const plot=document.getElementById('historico'),distribution=document.getElementById('distribuicao');
      if(pending||!plot?.data)return;
      if(lastYear===String(value))return;lastYear=String(value);
      year.value=String(value);readout.replaceChildren();
      const unit=selected().variavel==='temperatura_c'?'°C':'mm';
      const scale=selected().escala==='diferenca'?(en?'difference from baseline':'diferença da média'):(en?'seasonal value':'valor do trimestre');
      for(const trace of plot.data){
        const i=trace.x.findIndex(x=>Number(x)===Number(value));
        if(i<0)continue;
        const label=document.createElement('span');label.className=trace.name.includes('POWER')?'inspecao-power':'inspecao-era5';
        label.textContent=`${trace.name}: ${Number(trace.y[i]).toLocaleString(en?'en-US':'pt-BR',{minimumFractionDigits:2,maximumFractionDigits:2})} ${unit}`;readout.append(label);
      }
      const note=document.createElement('small');note.textContent=`${value} · ${scale}`;readout.append(note);
      // Emphasis changes marker size only, never coordinates or computed values.
      Plotly.restyle(plot,{'mode':'lines+markers','marker.size':plot.data.map(t=>t.x.map(x=>Number(x)===Number(value)?7:0))});
      if(distribution?.data)Plotly.restyle(distribution,{'marker.size':distribution.data.map(t=>(t.customdata||[]).map(x=>Number(x)===Number(value)?10:5))});
    }
    function bindCharts(){
      const plot=document.getElementById('historico'),distribution=document.getElementById('distribuicao');
      if(!plot?.data?.length||!distribution?.data?.length)return;
      const key=JSON.stringify([ready,plot.data.map(t=>[t.x,t.y])]);
      if(key!==signature){
        signature=key;lastYear='';const years=[...new Set(plot.data.flatMap(t=>t.x.map(Number)))].sort((a,b)=>a-b),previous=Number(year.value);
        year.replaceChildren(...years.map(n=>new Option(String(n),String(n))));
        inspect(years.includes(previous)?previous:years.at(-1));
      }
      for(const [el,isDistribution] of [[plot,false],[distribution,true]]){
        if(el.dataset.inspectionBound)continue;el.dataset.inspectionBound='true';
        el.on('plotly_hover',event=>{const point=event.points?.[0];if(point)inspect(isDistribution?point.customdata:point.x);});
        el.on('plotly_afterplot',()=>{if(pending)settle();});
      }
    }
    year.addEventListener('change',()=>inspect(year.value));
    document.querySelectorAll('a[href="#enso-assistente"]').forEach(link=>link.addEventListener('click',e=>{
      e.preventDefault();const assistant=document.getElementById('enso-assistente');if(!assistant)return;
      assistant.open=true;assistant.scrollIntoView({block:'center',behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'instant':'smooth'});
      document.getElementById('enso_question').focus({preventScroll:true});
    }));
    waiting();
  });
})();
