(() => {
  'use strict';
  const assetBase=new URL('./',document.currentScript.src);
  let current,view='globe',revision=0,globePromise,catalogue=[],mapFiles;
  const readJSON=url=>fetch(new URL(url,assetBase)).then(r=>{if(!r.ok)throw Error(url);return r.json();});
  function globe(){return globePromise ||= import('./globo.js?v=20261019-abertura1').then(async m=>{const g=await m.createLocator(document.getElementById('globo-local'),id=>Shiny.setInputValue('globo_selecao',id,{priority:'event'}));g.catalogue(catalogue);return g;});}
  async function draw(){
    const version=++revision,el=document.getElementById('localizador');if(!current||!el)return;
    if(/^[A-Z]{2}$/.test(current.iso2))document.getElementById('pais').style.backgroundImage=`url('${new URL('vendor/flags/'+current.iso2.toLowerCase()+'.svg',assetBase)}')`;
    const pilot=['GN-3445133','GN-3455671','GN-3470127'].includes(current.id);
    if(view==='region'&&!pilot)view='globe';
    document.documentElement.style.setProperty('--metric',current.metrica==='temperatura_c'?'#e44e36':'#217fa5');
    // On phones the data comes first; initialise WebGL only when the location is opened.
    if(!document.querySelector('.localizacao-expandivel').open){
      if(globePromise)globePromise.then(g=>g.hide()).catch(()=>{});
      return;
    }
    try{
      if(view==='globe'){
        try{const g=await globe();if(version!==revision)return;el.hidden=true;g.show(current);}
        catch(e){console.warn('Globo de localização indisponível; mapa alternativo ativo.',e);if(version!==revision)return;view='fallback';el.hidden=false;document.getElementById('globo-local').hidden=true;}
      }else{el.hidden=false;if(globePromise)globePromise.then(g=>g.hide()).catch(()=>{});}
      if(view!=='globe'){
        // Cartographic fallback and regional geometry are requested only when used.
        const [world,region]=await(mapFiles ||= Promise.all([readJSON('mapa.json'),readJSON('aprovado/regiao.json')]));
        if(version!==revision)return;
        const id=pilot?current.id.replace('GN-',''):current.id;
        const regions=pilot?region:{regioes:{[id]:{pontos:[{id,nome:current.nome}]}}};
        el.innerHTML=EnsoAtlas.render(world,regions,id,current.metrica,view==='region'?'region':'world');
        el.querySelector('svg').setAttribute('aria-label',`${current.nome}. Geographic location.`);
      }
      document.querySelectorAll('[data-map-view]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.mapView===view)));
      document.querySelector('.mapa-nota').textContent=view==='globe'
        ?'Drag the globe and select a point to explore another city. Estimates describe grid cells, not individual neighbourhoods.'
        :'Location map. Sources estimate climate for a grid cell, not individual neighbourhoods.';
    }catch(e){el.hidden=false;el.textContent='Map unavailable. The city and coordinates remain available below.';}
  }
  document.addEventListener('DOMContentLoaded',()=>{
    const location=document.querySelector('.localizacao-expandivel'),phone=matchMedia('(max-width:760px)');
    location.open=!phone.matches;
    location.addEventListener('toggle',()=>draw());
    phone.addEventListener('change',()=>{location.open=!phone.matches;draw();});
    for(const id of ['pais','cidade']){
      const select=document.getElementById(id),label=document.createElement('span');label.className='nome-completo';label.id=id+'-completo';select.after(label);select.setAttribute('aria-describedby',label.id);
      const measure=document.createElement('canvas').getContext('2d');
      const update=()=>{const text=select.selectedOptions[0]?.textContent||'';const style=getComputedStyle(select);measure.font=style.font;const available=select.clientWidth-parseFloat(style.paddingLeft)-Math.max(28,parseFloat(style.paddingRight));label.textContent=measure.measureText(text).width>available?text:'';label.hidden=!label.textContent;select.title=text;};
      select.addEventListener('change',update);new MutationObserver(update).observe(select,{childList:true,subtree:true});new ResizeObserver(update).observe(select);document.fonts.ready.then(update);update();
    }
    Shiny.addCustomMessageHandler('mundial',p=>{current=p;draw();});
    Shiny.addCustomMessageHandler('catalogo',points=>{catalogue=points;if(globePromise)globePromise.then(g=>g.catalogue(points)).catch(()=>{});});
    document.getElementById('globo-local').addEventListener('locatorfailed',()=>{view='fallback';draw();});
    document.querySelectorAll('[data-map-view]').forEach(b=>b.addEventListener('click',()=>{view=b.dataset.mapView;draw();}));
    const frame=document.querySelector('.pacifico-frame');
    const observer=new IntersectionObserver(entries=>{
      if(!entries[0].isIntersecting||frame.hasAttribute('srcdoc'))return;
      observer.disconnect();
      fetch(new URL(frame.dataset.src,document.baseURI),{credentials:'same-origin'})
        .then(response=>{if(!response.ok)throw new Error('ENSO payload: '+response.status);return response.json();})
        .then(payload=>{frame.srcdoc=payload.html.replace('__ENSO_ASSET_BASE__',new URL('aprovado/',new URL(frame.dataset.src,document.baseURI)).href);})
        .catch(error=>{console.error(error);const note=document.createElement('p');note.className='nota';note.setAttribute('role','alert');note.textContent=document.documentElement.lang.startsWith('pt')?'A explicação ENSO não carregou. Recarregue a página.':'The ENSO explanation could not load. Reload the page.';frame.before(note);});
    },{rootMargin:'50px'});observer.observe(frame);
  });
})();
