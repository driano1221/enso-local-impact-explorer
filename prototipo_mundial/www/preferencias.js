(() => {
  'use strict';
  const root=document.documentElement;
  const english=()=>root.lang.startsWith('en');
  let stored='light';try{stored=localStorage.getItem('enso-theme')||stored;}catch{}
  const requested=new URLSearchParams(location.search).get('theme');
  root.dataset.theme=['light','dark'].includes(requested)?requested:(stored==='dark'?'dark':'light');
  const painting=new WeakSet();
  const paintPlots=()=>{
    const dark=root.dataset.theme==='dark',bg=dark?'#142e40':'#ffffff',ink=dark?'#c1d4df':'#536771',grid=dark?'#355064':'#e4ebee';
    document.querySelectorAll('.js-plotly-plot').forEach(el=>{
      if(!el._fullLayout||!window.Plotly||el._fullLayout.paper_bgcolor===bg||painting.has(el))return;
      painting.add(el);
      Plotly.relayout(el,{'paper_bgcolor':bg,'plot_bgcolor':bg,'font.color':ink,'xaxis.gridcolor':grid,'yaxis.gridcolor':grid,
        'xaxis.linecolor':grid,'yaxis.linecolor':grid,'xaxis.zerolinecolor':ink,'yaxis.zerolinecolor':ink}).then(()=>{
        const indices=el.data.map((t,i)=>['POWER','ERA5'].includes(t.name)?i:-1).filter(i=>i>=0);
        const colors=indices.map(i=>el.data[i].name==='POWER'?(dark?'#ff8065':'#e44e36'):(dark?'#6ab9d7':'#217fa5'));
        return indices.length?Plotly.restyle(el,{'line.color':colors,'marker.color':colors},indices):null;
      }).finally(()=>{painting.delete(el);if((root.dataset.theme==='dark')!==dark)requestAnimationFrame(paintPlots);});
    });
  };
  const sync=()=>{
    const dark=root.dataset.theme==='dark';
    document.querySelectorAll('[data-theme-toggle]').forEach(b=>{
      b.setAttribute('aria-pressed',String(dark));
      b.setAttribute('aria-label',english()?(dark?'Switch to light theme':'Switch to dark theme'):(dark?'Ativar tema claro':'Ativar tema escuro'));
      b.title=b.getAttribute('aria-label');
    });
    document.querySelectorAll('.pacifico-frame').forEach(f=>f.contentWindow?.postMessage({type:'enso-theme',theme:root.dataset.theme},location.origin));
    paintPlots();
  };
  document.addEventListener('DOMContentLoaded',()=>{
    sync();
    const metric=document.getElementById('variavel');
    const metricLabel=()=>{const label=document.querySelector('input[name=escala][value=valor]')?.nextElementSibling;
      const text=metric.value==='temperatura_c'?(english()?'Temperature (°C)':'Temperatura (°C)'):(english()?'Rainfall (mm)':'Chuva (mm)');
      if(label&&label.textContent!==text)label.textContent=text;};
    metric?.addEventListener('change',metricLabel);metricLabel();
    document.querySelector('[data-theme-toggle]')?.addEventListener('click',()=>{
      root.dataset.theme=root.dataset.theme==='dark'?'light':'dark';
      try{localStorage.setItem('enso-theme',root.dataset.theme);}catch{}
      const url=new URL(location.href);if(url.searchParams.has('theme')){url.searchParams.set('theme',root.dataset.theme);history.replaceState(null,'',url.href);}
      sync();
    });
    document.querySelectorAll('[data-language]').forEach(b=>{
      b.setAttribute('aria-pressed',String(b.dataset.language===(english()?'en':'pt')));
      b.addEventListener('click',()=>{
        if(b.getAttribute('aria-pressed')==='true')return;
        const url=new URL(location.href);url.searchParams.set('lang',b.dataset.language);url.searchParams.set('theme',root.dataset.theme);
        const city=document.getElementById('cidade');if(city?.value)url.searchParams.set('city',city.value);
        for(const id of ['estacao','variavel']){const value=document.getElementById(id)?.value;if(value)url.searchParams.set(id,value);}
        const scale=document.querySelector('input[name=escala]:checked');if(scale)url.searchParams.set('escala',scale.value);
        url.hash='';location.assign(url.href);
      });
    });
    document.addEventListener('click',e=>{
      const button=e.target.closest('.ajuda-botao');
      document.querySelectorAll('.ajuda-botao[aria-expanded=true]').forEach(b=>{if(b!==button)b.setAttribute('aria-expanded','false');});
      if(button){e.preventDefault();const open=button.getAttribute('aria-expanded')!=='true';button.setAttribute('aria-expanded',String(open));button.parentElement.dataset.dismissed=String(!open);}
    });
    document.addEventListener('focusin',e=>{if(e.target.matches('.ajuda-botao'))delete e.target.parentElement.dataset.dismissed;});
    document.addEventListener('pointerover',e=>{const info=e.target.closest('.ajuda-info');if(info&&!info.contains(e.relatedTarget))delete info.dataset.dismissed;});
    document.addEventListener('keydown',e=>{if(e.key==='Escape')document.querySelectorAll('.ajuda-botao').forEach(b=>{b.setAttribute('aria-expanded','false');b.parentElement.dataset.dismissed='true';});});
    document.querySelectorAll('.pacifico-frame').forEach(f=>f.addEventListener('load',sync));
    if(window.jQuery){jQuery(document).on('shiny:value',()=>{metricLabel();requestAnimationFrame(paintPlots);});
      jQuery(document).on('shiny:inputchanged',e=>{if(e.name==='variavel')requestAnimationFrame(metricLabel);});}
    const watched=new WeakSet();
    new MutationObserver(()=>{document.querySelectorAll('.js-plotly-plot').forEach(el=>{
      if(!watched.has(el)&&el.on){watched.add(el);el.on('plotly_afterplot',paintPlots);}
    });paintPlots();}).observe(document.getElementById('consulta'),{childList:true,subtree:true});
  });
})();
