(function () {
  'use strict';
  const escape = s => String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  window.EnsoAtlas = {
    render(world, region, selected, metric, view) {
      const id = String(selected), r = region.regioes[id];
      const temp = metric === 'temperatura_c', color = temp ? '#c0392b' : '#2980b9';
      const title = r.pontos.find(p=>String(p.id)===id).nome;
      const icon = temp ? '<path d="M-3 2V-10a3 3 0 0 1 6 0V2a6 6 0 1 1-6 0Z"/><path d="M0-5V5"/>' : '<path d="M0-12C-4-6-7-2-7 3a7 7 0 0 0 14 0c0-5-3-9-7-15Z"/>';
      const marker = (x,y) => `<g transform="translate(${x},${y})"><circle r="23" fill="${color}" opacity=".1"/><circle class="atlas-pin" r="15" fill="white" stroke="${color}" stroke-width="2.5"/><g transform="scale(.65)" fill="none" stroke="${color}" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">${icon}</g></g>`;
      let content;
      if(view==='world') {
        const p = world.pontos.find(p=>String(p.id)===id).world;
        const x=20+p[0]*.7, y=65+p[1]*.7;
        content=`<path d="${world.world}" transform="translate(20 65)scale(.7)" fill="#9db7be" stroke="#e8efef" stroke-width=".9"/>
          <path d="M${x} ${y+18}V373H575" fill="none" stroke="${color}" stroke-width="1.5"/>
          ${marker(x,y)}<text class="atlas-city" x="575" y="402" text-anchor="end" fill="${color}">${escape(title)}</text>
          <text x="24" y="420" class="atlas-credit">Natural Earth · Equal Earth · centro em Greenwich</text>`;
      } else {
        const labels = r.pontos.map(p=>{
          const active=String(p.id)===id;
          // Fixed geographic scale reserves a separate label row for each pilot city.
          const y=p.y+(p.nome==='Ouro Preto'?(active?49:31):-25);
          return `${active?marker(p.x,p.y):`<circle cx="${p.x}" cy="${p.y}" r="4" fill="#557480" stroke="white" stroke-width="2"/>`}
            <text class="atlas-city ${active?'atlas-selected':''}" x="${p.x}" y="${y}" text-anchor="middle" fill="${active?color:'#38535e'}">${escape(p.nome)}</text>`;
        }).join('');
        content=`<path d="${r.estados}" fill="#eaf0ed" stroke="#91a9ab" stroke-width="1.4"/>
          <path d="${r.municipios}" fill="none" stroke="#bccfca" stroke-width=".85"/>
          <text x="350" y="55" class="atlas-state">MINAS</text><text x="350" y="79" class="atlas-state">GERAIS</text>
          <g class="atlas-north" transform="translate(551 33)"><text y="-7" text-anchor="middle">N</text><path d="M0 0-5 16 0 13 5 16Z" fill="#4b6871"/></g>
          ${labels}
          <g transform="translate(20 311)"><rect x="-9" y="-8" width="148" height="139" rx="3" fill="#f7faf8" stroke="#ccd8d4"/>
          <path d="${region.brasil}" fill="#d4dfda" stroke="#f7faf8" stroke-width=".7"/>
          <path d="${region.mg}" fill="#628f91" stroke="#f7faf8" stroke-width=".7"/>
          <text x="8" y="117" class="atlas-credit">BRASIL · MG</text></g>
          <g transform="translate(439 414)"><path d="M0-5V0H${r.escala50km}V-5" fill="none" stroke="#55717a" stroke-width="1.5"/><text x="${r.escala50km/2}" y="20" text-anchor="middle" class="atlas-credit">50 km</text></g>`;
      }
      return `<svg class="atlas-map" viewBox="0 0 600 450" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="${escape(title)}, Minas Gerais, Brasil. ${view==='world'?'Localização no mundo':'Mapa regional com as três cidades do piloto'}."><title>${escape(title)} · ${temp?'temperatura':'chuva'}</title><rect width="600" height="450" fill="#edf3f1"/>${content}</svg>`;
    }
  };
})();
