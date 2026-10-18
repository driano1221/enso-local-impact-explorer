# Three.js no globo didático

Runtime oficial Three.js **0.180.0 / r180**, licença MIT preservada. Arquivos obtidos do repositório [mrdoob/three.js](https://github.com/mrdoob/three.js/tree/r180/build); URLs, tamanhos e SHA-256 em `provenance.json`. Nenhum hook ou instalador foi executado.

`terra.js` usa WebGL2 para um globo original, com iluminação, contornos Natural Earth, suporte físico ilustrativo e setas. O globo usa Three.js; o corte do oceano continua usando Anatomy. Duas bibliotecas têm papéis distintos e créditos próprios. Não é uma figura pronta de nenhum catálogo.

Os dois módulos somam 720.032 bytes sem compressão. A geografia local tem 96.417 bytes. As texturas são desenhadas dos polígonos no navegador, sem imagens de satélite ou dependência de CDN durante o uso. O código renderiza sob demanda, limita a densidade de pixels a 2, respeita movimento reduzido e interrompe animação fora da tela. A variação térmica é um parâmetro ilustrativo no shader, sem temperaturas, datas ou dados meteorológicos.

O módulo é carregado sob proteção: indisponibilidade do recurso WebGL ou perda de contexto abre o corte Anatomy, conserva a fase e mostra uma explicação. `qa.html` oferece uma simulação explícita para desenvolvimento. O teste automatizado `node scripts/testar_terra.mjs` verifica a convenção de latitude/longitude contra a malha real da biblioteca, foco geográfico, direção dos ventos e integridade dos arquivos. Inspeção visual e teste humano continuam necessários.
