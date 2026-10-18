# Anatomy no ENSO Local

Código de `kit/iso-kit.mjs` do [Anatomy](https://github.com/wheresryan22/anatomy), commit `e6600ffc4e8e6620eeb45bf49bcdbd5e4b84163f`, consultado em 13/10/2026. Licença MIT preservada em `LICENSE`. O conteúdo é idêntico; a extensão local `.js` permite ao servidor Shiny enviá-lo como JavaScript, pois sua configuração atual serve `.mjs` como octet-stream.

Uso real: projeção, enquadramento, prismas, cilindros, extrusões, chanfros, sombras por face, texto sobre face e emissão de SVG. `pacifico-model.js` constrói um modelo didático original de ENSO usando essa API; não é uma figura pronta do catálogo do Anatomy. O exemplo `ripple-tank` orientou o acabamento, sem importar sua física de ondulações, que não modela ENSO.

Não há React, serviço externo, instalação de skill, WebGL obrigatório ou telemetria. O módulo (35.175 bytes) é servido localmente. O SVG é calculado a partir de coordenadas 3D; a câmera é fixa. Os parâmetros de camada, cor e seta são qualitativos, sem unidade física e sem dados climáticos medidos. A figura não representa geografia real nem prevê uma cidade.

Validação: `node scripts/testar_pacifico.mjs` na raiz verifica integridade do kit/mapa aprovado, limites geométricos e 909 estados de transição. Isso não é a auditoria completa de sólidos do Anatomy; revisão visual em navegador complementa os checks. Fontes científicas e registro de integração em `competicao/INTERFACE_PILOTO.md`.

A evolução seguinte acrescenta um globo Three.js em `terra.js`, enquanto este módulo continua responsável pelo corte. O globo tem uma dependência WebGL2 opcional; se ela falhar, o corte permanece disponível. Créditos e arquivos das bibliotecas permanecem separados.
