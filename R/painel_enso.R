# Shared descriptive evidence, cached once per process and checked against its snapshot.
enso_leitura <- local({
  cache <- NULL
  function(root) {
    if(!is.null(cache)) return(cache)
    path <- file.path(root,"dados/mundial/enso_descritivo_v1")
    meta <- jsonlite::read_json(file.path(path,"manifesto.json"),simplifyVector=TRUE)
    for(name in c("fases","resumos")) stopifnot(identical(digest::digest(file=file.path(path,paste0(name,".csv")),algo="sha256"),meta$hashes[[name]]))
    cache <<- list(summary=read.csv(file.path(path,"resumos.csv"),stringsAsFactors=FALSE,na.strings=""),
      phases=read.csv(file.path(path,"fases.csv"),stringsAsFactors=FALSE,na.strings=""))
    cache
  }
})
enso_recorte <- function(root,id,season,variable,index="RONI") {
  all <- enso_leitura(root)$summary
  all[all$id==id & all$estacao==season & all$variavel==variable & all$indice==index,]
}
enso_numero <- function(v,lang,digits=2,sign=FALSE) {
  sub("^-","−",formatC(v,digits=digits,format="f",decimal.mark=if(lang=="pt") "," else ".",flag=if(sign) "+" else ""))
}
enso_texto <- function(d,lang,variable,sensitivity=NULL) {
  pt <- lang=="pt";u <- if(variable=="temperatura_c") "°C" else "mm"
  n <- function(v) enso_numero(v,lang,sign=TRUE)
  nino <- d[d$fase=="nino",];neutral <- d[d$fase=="transicao",]
  common <- intersect(nino$fonte,neutral$fonte)
  if(!length(common)) return(if(pt) "Não há grupos suficientes para esta comparação." else "Insufficient groups for this comparison.")
  delta <- nino$media[match(common,nino$fonte)]-neutral$media[match(common,neutral$fonte)]
  caution <- if(pt) "O sinal numérico, sozinho, não estabelece uma relação consistente com ENSO." else "The numerical sign alone does not establish a consistent ENSO relationship."
  if(!is.null(sensitivity)) {
    other_nino <- sensitivity[sensitivity$fase=="nino",];other_neutral <- sensitivity[sensitivity$fase=="transicao",]
    other <- other_nino$media[match(common,other_nino$fonte)]-other_neutral$media[match(common,other_neutral$fonte)]
    changed <- which(is.finite(other) & round(delta,2)!=0 & round(other,2)!=0 & sign(delta)!=sign(other))
    if(length(changed)) caution <- paste(vapply(changed,function(i) {
      if(pt) paste0("Em ",common[i],", o contraste muda para ",n(other[i])," ",u," com ONI; sua direção depende do índice.") else
        paste0("In ",common[i],", the contrast changes to ",n(other[i])," ",u," with ONI; its direction depends on the index.")
    },""),collapse=" ")
  }
  paste(if(pt) "No histórico, diferença das médias El Niño menos neutro/transição:" else "Historical mean difference, El Niño minus neutral/transition:",
    paste0(paste(paste(common,n(delta),u),collapse="; "),"."),caution,
    if(pt) "Comparação descritiva, sem ajuste de tendência ou teste de significância. Não atribui causa nem prevê outro evento." else
      "Descriptive comparison without trend adjustment or a significance test. It does not attribute causality or forecast another event.")
}
enso_historico_ui <- function(lang) {
  shiny::tags$details(id="enso-historico",class="enso-fases",
    shiny::tags$summary(if(lang=="pt") "Como o histórico varia entre fases do ENSO?" else "How does the record vary across ENSO phases?"),
    shiny::uiOutput("enso_historico"))
}
enso_historico_instalar <- function(input,output,session,lang,root) {
  pt <- lang=="pt";t <- function(a,b) if(pt)a else b
  output$enso_historico <- shiny::renderUI({
    shiny::req(input$cidade,input$estacao,input$variavel)
    d <- tryCatch(enso_recorte(root,input$cidade,input$estacao,input$variavel),error=function(e)NULL)
    if(is.null(d)||!nrow(d)) return(shiny::tags$p(t("Este resumo está temporariamente indisponível. Os dados originais continuam nos downloads.","This summary is temporarily unavailable. Original records remain available to download.")))
    unit <- if(input$variavel=="temperatura_c") "°C" else "mm"
    format <- function(v) enso_numero(v,lang,sign=TRUE)
    sensitivity <- enso_recorte(root,input$cidade,input$estacao,input$variavel,"ONI")
    labels <- if(pt)c(nina="La Niña",transicao="Neutro / transição",nino="El Niño") else c(nina="La Niña",transicao="Neutral / transition",nino="El Niño")
    table <- function(rows) shiny::tags$div(class="fases-table",shiny::tags$table(
      shiny::tags$thead(shiny::tags$tr(shiny::tags$th(t("Fase e amostra","Phase and sample")),shiny::tags$th(class="power","POWER"),shiny::tags$th(class="era5","ERA5"))),
      shiny::tags$tbody(lapply(names(labels),function(phase) {
        s <- rows[rows$fase==phase,];if(!nrow(s))return(NULL)
        cell <- function(source) {
          a <- s[s$fonte==source,];if(!nrow(a))return(shiny::tags$td("—"))
          shiny::tags$td(class=tolower(source),shiny::tags$strong(paste(format(a$media),unit)),
            shiny::tags$small(paste0(format(a$q1)," ",t("a","to")," ",format(a$q3))),
            shiny::tags$small(paste0("n = ",a$n)))
        }
        shiny::tags$tr(shiny::tags$th(labels[[phase]],shiny::tags$small(if(phase!="transicao")paste(s$episodios[1],t("episódios","episodes")) else t("Fora de episódios persistentes","Outside persistent episodes"))),cell("POWER"),cell("ERA5"))
      }))))
    current <- enso_leitura(root)$phases
    year <- if(is.null(input$ano_inspecao)) 2025L else as.integer(input$ano_inspecao)
    now <- current[current$indice=="RONI" & current$ano==year & current$estacao==input$estacao,]
    shiny::tagList(shiny::tags$p(class="fases-contexto",t("Diferença média da referência 1991–2020, por fase histórica do Pacífico. Cada fonte usa sua própria referência.","Mean difference from the 1991–2020 baseline by historical Pacific phase. Each source uses its own baseline.")),
      if(nrow(now)==1)shiny::tags$p(paste(year,"·",input$estacao,"·",labels[[now$fase]],"· RONI",enso_numero(now$valor,lang,1))),
      table(d),shiny::tags$p(class="fases-conclusao",enso_texto(d,lang,input$variavel,sensitivity)),
      shiny::tags$p(class="nota",t("Em destaque: média do grupo. A faixa abaixo reúne os 50% centrais dos anos, não um intervalo de confiança. n é o número de temporadas; anos de um mesmo episódio não são eventos independentes.","Bold: group mean. The range below contains the middle 50% of years, not a confidence interval. n counts seasons; years in the same episode are not independent events.")),
      shiny::tags$details(shiny::tags$summary(t("Método, anos e sensibilidade ao ONI","Method, years and ONI sensitivity")),
        shiny::tags$p(t("RONI ERSSTv6: pelo menos cinco temporadas sobrepostas consecutivas com índice ≥ +0,5 ou ≤ −0,5. A fase usa o índice do mês central do trimestre. Neutro/transição inclui flutuações sem um episódio persistente. Período 1981–2025; dez–fev começa em 1982.","RONI ERSSTv6: at least five consecutive overlapping seasons at ≥ +0.5 or ≤ −0.5. The phase uses the index of the central month. Neutral/transition includes fluctuations outside persistent episodes. Period 1981–2025; Dec–Feb starts in 1982.")),
        shiny::tags$p(t("Tendência climática e outros fatores podem confundir os grupos. As duas fontes não são observações independentes. Esta análise não valida previsão nem efeito causal.","Climate trends and other factors may confound the groups. The sources are not independent observations. This analysis validates neither forecasting nor causal effects.")),
        shiny::tags$p(shiny::tags$a(href="https://www.cpc.ncep.noaa.gov/products/analysis_monitoring/enso/roni/",target="_blank",rel="noopener","NOAA/CPC · RONI ↗")),
        lapply(names(labels),function(phase)shiny::tags$p(paste(labels[[phase]],"·",paste(unique(d$anos[d$fase==phase]),collapse=" / ")))),
        shiny::tags$h4(t("Mesma comparação com ONI","Same comparison using ONI")),
        table(sensitivity)))
  })
}
