# Integridade pública — Stellar Testnet

**Atualização final — 19/10/2026:** o [manifesto completo da release r7](release_r7/README.md) foi ancorado na [Stellar Testnet](https://horizon-testnet.stellar.org/transactions/162206069078f8696f99a19dbbb26c5a83780c198f620ff88ccf79cb82ab10c2), cobrindo seus 3.301 arquivos listados. Teste real da release e adulterações passou; zero custo real, pacote e visual preservados. Recibo/prova disponíveis como anexos separados da [release](https://github.com/driano1221/enso-local-impact-explorer/releases/tag/v0.2.0-preview.684). Os blocos abaixo descrevem a demonstração histórica de dois exports, que permanece preservada e distinta da prova r7. Integridade não certifica exatidão climática; Testnet pode reiniciar.

Implementado e consultado na rede em 17/10/2026. Nenhum custo em dinheiro real; nenhum recurso visual ou modelo climático alterado. Esta demonstração cobre **dois downloads congelados**, não todos os dados mundiais nem a versão final de entrega.

## Registro verificável

- Transação: [`b8c1c116925fa4e2f6affcbe544d91d0f408275ca022a26f848b875098102a26`](https://horizon-testnet.stellar.org/transactions/b8c1c116925fa4e2f6affcbe544d91d0f408275ca022a26f848b875098102a26).
- Conta pública: `GCVEOSSRF2CMDYBANGWIY5NMPU6NUR2M6WAJ5NTCKGEUNI7RWAJIJIZE`.
- Rede: Stellar Testnet; passphrase `Test SDF Network ; September 2015`.
- Network ID: `cee0302d59844d32bdca915c8203dd44b33fbb7edc19051ea37abedf28ecd472`.
- Ledger: **5236935**, fechado em **17/10/2026 03:37:42 UTC / 00:37:42 Brasília**.
- SHA-256 do manifesto: `0a430dcc5cc67b22586be945ad08993329bf3a6a2aeb46d2304b87e4556e864e`.
- Operação nativa `ManageData`, nome `enso-manifest-sha256`, com o digest de 32 bytes; memo hash contém o mesmo digest. **Não há smart contract personalizado.**
- Taxa: 100 stroops = 0,00001 XLM **fictício**, obtido pelo Friendbot. Gasto real: zero. Chave efêmera gerada em memória, nunca gravada ou impressa; não foi usada carteira do usuário.

## O que está protegido

`demo/manifest.json` lista nome, tamanho e SHA-256 dos arquivos:

1. `vicosa_son_chart_en.csv`: 90 linhas históricas, temperatura SON de Viçosa, POWER e ERA5, exportadas do painel inglês.
2. `encamp_djf_factsheet_en.txt`: ficha de chuva DJF de Encamp, com disponibilidade de fonte e limites científicos.

São cópias idênticas aos downloads em `competicao/evidencias/ingles_20261017/`. O manifesto vincula os bytes desses arquivos à transação. Somente o digest vai para a cadeia; os dados permanecem fora dela. Campos de data/procedência escritos no manifesto são declarações do pacote: o tempo confirmado pela rede é o fechamento do ledger, não a data de aquisição meteorológica.

**Exemplo real do teste:** trocar `20.702078853046594` por `21.702078853046594` no CSV altera um byte. A cópia foi rejeitada. Reescrever o manifesto com o novo hash também foi rejeitado frente à transação original. O original foi aceito. Uma transação inexistente retornou HTTP 404, nunca sucesso.

Isso demonstra correspondência byte a byte com o compromisso registrado, sob as propriedades do SHA-256 e a confiança na rede/API consultada. Não demonstra exatidão da NASA/ERA5, autoria ou identidade civil, causalidade ENSO, previsão, nem que toda atualização futura do painel esteja registrada. Até mudar a formatação do CSV muda seu hash. Um arquivo alterado pode ser registrado em **outra** transação; por isso o identificador original deve ser publicado e preservado fora do pacote substituível.

## Reproduzir sem gastar dinheiro

Com Python 3.11, a partir da raiz do projeto (PowerShell):

```powershell
python -m venv .venv-integridade
& .venv-integridade/Scripts/python.exe -m pip install -r integridade/requirements-lock.txt
& .venv-integridade/Scripts/python.exe -m unittest discover -s integridade -p 'test_verificar.py' -v
& .venv-integridade/Scripts/python.exe integridade/test_live.py
& .venv-integridade/Scripts/python.exe integridade/verificar.py verify integridade/demo/manifest.json --transaction b8c1c116925fa4e2f6affcbe544d91d0f408275ca022a26f848b875098102a26 --account GCVEOSSRF2CMDYBANGWIY5NMPU6NUR2M6WAJ5NTCKGEUNI7RWAJIJIZE
```

Os três últimos comandos não criam transações. O teste online usa pasta temporária para adulterar uma cópia e atualiza apenas `demo/live_check.json`. Sem acesso à rede, informa falha; o recibo local sozinho não substitui confirmação online.

Para um **novo pacote público congelado**, preparar um manifesto no mesmo formato, com caminhos relativos confinados à pasta, bytes e SHA-256 calculados dos arquivos finais. Usar caminho novo para o recibo:

```powershell
& .venv-integridade/Scripts/python.exe integridade/verificar.py anchor caminho/manifest.json caminho/receipt.json
```

Esse comando cria uma conta com saldo fictício e registra o hash somente na Testnet. Não execute novamente para a demonstração já registrada. Antes do envio salva `receipt.pending.json` com o ID e envelope assinado, sem chave secreta. Em timeout, consultar esse ID com `verify`; não gerar outra ancoragem presumindo que a primeira falhou. Um arquivo pending preservado ao lado do recibo confirmado é o registro anterior ao envio, não sinal de que ainda esteja pendente na rede. A existência desses arquivos bloqueia repetição acidental. Se o financiamento falhar antes dessa etapa, não há envio do manifesto.

## Evidências, limitações e publicação

- [Recibo confirmado](demo/receipt.json), [consulta online e teste de adulteração](demo/live_check.json), [preservação de 310 arquivos aprovados](demo/preservation.json).
- 12 testes locais: original, adulteração, manifesto reescrito, rede/conta incorretas, falha/ausência de confirmação, ID/envelope/operação/assinatura, caminho fora do pacote, timeout/404, proteção de recibo e repetição. Falhas de conexão aconteceram durante preparação; nenhum sucesso foi declarado antes da confirmação.
- O verificador checa assinatura/envelope/operação e consulta Horizon por HTTPS. **Não opera um nó próprio nem verifica consenso independentemente**; o status de inclusão e horário confiam na API pública da rede. O recibo é evidência arquivada, não uma prova independente de consenso.
- A [Testnet é gratuita e reinicia periodicamente](https://developers.stellar.org/docs/networks); o registro não deve ser vendido como certificação permanente. O [endpoint Friendbot Testnet](https://developers.stellar.org/docs/data/apis/rpc/api-reference/methods/getNetwork) documentado funcionou após resets de conexão no outro hostname oficial. Não houve bypass de TLS ou de limites.
- Na publicação final: congelar o pacote que será entregue, gerar seu manifesto, registrar essa versão e publicar ID/conta junto ao repositório e vídeo. Conferir a disponibilidade antes da demonstração. Não substituir silenciosamente o exemplo atual.

## English summary for judges

We anchor the SHA-256 digest of a manifest containing two frozen public dashboard exports on **Stellar Testnet**. A confirmed native ManageData transaction and hash memo commit to that exact digest. The verifier checks the local files, manifest, expected transaction ID, public account, test network, signature and confirmed successful transaction. The original bundle passes; a one-byte change and a rewritten manifest fail. This is an implemented blockchain integrity proof, not a custom smart contract or AI feature. It does not validate climate science, identity, causality or prediction. Only the digest is on-chain. Testnet uses free fake XLM and periodically resets; confirmation relies on the public Horizon API. The final release needs its own frozen manifest and anchor.
