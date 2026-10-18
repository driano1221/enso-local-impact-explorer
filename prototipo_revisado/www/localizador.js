/* Geometria pré-calculada: nenhum tile, biblioteca de mapas ou gesto de navegação. */
window.EnsoLocator = {
  render(g, id, nome, metrica) {
    const p = g.pontos.find(p => String(p.id) === String(id));
    if (!p) return '';
    const cor = metrica === 'temperatura_c' ? '#c0392b' : '#2980b9';
    const mark = (x,y,r) => `<circle cx="${x}" cy="${y}" r="${r+5}" fill="${cor}" opacity=".12"/><circle cx="${x}" cy="${y}" r="${r}" fill="${cor}" stroke="white" stroke-width="2"/>`;
    return `<svg viewBox="0 0 700 330" role="img" aria-label="${nome}, Minas Gerais, Brasil. Localização no mundo e no Brasil." class="localizador-vetor" xmlns="http://www.w3.org/2000/svg">
      <path d="M392 28V286" stroke="#c7d5dc" stroke-dasharray="3 6"/>
      <text x="18" y="32" fill="#557082" font-size="12" letter-spacing="2">NO MUNDO</text>
      <g transform="translate(12 67) scale(.46)"><path d="${g.world}" fill="#bacbd5" stroke="#eef4f7" stroke-width=".65"/>${mark(...p.world,9)}</g>
      <g transform="translate(395 9) scale(.85)"><path d="${g.brasil}" fill="#d1e0e8" stroke="#8aabba" stroke-width="1.2"/>${mark(...p.brasil,5)}</g>
      <text x="430" y="32" fill="#557082" font-size="12" letter-spacing="2">BRASIL</text>
      <text x="18" y="293" fill="#557082" font-size="12">Natural Earth · contornos simplificados</text>
      <text x="430" y="293" fill="${cor}" font-size="14" font-weight="600">● ${nome} / MG</text>
    </svg>`;
  }
};
