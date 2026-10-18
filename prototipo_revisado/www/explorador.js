(function () {
  'use strict';
  const files = Promise.all(['localizador.json','regiao.json'].map(url=>fetch(url).then(r=>{if(!r.ok)throw Error('Mapa indisponível');return r.json();})));
  files.catch(()=>{});
  let current = null, view = 'region', revision = 0;
  async function draw() {
    const version=++revision, el=document.getElementById('localizador');
    if(!current || !el)return;
    try {
      const [world,region]=await files;
      if(version!==revision)return;
      el.innerHTML=EnsoAtlas.render(world,region,current.id,current.metrica,view);
      document.querySelectorAll('[data-map-view]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.mapView===view)));
    } catch(e) {el.textContent=`${current.nome} · Minas Gerais, Brasil. Mapa indisponível; coordenadas abaixo.`;}
  }
  document.addEventListener('DOMContentLoaded',function(){
    document.querySelector('.filtros-toggle').addEventListener('click',function(){
      const open=this.getAttribute('aria-expanded')!=='true';
      this.setAttribute('aria-expanded',String(open));this.textContent=open?'Recolher filtros −':'Época e fonte +';
      document.querySelector('.consulta-lateral').classList.toggle('filtros-abertos',open);
    });
    Shiny.addCustomMessageHandler('localizador',p=>{current=p;draw();});
    Shiny.addCustomMessageHandler('cor-metrica',p=>document.documentElement.style.setProperty('--metric',p.cor));
    document.querySelectorAll('[data-map-view]').forEach(b=>b.addEventListener('click',()=>{view=b.dataset.mapView;draw();}));
  });
})();
