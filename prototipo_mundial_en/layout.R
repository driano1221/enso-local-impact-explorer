paises <- indice[!duplicated(indice$pais_iso2),c("pais_iso2","pais")]; paises <- paises[order(paises$pais), ]
paises$pais <- mapply(nome_pais,paises$pais_iso2,paises$pais); paises <- paises[order(paises$pais), ]
filtro_rotulo <- function(texto,tipo) {
  desenho <- switch(tipo,globe='<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c5 5 5 13 0 18M12 3c-5 5-5 13 0 18"/>',
    pin='<path d="M19 10c0 6-7 11-7 11S5 16 5 10a7 7 0 1 1 14 0Z"/><circle cx="12" cy="10" r="2"/>',
    metric='<path d="M10 14V5a2 2 0 0 1 4 0v9a4 4 0 1 1-4 0Z"/><path d="M12 8v9"/>',
    calendar='<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M7 2v6m10-6v6M3 11h18"/>')
  tags$span(class="filtro-rotulo",HTML(paste0('<svg viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="1.5">',desenho,'</svg>')),texto,
    if(tipo=="calendar") ajuda_info("epoca", "About the time-of-year periods", "We use four standard three-month climate periods: Dec–Feb, Mar–May, Jun–Aug and Sep–Nov. This compares the same months across years. Seasons differ between hemispheres and regions; the months here stay fixed. In Dec–Feb, December is assigned to the following year."))
}
ajuda_info <- function(id,rotulo,texto) tags$span(class="ajuda-info",
  tags$button(type="button",class="ajuda-botao",`aria-label`=rotulo,`aria-describedby`=paste0("ajuda-",id),`aria-expanded`="false","i"),
  tags$span(id=paste0("ajuda-",id),class="ajuda-texto",role="tooltip",texto))
