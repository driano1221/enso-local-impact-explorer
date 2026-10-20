if (.Platform$OS.type == "windows") Sys.setlocale("LC_ALL", "English_United States.utf8")
library(shiny)
library(bslib)
library(dplyr)
library(readr)
app_dir <- normalizePath(".",winslash="/")
source("../R/tema_vault.R", encoding="UTF-8", local=TRUE)
source("../R/validar_piloto.R", encoding="UTF-8", local=TRUE)
source("../R/ler_mundial.R", encoding="UTF-8", local=TRUE)
source("../prototipo_revisado/explorador.R", encoding="UTF-8", local=TRUE)
source("comparacao_en.R", encoding="UTF-8", local=TRUE)
addResourcePath("aprovado", normalizePath("www/aprovado-en"))
indice <- read.csv("../dados/mundial/integracao/pontos.csv", na.strings="", fileEncoding="UTF-8")
cobertura <- read.csv("../dados/mundial/cobertura_catalogo.csv", na.strings="", fileEncoding="UTF-8")
nomes_paises <- list()
nome_pais <- function(iso, original) if (!is.null(nomes_paises[[iso]])) nomes_paises[[iso]] else original
num <- function(x, n=1, sinal=FALSE) formatC(x, digits=n, format="f", decimal.mark=".", flag=if(sinal) "+" else "")
rotulos_estacao <- c(SON="September to November", DJF="December to February", MAM="March to May", JJA="June to August")
series_mundiais <- function(x, epoca, v) {
  d <- preparar_sazonal(x$mensal)
  bind_rows(lapply(unique(d$fonte), function(f) {
    serie_temporadas(d[d$fonte==f & d$estacao==epoca, ], v) |> mutate(fonte=f)
  }))
}
exportar_mundial <- function(x, epoca, v) {
  series_mundiais(x, epoca, v) |> mutate(id=x$ponto$id, cidade=x$ponto$cidade,
    pais=x$ponto$pais, estacao=epoca, variavel=v, unidade=unidade_grafico(v),
    referencia_periodo="1991-2020", interpretacao="Descriptive historical records; not a forecast or an ENSO effect",
    latitude=x$ponto$latitude, longitude=x$ponto$longitude) |>
    left_join(x$fontes, by=c("id", "fonte"))
}
comparar_mundial <- function(a) {
  if (!all(c("POWER","ERA5") %in% a$fonte)) return(NULL)
  stopifnot(!anyDuplicated(a[c("fonte","ano_sazonal")]))
  p <- a[a$fonte=="POWER",c("ano_sazonal","valor")]
  e <- a[a$fonte=="ERA5",c("ano_sazonal","valor")]
  stopifnot(setequal(p$ano_sazonal,e$ano_sazonal))
  pares <- merge(p,e,by="ano_sazonal",suffixes=c("_power","_era5"))
  list(distancia=mean(abs(pares$valor_power-pares$valor_era5)),n=nrow(pares))
}
ficha_mundial <- function(x,epoca,v) {
  a <- series_mundiais(x,epoca,v); comparacao <- comparar_mundial(a)
  c("ENSO Local — global historical factsheet", paste(x$ponto$cidade,x$ponto$pais,sep=" · "),
    paste("Point:",x$ponto$latitude,x$ponto$longitude),
    paste("Measure:",if(v=="temperatura_c") "air temperature" else "total rainfall",
      "·",rotulos_estacao[[epoca]],"·",min(a$ano_sazonal),"to",max(a$ano_sazonal)),
    if(v=="temperatura_c") "Temperature: equally weighted average of three monthly means (°C)." else "Rainfall: sum of three monthly totals (mm/season). 1 mm = 1 litre/m².",
    "Reference: 1991–2020 for each source and month. Difference = value minus reference; not an effect attributed to ENSO.",
    "DJF: December belongs to the following year; complete seasons only.",
    if(is.null(comparacao)) "Only POWER is available; ERA5 has not been acquired. Missing does not mean zero." else
      paste("Mean absolute difference between sources:",num(comparacao$distancia),unidade_grafico(v),"in",comparacao$n,"matched seasons. This does not identify the more accurate source."),
    "Gridded estimates at a reference point, not measurements of the entire municipality. POWER LST; ERA5 UTC.",
    "Global inference has not been released: no conclusion about association, causation or prediction. The latest available year is not current weather.",
    "Pilot station checks do not automatically apply to this point. The global catalogue still has ranking and boundary gaps.",
    unlist(lapply(seq_len(nrow(x$fontes)),function(i) c(paste("Source:",x$fontes$fonte[i],"Calendar:",x$fontes$calendario[i]),
      x$fontes$url[i],paste("Monthly SHA-256:",x$fontes$sha256_mensal[i])))))
}
source("../idiomas/exports_en.R", encoding="UTF-8", local=TRUE)
source("layout.R", encoding="UTF-8", local=TRUE)
descrever_anos <- function(a) {
  bind_rows(lapply(intersect(c("POWER","ERA5"),unique(a$fonte)),function(f) {
    d <- a[a$fonte==f, ]; q <- quantile(d$valor,c(.25,.5,.75),names=FALSE,type=7)
    data.frame(fonte=f,n=nrow(d),ultimo_ano=max(d$ano_sazonal),ultimo=d$valor[which.max(d$ano_sazonal)],
      referencia=d$referencia[1],q1=q[1],mediana=q[2],q3=q[3],
      inferior=min(d$valor[d$valor>=q[1]-1.5*(q[3]-q[1])]),superior=max(d$valor[d$valor<=q[3]+1.5*(q[3]-q[1])]))
  }))
}
plotly_local <- function(p,label) {
  p <- plotly::plotly_build(p)
  j <- which(vapply(p$dependencies,function(d) identical(d$name,"plotly-main"),logical(1)))
  stopifnot(length(j)==1,p$dependencies[[j]]$version=="2.11.1")
  p$dependencies[[j]] <- htmltools::htmlDependency("plotly-main","2.11.1",
    src=c(file=file.path(app_dir,"www/vendor/plotly")),script="plotly-basic-2.11.1.min.js",all_files=FALSE)
  htmlwidgets::onRender(p,"function(el,x,label){el.setAttribute('role','img');el.setAttribute('aria-label',label);}",data=label)
}
server <- function(input, output, session) {
  destino_globo <- reactiveVal(NULL)
  observeEvent(session$clientData$url_search, {
    if(is.null(session$clientData$url_search)) return(NULL)
    q <- shiny::parseQueryString(session$clientData$url_search)
    if(length(q$city)==1 && q$city %in% indice$id) {
      p <- indice[indice$id==q$city, ]
      if(identical(shiny::isolate(input$pais),p$pais_iso2)) updateSelectInput(session,"cidade",selected=p$id)
      else { destino_globo(p$id); updateSelectInput(session,"pais",selected=p$pais_iso2) }
    }
    for(id in c("estacao","variavel","escala")) {
      choices <- switch(id,estacao=names(rotulos_estacao),variavel=c("temperatura_c","precipitacao_mm_mes"),escala=c("valor","diferenca"))
      if(length(q[[id]])==1 && q[[id]] %in% choices) {
        if(id=="escala") updateRadioButtons(session,id,selected=q[[id]]) else updateSelectInput(session,id,selected=q[[id]])
      }
    }
  },once=TRUE,ignoreNULL=TRUE,priority=-100)
  session$onFlushed(function() {
    session$sendCustomMessage("catalogo", lapply(seq_len(nrow(indice)), function(i)
      list(id=indice$id[i], nome=indice$cidade[i], iso2=indice$pais_iso2[i],
           latitude=indice$latitude[i], longitude=indice$longitude[i])))
  }, once=TRUE)
  observeEvent(input$globo_selecao, {
    id <- input$globo_selecao
    req(is.character(id), length(id)==1, id %in% indice$id)
    alvo <- indice[indice$id==id, ]
    if (identical(input$pais, alvo$pais_iso2)) {
      destino_globo(NULL)
      updateSelectInput(session,"cidade",selected=id)
    } else {
      destino_globo(id)
      updateSelectInput(session,"pais",selected=alvo$pais_iso2)
    }
  })
  observeEvent(input$pais, {
    req(input$pais %in% indice$pais_iso2)
    d <- indice[indice$pais_iso2==input$pais, ]
    selected <- if (input$pais=="BR") "GN-3445133" else d$id[1]
    search <- shiny::isolate(session$clientData$url_search)
    q <- shiny::parseQueryString(if(is.null(search)) "" else search)
    if(length(q$city)==1 && q$city %in% d$id) selected <- q$city
    if (!is.null(destino_globo()) && destino_globo() %in% d$id) selected <- destino_globo()
    destino_globo(NULL)
    updateSelectInput(session,"cidade", choices=setNames(d$id,d$cidade), selected=selected)
  })
  ponto <- reactive({
    req(input$cidade, input$pais)
    req(input$cidade %in% indice$id[indice$pais_iso2==input$pais])
    ler_ponto_mundial(input$cidade, file.path(app_dir,".."))
  })
  serie <- reactive({ req(input$estacao, input$variavel); series_mundiais(ponto(), input$estacao, input$variavel) })
  output$contexto <- renderUI({ p <- ponto()$ponto
    cidade <- trimws(sub("\\s*\\([^)]*\\)\\s*$","",p$cidade))
    alias <- if(cidade!=trimws(p$cidade)) trimws(sub(cidade,"",p$cidade,fixed=TRUE)) else NULL
    tags$div(class=paste("contexto",if(nchar(cidade)>18) "nome-longo" else ""), tags$p(class="eyebrow pais-identidade",
      tags$img(src=paste0("vendor/flags/",tolower(p$pais_iso2),".svg"),alt="",width=32,height=24),
      nome_pais(p$pais_iso2,p$pais)), tags$h1(cidade),
      if(!is.null(alias)) tags$p(class="nome-alternativo",alias),
      tags$p(class="lugar-subtitulo",paste0(min(serie()$ano_sazonal),"–",max(serie()$ano_sazonal)," · ",rotulos_estacao[[input$estacao]])))
  })
  output$disponibilidade <- renderUI({ x <- ponto()
    tags$div(class="disponibilidade", tags$span(class="status-fonte", "POWER available",ajuda_fonte("POWER","status")),
      tags$span(class=if(x$ponto$era5_disponivel) "status-fonte" else "status-pendente",
        if (x$ponto$era5_disponivel) "ERA5 available · two sources" else "ERA5 not yet acquired",ajuda_fonte("ERA5","status")))
  })
  output$resumo_valor <- renderUI({ a <- serie(); a <- a[a$ano_sazonal==max(a$ano_sazonal), ]
    a <- a[order(match(a$fonte,c("POWER","ERA5"))), ]
    tags$div(class="resumo resumo-fontes",
      tags$div(class="titulo-metrica", HTML(icone_metrica(input$variavel)),
        tags$h2(if(input$variavel=="temperatura_c") "Mean air temperature" else "Total rainfall")),
      tags$p(class="recorte-comparacao", paste(rotulos_estacao[[input$estacao]], a$ano_sazonal[1], sep=" · "),tags$span(class="ultimo-ano","Latest year in the dataset, not today's weather")),
      tags$div(class="valores-fontes", lapply(seq_len(nrow(a)), function(i)
        tags$div(class=paste("valor-fonte",tolower(a$fonte[i])), tags$span(class="nome-fonte",a$fonte[i],ajuda_fonte(a$fonte[i])),
          tags$div(tags$strong(num(a$valor[i])), tags$span(if(input$variavel=="temperatura_c") " °C" else " mm")),
          tags$small(paste(num(abs(a$diferenca[i])), if(input$variavel=="temperatura_c") "°C" else "mm",
            if(a$diferenca[i]>=0) "above average" else "below average"))))),
      tags$p(class="referencia-valores","Above or below the average for the same months in 1991–2020, for each source."))
  })
  output$historico <- renderPlotly({
    # Reuse styling; only actual sources enter the traces, never a missing-source placeholder.
    a <- serie(); p <- grafico_fontes(a, input$variavel, input$escala)
    p$x$attrs <- Filter(function(t) is.null(t$name) || t$name %in% unique(a$fonte), p$x$attrs)
    p$x$attrs <- lapply(p$x$attrs,function(t) {
      if(!is.null(t$name) && t$name %in% c("POWER","ERA5")) { t$line$color <- if(t$name=="POWER") "#e44e36" else "#217fa5"; t$line$width <- 1.6 }; t
    })
    referencias <- if(input$escala=="valor") lapply(unique(a$fonte),function(f) {
      d <- a[a$fonte==f, ]
      list(type="line",x0=min(d$ano_sazonal),x1=max(d$ano_sazonal),y0=d$referencia[1],y1=d$referencia[1],
        layer="below",line=list(color=if(f=="POWER") "#e44e36" else "#217fa5",width=1,dash="dot"),opacity=.55)
    }) else list()
    p <- plotly::layout(p,shapes=referencias,paper_bgcolor="#ffffff",plot_bgcolor="#ffffff",
      margin=list(l=44,r=8,t=12,b=28),
      xaxis=list(showgrid=TRUE,gridcolor="#eef3f6",tickvals=c(1981,1990,2000,2010,2025)),
      yaxis=list(gridcolor="#e4ebee"),font=list(family="Source Sans 3, sans-serif",color="#536771",size=11))
    # Only scatter traces are used. Local basic bundle avoids the full 3D/map payload
    # and avoids partial_bundle() downloading a dependency at application runtime.
    plotly_local(p,paste("Historical records for",ponto()$ponto$cidade,". Sources:",paste(unique(a$fonte),collapse=", ")))
  })
  output$comparacao_destaque <- renderUI({
    c <- comparar_mundial(serie())
    tags$div(class="comparacao-card",tags$p("Difference between sources"),
      tags$strong(if(is.null(c)) "—" else num(c$distancia)),tags$span(paste0(" ",unidade_grafico(input$variavel))),
      tags$small(if(is.null(c)) "One source available" else "Mean absolute gap; it does not identify the more accurate source."))
  })
  output$indicadores <- renderUI({
    s <- descrever_anos(serie()); u <- unidade_grafico(input$variavel)
    valores <- function(col) tags$div(class="mini-fontes",lapply(seq_len(nrow(s)),function(i)
      tags$div(class=paste("mini-fonte",tolower(s$fonte[i])),tags$span(s$fonte[i]),
        tags$p(tags$strong(num(s[[col]][i])),tags$span(class="unidade-indicador",u)))))
    tagList(tags$section(class="indicador-bloco",tags$h2(paste0("Latest year (",max(s$ultimo_ano),")")),valores("ultimo")),
      tags$section(class="indicador-bloco",tags$h2("Reference average",tags$small("1991–2020")),valores("referencia")))
  })
  output$distribuicao_subtitulo <- renderUI(tags$p(class="distribuicao-contexto",
    paste(if(input$variavel=="temperatura_c") "Mean air temperature" else "Total rainfall",rotulos_estacao[[input$estacao]],sep=" · ")))
  output$distribuicao <- renderPlotly({
    a <- serie(); s <- descrever_anos(a); p <- plotly::plot_ly(); shapes <- list()
    for(i in seq_len(nrow(s))) {
      f <- s$fonte[i]; d <- a[a$fonte==f, ]; y <- if(f=="POWER") 2 else 1
      cor <- if(f=="POWER") "#e44e36" else "#217fa5"
      p <- plotly::add_trace(p,x=d$valor,y=y+sin(seq_len(nrow(d))*2.4)*.045,type="scatter",mode="markers",name=f,
        marker=list(color=cor,size=5,opacity=.65),
        text=paste(f,d$ano_sazonal,paste0(num(d$valor)," ",unidade_grafico(input$variavel)),sep=" · "),hoverinfo="text")
      shapes <- c(shapes,list(list(type="rect",x0=s$q1[i],x1=s$q3[i],y0=y-.18,y1=y+.18,
        line=list(color=cor,width=1),fillcolor=if(f=="POWER") "rgba(244,105,82,.26)" else "rgba(44,150,200,.28)"),
        list(type="line",x0=s$mediana[i],x1=s$mediana[i],y0=y-.18,y1=y+.18,line=list(color=cor,width=2)),
        list(type="line",x0=s$inferior[i],x1=s$q1[i],y0=y,y1=y,line=list(color=cor,width=1)),
        list(type="line",x0=s$q3[i],x1=s$superior[i],y0=y,y1=y,line=list(color=cor,width=1)),
        list(type="line",x0=s$inferior[i],x1=s$inferior[i],y0=y-.09,y1=y+.09,line=list(color=cor,width=1)),
        list(type="line",x0=s$superior[i],x1=s$superior[i],y0=y-.09,y1=y+.09,line=list(color=cor,width=1)),
        list(type="line",x0=s$referencia[i],x1=s$referencia[i],y0=y-.34,y1=y+.34,line=list(color=cor,width=1,dash="dash"))))
    }
    p <- plotly::layout(p,shapes=shapes,showlegend=FALSE,margin=list(l=52,r=12,t=10,b=30),
      paper_bgcolor="white",plot_bgcolor="white",separators=",.",
      font=list(family="Source Sans 3, sans-serif",size=11,color="#536771"),
      xaxis=list(title="",ticksuffix=if(input$variavel=="temperatura_c") " °C" else " mm",gridcolor="#e9f0f4",fixedrange=TRUE),
      yaxis=list(title="",tickvals=ifelse(s$fonte=="POWER",2,1),ticktext=s$fonte,range=c(.45,2.55),showgrid=FALSE,zeroline=FALSE,fixedrange=TRUE))
    plotly_local(plotly::config(p,displayModeBar=FALSE,responsive=TRUE,scrollZoom=FALSE),"Descriptive distribution of seasonal values by source")
  })
  output$legenda <- renderUI(tagList(
    tags$p(class="legenda-dupla", lapply(intersect(c("POWER","ERA5"),unique(serie()$fonte)), function(f) tags$span(class=paste("chave",tolower(f)),f)),
      if(input$escala=="valor") tags$span(class="chave referencia","Reference 1991–2020")),
    tags$p(class="nota", if(input$variavel=="temperatura_c") "Average of the three monthly means, in °C." else "Rainfall summed over three months, in mm (1 mm = 1 litre/m²).",
      " Select a line to inspect the values for each year.",
      if(input$estacao=="DJF") " December belongs to the following year; only complete seasons are included.")))
  output$local_mapa <- renderUI({ p <- ponto()$ponto
    tags$div(class="local-mapa",HTML(icone_metrica(input$variavel)),tags$div(tags$strong(p$cidade),
      tags$span(paste(num(abs(p$latitude),2),if(p$latitude<0) "° S" else "° N"," / ",num(abs(p$longitude),2),if(p$longitude<0) "° W" else "° E"))))
  })
  observe({ p <- ponto()$ponto; req(input$variavel)
    session$sendCustomMessage("mundial",list(id=p$id,nome=p$cidade,pais=nome_pais(p$pais_iso2,p$pais),iso2=p$pais_iso2,latitude=p$latitude,longitude=p$longitude,metrica=input$variavel,icone=icone_metrica(input$variavel,"white")))
  })
  output$resumo_local <- renderUI({ a <- serie(); comparacao <- comparar_mundial(a)
    tags$div(class="respostas-locais",
      tags$section(class="leitura-historico",tags$h3(icone_resumo("documento"),"The historical record"),tags$p(paste("Each year shows",if(input$variavel=="temperatura_c") "the mean air temperature" else "the total rainfall","for",rotulos_estacao[[input$estacao]],"in",ponto()$ponto$cidade,". This keeps the time of year consistent across the comparison."))),
      tags$section(class="leitura-fontes",tags$h3(icone_resumo("comparacao"),"The comparison"),
        if(!is.null(comparacao)) tagList(tags$p(class="distancia-destaque",tags$strong(num(comparacao$distancia)),tags$span(unidade_grafico(input$variavel))),
          tags$p(paste("mean absolute difference between POWER and ERA5 across",comparacao$n,"seasons. The gap between the lines does not tell us which source is more accurate.")))
        else tagList(tags$p(class="fonte-ausente","One source available"),tags$p("POWER is available. ERA5 has not yet been acquired; its absence does not mean zero."))),
      tags$section(class="conclusao-local",tags$h3(icone_resumo("pessoa"),"What about El Niño?"),tags$p("An association has not yet been calculated for this global query. Historical records alone do not explain what caused the changes or predict next year.")))
  })
  output$cobertura_local <- renderUI({
    p <- ponto()$ponto; c <- cobertura[cobertura$pais_iso2==p$pais_iso2,,drop=FALSE]
    tags$p(if(nrow(c)==1 && c$pendencia_ranking=="complementacao_nacional_necessaria")
      paste(p$pais,": some locations are approved, but the three largest still require confirmation. This does not automatically invalidate the displayed point.")
      else paste(p$pais,": the ranking or applicability decision is recorded in the catalogue. Geographic approval is not observational validation of the climate estimates."))
  })
  output$fontes <- renderUI({ x <- ponto()
    tagList(tags$p("Calendars in this global dataset: POWER uses local solar time (LST); ERA5 uses UTC. Comparisons may be sensitive to month boundaries. The pilot's station checks have not been extended to all these locations."),
      lapply(seq_len(nrow(x$fontes)), function(i) tags$details(tags$summary(x$fontes$fonte[i]),
        tags$p(paste("Calendar:",x$fontes$calendario[i],"·",nrow(x$mensal[x$mensal$fonte==x$fontes$fonte[i],]),"months")),
        tags$p(tags$a(href=x$fontes$url[i],target="_blank",rel="noopener","Original request")),
        tags$p(paste("Monthly SHA-256:",x$fontes$sha256_mensal[i])))))
  })
  output$serie_csv <- downloadHandler(filename=function() paste0(input$cidade,"_",input$estacao,"_series.csv"),
    content=function(file) write_excel_csv2(exportar_mundial(ponto(),input$estacao,input$variavel),file))
  output$mensal_csv <- downloadHandler(filename=function() paste0(input$cidade,"_mensal.csv"),
    content=function(file) write_excel_csv2(left_join(ponto()$mensal,ponto()$fontes,by=c("id","fonte")) |>
      mutate(unidade_temperatura="°C",unidade_chuva="mm/month",referencia_periodo="1991-2020",
        interpretacao="Descriptive historical records; retrospective centred indices; not a forecast"),file))
  output$ficha_txt <- downloadHandler(filename=function() paste0(input$cidade,"_",input$estacao,"_ficha.txt"),
    content=function(file) writeLines(enc2utf8(ficha_mundial(ponto(),input$estacao,input$variavel)),file,useBytes=TRUE))
}
shinyApp(ui,server)
