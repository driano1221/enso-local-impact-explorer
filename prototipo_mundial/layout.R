paises <- indice[!duplicated(indice$pais_iso2),c("pais_iso2","pais")]; paises <- paises[order(paises$pais), ]
paises$pais <- mapply(nome_pais,paises$pais_iso2,paises$pais); paises <- paises[order(paises$pais), ]
filtro_rotulo <- function(texto,tipo) {
  desenho <- switch(tipo,globe='<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c5 5 5 13 0 18M12 3c-5 5-5 13 0 18"/>',
    pin='<path d="M19 10c0 6-7 11-7 11S5 16 5 10a7 7 0 1 1 14 0Z"/><circle cx="12" cy="10" r="2"/>',
    metric='<path d="M10 14V5a2 2 0 0 1 4 0v9a4 4 0 1 1-4 0Z"/><path d="M12 8v9"/>',
    calendar='<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M7 2v6m10-6v6M3 11h18"/>')
  tags$span(class="filtro-rotulo",HTML(paste0('<svg viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="1.5">',desenho,'</svg>')),texto,
    if(tipo=="calendar") ajuda_info("epoca", "Sobre as épocas do ano", "Usamos quatro trimestres climatológicos: dez–fev, mar–mai, jun–ago e set–nov. Assim comparamos os mesmos meses entre anos. As estações variam entre hemisférios e regiões; aqui os meses são fixos. Em dez–fev, dezembro pertence ao ano seguinte."))
}
ajuda_info <- function(id,rotulo,texto) tags$span(class="ajuda-info",
  tags$button(type="button",class="ajuda-botao",`aria-label`=rotulo,`aria-describedby`=paste0("ajuda-",id),`aria-expanded`="false","i"),
  tags$span(id=paste0("ajuda-",id),class="ajuda-texto",role="tooltip",texto))