ajuda_fonte <- function(fonte,local="valor") {
  texto <- if(fonte=="POWER") "A NASA source providing historical temperature and rainfall estimates on a geographic grid. We query the cell near the selected location." else "A reconstruction of past climate by ECMWF/Copernicus, combining observations and weather models. Here we use ERA5 via Open-Meteo, in the cell near the selected location."
  ajuda_info(paste0(tolower(fonte),"-",local),paste("About",fonte),texto)
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
ui <- page_fluid(title="ENSO Local · World", lang="en",
  theme=bs_theme(version=5,bg="#edf2f4",fg=cor_estrutura,primary=cor_principal,
    base_font="Source Sans 3, system-ui, sans-serif"),
  tags$head(
    tags$link(rel="stylesheet",href="mundial.css"),
    tags$link(rel="stylesheet",href="consulta-diagrama.css?v=oceano2"),
    tags$link(rel="stylesheet",href="redesign.css?v=oceano2"),
    tags$link(rel="stylesheet",href="preferencias.css?v=abertura5"),
    tags$link(rel="stylesheet",href="refino.css?v=altas1"),
    tags$script(src="preferencias.js?v=r14-final"),tags$script(src="consulta.js?v=r14-final"),tags$link(rel="stylesheet",href="consulta.css?v=medias1"),
    tags$script(src="aprovado/atlas.js"),tags$script(src="mundial.js?v=altas1"),
    tags$script(src="aprovado/figura-frame.js")),
  tags$a(class="pular",href="#consulta","Skip to exploration"),
  tags$div(class="app-shell",
    tags$header(class="atlas-masthead",
      tags$a(class="identidade",href="#consulta",tags$img(src="marca.svg",alt="",width=40,height=40),tags$div(class="marca","enso",tags$span("local"))),
      tags$p(class="atlas-edicao","Local climate observatory",tags$span("Historical records · 1981–2025")),
      tags$nav(`aria-label`="Dashboard sections",tags$a(class="nav-editorial",href="#entender","Understand the data ↘"),tags$a(class="nav-editorial",href="#sobre-projeto","About the project"),
        tags$button(type="button",class="tema-botao",`aria-label`="Switch to dark theme",`aria-pressed`="false",`data-theme-toggle`="",HTML('<svg viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="1.6"><path class="tema-lua" d="M20 15A9 9 0 0 1 9 4a8 8 0 1 0 11 11Z"/><g class="tema-sol"><circle cx="12" cy="12" r="4"/><path d="M12 2v3m0 14v3M2 12h3m14 0h3M5 5l2 2m10 10 2 2M5 19l2-2M17 7l2-2"/></g></svg>')),
        tags$div(class="idioma-controle",role="group",`aria-label`="Language",
          tags$button(type="button",`data-language`="pt",`aria-label`="Português (Brasil)","PT-BR"),tags$button(type="button",`data-language`="en",`aria-label`="English","EN")))),
    tags$main(id="consulta",
      tags$section(class="abertura",`aria-label`="About this query",
        tags$h1("Your local climate, in perspective."),
        tags$p(class="abertura-proposta","Choose a place and see how temperature and rainfall changed from 1981 to 2025. Compare NASA POWER and ERA5, inspect each year and download the data."),
        tags$div(class="abertura-acoes",
          tags$a(class="atalho-ia",href="#enso-assistente",tags$span(class="selo-ia","AI"),"Ask about the chart",tags$span(`aria-hidden`="true","↗")),
          tags$a(href="#entender","Explore El Niño and La Niña ↘"),
          tags$a(href="#verificar-dados","Verify data · Stellar Testnet ↗")),
        tags$p(class="abertura-enso","El Niño and La Niña are phases of ENSO, a natural variation in the Pacific Ocean and atmosphere. Explore local history and understand the limits of this comparison.")),
      tags$p(id="consulta-feedback",class="consulta-feedback",role="status",`aria-live`="polite","Data for the selected query"),
      tags$div(class="consulta-toolbar", tags$section(class="filtros",
        selectInput("pais",filtro_rotulo("Country / territory","globe"),setNames(paises$pais_iso2,paises$pais),selected="BR",selectize=FALSE),
        selectInput("cidade",filtro_rotulo("Location","pin"),setNames(indice$id[indice$pais_iso2=="BR"],indice$cidade[indice$pais_iso2=="BR"]),selected="WUP-7802",selectize=FALSE),
        selectInput("variavel",filtro_rotulo("Measure","metric"),c("Temperature"="temperatura_c","Rainfall"="precipitacao_mm_mes"),selectize=FALSE),
        selectInput("estacao",filtro_rotulo("Time of year","calendar"),c("Sep–Nov"="SON","Dec–Feb"="DJF","Mar–May"="MAM","Jun–Aug"="JJA"),selectize=FALSE)),
      tags$div(class="cabecalho-consulta",uiOutput("disponibilidade"),
        tags$details(class="exportacoes",tags$summary(icone_painel("baixar"),"Download data ↓"),downloadLink("serie_csv","Chart data · CSV"),downloadLink("mensal_csv","Monthly data · CSV"),downloadLink("ficha_txt","Query factsheet · TXT")))),
      tags$div(class="exploracao",
        tags$section(class="geografia",
          uiOutput("contexto"),
          tags$details(class="localizacao-expandivel",open=NA,
          tags$summary(icone_painel("globo"),"Explore location"),
          tags$div(class="localizacao-conteudo",
          tags$div(class="mapa-barra",tags$h2("Location"),tags$div(class="mapa-acoes",
            tags$button(type="button",`data-map-view`="globe",`aria-pressed`="true",icone_painel("globo"),"Globe"))),
          tags$div(class="mapa-estatico",tags$div(id="globo-local",hidden=NA),tags$div(id="localizador"),uiOutput("local_mapa")),
          tags$p(class="nota mapa-nota","Drag the globe and select a point to explore another city. Estimates describe grid cells, not individual neighbourhoods.")))),
        tags$section(class="serie",tags$div(class="painel-metrica",uiOutput("resumo_valor")),
          tags$div(class="grafico-cabecalho",tags$h3("Through the years"),
            radioButtons("escala","Chart scale",c("Value in °C or mm"="valor","Difference from average"="diferenca"),inline=TRUE)),
          uiOutput("legenda"),
          tags$p(class="nota fonte-credito",tags$a(href="https://open-meteo.com/",target="_blank",rel="noopener","ERA5 via Open-Meteo")," · ",tags$a(href="https://creativecommons.org/licenses/by/4.0/",target="_blank",rel="noopener","CC BY 4.0")),
          plotlyOutput("historico",height="260px"),
          tags$div(class="inspecao",tags$label(`for`="ano-inspecao","Inspect a year"),tags$select(id="ano-inspecao",`aria-describedby`="ano-valores"),
            tags$div(id="ano-valores",role="status",`aria-live`="polite")),
          tags$details(class="explica-escala",tags$summary("Understanding the difference from average"),
            tags$p("The seasonal value minus the average for the same months in 1991–2020, calculated separately for each source. A zero difference means the seasonal value equals its reference."))),
        tags$aside(class="indicadores",`aria-label`="Historical indicators",uiOutput("comparacao_destaque"),uiOutput("indicadores"),
          tags$section(class="distribuicao",tags$h2("Distribution of years"),uiOutput("distribuicao_subtitulo"),
            plotlyOutput("distribuicao",height="140px"),
            tags$p(class="nota","Each point is a season. Box: middle 50%; line: median; dashed line: reference.")))),
      tags$section(class="evidencia",tags$div(class="evidencia-titulo",tags$h2("Local summary"),tags$p("What the historical record can tell us")),uiOutput("resumo_local")),
      tags$div(class="detalhes",id="entender",navset_tab(
        nav_panel("Understanding ENSO",icon=icone_painel("ondas"),tags$iframe(`data-src`="enso-payload.json",title="How the Pacific changes",loading="lazy",class="pacifico-frame")),
        nav_panel("Reading this query",icon=icone_painel("leitura"),tags$div(class="documentacao",
          tags$h2("From a point on the map to its history"),
          includeHTML("www/consulta-diagrama.html"),
          tags$details(tags$summary("How we calculate the values"),
            tags$p("Temperature: the equally weighted average of three monthly means. Rainfall: the sum of three monthly totals. Each source has its own 1991–2020 reference."),
            tags$p("We compare the same years using the mean absolute difference: positive and negative differences do not cancel out. Agreement does not establish accuracy; a local station provides additional evidence.")),
          tags$details(tags$summary("Limits of this interpretation"),tags$p("Global ENSO associations await statistical validation. These records do not predict the next season or prove that the Pacific caused a local change. ONI and RONI are centred three-month indices and include the month after the central month.")))),
        nav_panel("Sources and coverage",icon=icone_painel("fontes"),tags$div(class="documentacao",tags$h2("Where the data come from"),uiOutput("fontes"),
          uiOutput("cobertura_local"),
          tags$p(paste("The selection of the largest cities is still under review in",sum(cobertura$pendencia_ranking=="complementacao_nacional_necessaria",na.rm=TRUE),"countries or territories. Available points can be explored; this list does not yet include every capital and the three largest cities in every country.")))))),
      tags$section(id="sobre-projeto",class="documentacao sobre-projeto",tags$h2("About ENSO Local"),tags$p("For students, educators and analysts exploring local climate, comparing sources and taking verifiable records into their own analyses."),tags$p("Climate Data & Environmental Monitoring · IEEE ClimateChain Global Hackathon"),tags$p(tags$a(href="https://github.com/driano1221/enso-local-impact-explorer",target="_blank",rel="noopener","GitHub · code and documentation ↗")," · ",tags$a(href="#verificar-dados","Verify data ↗"))),
      tags$footer(class="rodape",id="creditos",
        tags$div(tags$p(class="rodape-titulo","Every place has a climate.",tags$em(" A connection to the Pacific.")),tags$p("ENSO Local · Adriano Pires Cunha · Exploratory research")),
        tags$div(tags$p(paste(nrow(indice),"locations · POWER:",nrow(indice),"· ERA5:",sum(tolower(indice$era5_disponivel)=="true"))),
          tags$details(tags$summary("Visual credits"),tags$p("Cartography: Natural Earth · IBGE in the pilot. Illustrative globe, without live clouds or weather: ",tags$a(href="https://www.solarsystemscope.com/textures/",target="_blank",rel="noopener","Solar System Scope")," / CC BY 4.0, texture via Three.js r180. Flags: flag-icons / MIT. Source Sans 3: Adobe / SIL OFL. Charts: Plotly / MIT.")))))))