ajuda_fonte <- function(fonte,local="valor") {
  texto <- if(fonte=="POWER") "Fonte da NASA que disponibiliza estimativas históricas de temperatura e chuva em uma grade geográfica. Aqui consultamos a célula próxima ao local escolhido." else "Reconstrução do clima do ECMWF/Copernicus, que combina observações e modelos meteorológicos. Aqui usamos ERA5 via Open-Meteo, na célula próxima ao local escolhido."
  ajuda_info(paste0(tolower(fonte),"-",local),paste("Sobre",fonte),texto)
}
icone_resumo <- function(tipo) {
  desenho <- switch(tipo,documento='<path d="M6 3h9l4 4v14H6zM14 3v5h5M9 12h7M9 15h7M9 18h4"/>',
    comparacao='<circle cx="10" cy="10" r="7"/><path d="m15 15 6 6M10 6v5l3 2"/>',
    pessoa='<circle cx="12" cy="6" r="3"/><path d="M8 10c-3 1-4 4-4 10h16c0-6-1-9-4-10M12 13v5"/>')
  HTML(paste0('<svg class="resumo-icone" viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">',desenho,'</svg>'))
}
icone_painel <- function(tipo) {
  desenho <- switch(tipo,
    ondas='<path d="M3 8c3-4 6-4 9 0s6 4 9 0M3 14c3-4 6-4 9 0s6 4 9 0M3 20c3-4 6-4 9 0s6 4 9 0"/>',
    leitura='<path d="M12 5C8 2 4 3 2 4v15c3-1 7-1 10 1 3-2 7-2 10-1V4c-2-1-6-2-10 1Zm0 0v15M5 7l4 1M5 11l4 1M15 8l4-1M15 12l4-1"/>',
    fontes='<ellipse cx="12" cy="5" rx="8" ry="3"/><path d="M4 5v7c0 4 16 4 16 0V5M4 12v7c0 4 16 4 16 0v-7"/>',
    globo='<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c5 5 5 13 0 18M12 3c-5 5-5 13 0 18"/>',
    regiao='<path d="m3 5 6-2 6 2 6-2v16l-6 2-6-2-6 2Zm6-2v16m6-14v16"/>',
    baixar='<path d="M12 3v12m-5-5 5 5 5-5M4 16v5h16v-5"/>')
  tags$svg(class="icone-painel",viewBox="0 0 24 24",`aria-hidden`="true",focusable="false",fill="none",stroke="currentColor",`stroke-width`="1.5",`stroke-linecap`="round",`stroke-linejoin`="round",HTML(desenho))
}
ui <- page_fluid(title="ENSO Local · Mundo", lang="pt-BR",
  theme=bs_theme(version=5,bg="#edf2f4",fg=cor_estrutura,primary=cor_principal,
    base_font="Source Sans 3, system-ui, sans-serif"),
  tags$head(
    tags$link(rel="stylesheet",href="mundial.css"),
    tags$link(rel="stylesheet",href="consulta-diagrama.css?v=oceano2"),
    tags$link(rel="stylesheet",href="redesign.css?v=oceano2"),
    tags$link(rel="stylesheet",href="preferencias.css?v=abertura5"),
    tags$link(rel="stylesheet",href="refino.css?v=altas1"),
    tags$script(src="preferencias.js?v=abertura5"),tags$script(src="consulta.js?v=medias1"),tags$link(rel="stylesheet",href="consulta.css?v=medias1"),
    tags$script(src="aprovado/atlas.js"),tags$script(src="mundial.js?v=altas1"),
    tags$script(src="aprovado/figura-frame.js")),
  tags$a(class="pular",href="#consulta","Ir à exploração"),
  tags$div(class="app-shell",
    tags$header(class="atlas-masthead",
      tags$a(class="identidade",href="#consulta",tags$img(src="marca.svg",alt="",width=40,height=40),tags$div(class="marca","enso",tags$span("local"))),
      tags$p(class="atlas-edicao","Observatório do clima local",tags$span("Histórico · 1981–2025")),
      tags$nav(`aria-label`="Seções do atlas",tags$a(class="nav-editorial",href="#entender","Entenda os dados ↘"),tags$a(class="nav-editorial",href="#creditos","Sobre o projeto"),
        tags$button(type="button",class="tema-botao",`aria-label`="Ativar tema escuro",`aria-pressed`="false",`data-theme-toggle`="",HTML('<svg viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="1.6"><path class="tema-lua" d="M20 15A9 9 0 0 1 9 4a8 8 0 1 0 11 11Z"/><g class="tema-sol"><circle cx="12" cy="12" r="4"/><path d="M12 2v3m0 14v3M2 12h3m14 0h3M5 5l2 2m10 10 2 2M5 19l2-2M17 7l2-2"/></g></svg>')),
        tags$div(class="idioma-controle",role="group",`aria-label`="Idioma",
          tags$button(type="button",`data-language`="pt",`aria-label`="Português (Brasil)","PT-BR"),tags$button(type="button",`data-language`="en",`aria-label`="English","EN")))),
    tags$main(id="consulta",
      tags$section(class="abertura",`aria-label`="Sobre esta consulta",
        tags$h1("O clima da sua cidade, em perspectiva."),
        tags$p(class="abertura-proposta","Escolha um lugar e veja como a temperatura e a chuva variaram de 1981 a 2025. Compare NASA POWER e ERA5, consulte cada ano e leve os dados com você."),
        tags$div(class="abertura-acoes",
          tags$a(class="atalho-ia",href="#enso-assistente",tags$span(class="selo-ia","IA"),"Pergunte sobre o gráfico",tags$span(`aria-hidden`="true","↗")),
          tags$a(href="#entender","Explore El Niño e La Niña ↘")),
        tags$p(class="abertura-enso","El Niño e La Niña são fases do ENSO, uma variação natural do oceano e da atmosfera no Pacífico. Aqui você explora o histórico local e entende os limites dessa comparação.")),
      tags$p(id="consulta-feedback",class="consulta-feedback",role="status",`aria-live`="polite","Dados do recorte selecionado"),
      tags$div(class="consulta-toolbar", tags$section(class="filtros",
        selectInput("pais",filtro_rotulo("País / território","globe"),setNames(paises$pais_iso2,paises$pais),selected="BR",selectize=FALSE),
        selectInput("cidade",filtro_rotulo("Localidade","pin"),setNames(indice$id[indice$pais_iso2=="BR"],indice$cidade[indice$pais_iso2=="BR"]),selected="GN-3445133",selectize=FALSE),
        selectInput("variavel",filtro_rotulo("Medida","metric"),c("Temperatura"="temperatura_c","Chuva"="precipitacao_mm_mes"),selectize=FALSE),
        selectInput("estacao",filtro_rotulo("Época do ano","calendar"),c("Set–nov"="SON","Dez–fev"="DJF","Mar–mai"="MAM","Jun–ago"="JJA"),selectize=FALSE)),
      tags$div(class="cabecalho-consulta",uiOutput("disponibilidade"),
        tags$details(class="exportacoes",tags$summary(icone_painel("baixar"),"Baixar dados ↓"),downloadLink("serie_csv","Série do gráfico · CSV"),downloadLink("mensal_csv","Dados mensais · CSV"),downloadLink("ficha_txt","Ficha da consulta · TXT")))),
      tags$div(class="exploracao",
        tags$section(class="geografia",
          uiOutput("contexto"),
          tags$details(class="localizacao-expandivel",open=NA,
          tags$summary(icone_painel("globo"),"Explorar localização"),
          tags$div(class="localizacao-conteudo",
          tags$div(class="mapa-barra",tags$h2("Localização"),tags$div(class="mapa-acoes",
            tags$button(type="button",`data-map-view`="globe",`aria-pressed`="true",icone_painel("globo"),"Globo"))),
          tags$div(class="mapa-estatico",tags$div(id="globo-local",hidden=NA),tags$div(id="localizador"),uiOutput("local_mapa")),
          tags$p(class="nota mapa-nota","Arraste o globo e toque em um ponto para consultar outra cidade. Estimativas de grade, não de cada bairro.")))),
        tags$section(class="serie",tags$div(class="painel-metrica",uiOutput("resumo_valor")),
          tags$div(class="grafico-cabecalho",tags$h3("Ao longo dos anos"),
            radioButtons("escala","Escala do gráfico",c("Valor em °C ou mm"="valor","Diferença da média"="diferenca"),inline=TRUE)),
          uiOutput("legenda"),
          tags$p(class="nota fonte-credito",tags$a(href="https://open-meteo.com/",target="_blank",rel="noopener","ERA5 via Open-Meteo")," · ",tags$a(href="https://creativecommons.org/licenses/by/4.0/",target="_blank",rel="noopener","CC BY 4.0")),
          plotlyOutput("historico",height="260px"),
          tags$div(class="inspecao",tags$label(`for`="ano-inspecao","Consultar um ano"),tags$select(id="ano-inspecao",`aria-describedby`="ano-valores"),
            tags$div(id="ano-valores",role="status",`aria-live`="polite")),
          tags$details(class="explica-escala",tags$summary("Entender a diferença da média"),
            tags$p("Valor do trimestre menos a média dos mesmos meses em 1991–2020, calculada separadamente para cada fonte. Diferença zero significa um valor igual à referência, não temperatura de 0 °C."))),
        tags$aside(class="indicadores",`aria-label`="Indicadores históricos",uiOutput("comparacao_destaque"),uiOutput("indicadores"),
          tags$section(class="distribuicao",tags$h2("Distribuição dos anos"),uiOutput("distribuicao_subtitulo"),
            plotlyOutput("distribuicao",height="140px"),
            tags$p(class="nota","Cada ponto é uma temporada. Caixa: 50% central; traço: mediana; tracejado: referência.")))),
      tags$section(class="evidencia",tags$div(class="evidencia-titulo",tags$h2("Resumo da consulta"),tags$p("O que o histórico permite dizer")),uiOutput("resumo_local")),
      tags$div(class="detalhes",id="entender",navset_tab(
        nav_panel("Entender o ENSO",icon=icone_painel("ondas"),tags$iframe(`data-src`="enso-payload.json",title="Como o Pacífico muda",loading="lazy",class="pacifico-frame")),
        nav_panel("Como ler esta consulta",icon=icone_painel("leitura"),tags$div(class="documentacao",
          tags$h2("Do ponto no mapa ao histórico"),
          includeHTML("www/consulta-diagrama.html"),
          tags$details(tags$summary("Como fazemos as contas"),
            tags$p("Temperatura: média das três médias mensais, com pesos iguais. Chuva: soma dos três meses. Cada fonte tem sua própria referência de 1991–2020."),
            tags$p("A comparação entre fontes usa os mesmos anos e a média das diferenças absolutas: valores positivos e negativos não se cancelam. Concordância não comprova precisão; uma estação local é outra evidência.")),
          tags$details(tags$summary("Limites desta leitura"),tags$p("As associações mundiais com ENSO aguardam validação estatística. Este histórico não prevê o próximo trimestre, nem prova que o Pacífico causou uma mudança local. ONI e RONI são índices centrados de três meses e incluem o mês seguinte ao mês central.")))),
        nav_panel("Fontes e cobertura",icon=icone_painel("fontes"),tags$div(class="documentacao",tags$h2("De onde vêm os dados"),uiOutput("fontes"),
          uiOutput("cobertura_local"),
          tags$p(paste("O catálogo mundial ainda tem",sum(cobertura$pendencia_ranking=="complementacao_nacional_necessaria",na.rm=TRUE),"pendências territoriais ou populacionais. As localidades exibidas já foram aprovadas para aquisição; isso não implica que o top 3 de todos os países esteja concluído.")))))),
      tags$footer(class="rodape",id="creditos",
        tags$div(tags$p(class="rodape-titulo","O clima de cada lugar.",tags$em(" A conexão com o Pacífico.")),tags$p("ENSO Local · Adriano Pires Cunha · Pesquisa exploratória")),
        tags$div(tags$p(paste(nrow(indice),"pontos · POWER em todos · ERA5 em",sum(tolower(indice$era5_disponivel)=="true"))),
          tags$details(tags$summary("Créditos visuais"),tags$p("Cartografia: Natural Earth · IBGE no piloto. Globo ilustrativo, sem nuvens ou clima atual: ",tags$a(href="https://www.solarsystemscope.com/textures/",target="_blank",rel="noopener","Solar System Scope")," / CC BY 4.0, textura via Three.js r180. Bandeiras: flag-icons / MIT. Source Sans 3: Adobe / SIL OFL. Gráficos: Plotly / MIT.")))))))
