if (.Platform$OS.type == "windows") Sys.setlocale("LC_ALL", "English_United States.utf8")
library(shiny)
library(bslib)
library(dplyr)
library(readr)
source("../R/tema_vault.R", encoding="UTF-8", local=TRUE)
source("../R/validar_piloto.R", encoding="UTF-8", local=TRUE)
source("../R/ler_mundial.R", encoding="UTF-8", local=TRUE)
source("../prototipo_revisado/explorador.R", encoding="UTF-8", local=TRUE)
source("../prototipo_revisado/comparacao.R", encoding="UTF-8", local=TRUE)
addResourcePath("aprovado", normalizePath("../prototipo_revisado/www"))
indice <- read.csv("../dados/mundial/integracao/pontos.csv", na.strings="", fileEncoding="UTF-8")
cobertura <- read.csv("../dados/mundial/cobertura_catalogo.csv", na.strings="", fileEncoding="UTF-8")
nomes_paises <- jsonlite::fromJSON("paises-pt.json")
nome_pais <- function(iso, original) if (!is.null(nomes_paises[[iso]])) nomes_paises[[iso]] else original
num <- function(x, n=1, sinal=FALSE) formatC(x, digits=n, format="f", decimal.mark=",", flag=if(sinal) "+" else "")
rotulos_estacao <- c(SON="Setembro a novembro", DJF="Dezembro a fevereiro", MAM="Março a maio", JJA="Junho a agosto")
series_mundiais <- function(x, epoca, v) {
  d <- preparar_sazonal(x$mensal)
  bind_rows(lapply(unique(d$fonte), function(f) {
    serie_temporadas(d[d$fonte==f & d$estacao==epoca, ], v) |> mutate(fonte=f)
  }))
}
exportar_mundial <- function(x, epoca, v) {
  series_mundiais(x, epoca, v) |> mutate(id=x$ponto$id, cidade=x$ponto$cidade,
    pais=x$ponto$pais, estacao=epoca, variavel=v, unidade=unidade_grafico(v),
    referencia_periodo="1991-2020", interpretacao="Historico descritivo; nao previsao nem efeito ENSO",
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
  c("ENSO Local — ficha histórica mundial", paste(x$ponto$cidade,x$ponto$pais,sep=" · "),
    paste("Ponto:",x$ponto$latitude,x$ponto$longitude),
    paste("Medida:",if(v=="temperatura_c") "temperatura do ar" else "chuva acumulada",
      "·",rotulos_estacao[[epoca]],"·",min(a$ano_sazonal),"a",max(a$ano_sazonal)),
    if(v=="temperatura_c") "Temperatura: média com pesos iguais das três médias mensais (°C)." else "Chuva: soma dos três totais mensais (mm/trimestre). 1 mm = 1 litro/m².",
    "Referência: 1991–2020 por fonte e mês. Diferença = valor menos referência; não é efeito atribuído ao ENSO.",
    "DJF: dezembro pertence ao ano seguinte; apenas temporadas completas.",
    if(is.null(comparacao)) "Somente POWER disponível; ERA5 não adquirido. Ausência não é zero." else
      paste("Distância absoluta média entre fontes:",num(comparacao$distancia),unidade_grafico(v),"em",comparacao$n,"temporadas pareadas. Não identifica a fonte mais precisa."),
    "Estimativas de grade em um ponto de referência, não medição de todo o município. POWER LST; ERA5 UTC.",
    "Inferência mundial não liberada: não há conclusão sobre associação, causa ou previsão. Último ano disponível não é condição atual.",
    "A validação por estações do piloto não se estende automaticamente a este ponto. Catálogo mundial ainda tem lacunas de ranking/delimitação.",
    unlist(lapply(seq_len(nrow(x$fontes)),function(i) c(paste("Fonte:",x$fontes$fonte[i],"Calendário:",x$fontes$calendario[i]),
      x$fontes$url[i],paste("SHA-256 mensal:",x$fontes$sha256_mensal[i])))))
}
source("layout.R", encoding="UTF-8", local=TRUE)
server <- function(input, output, session) {
  destino_globo <- reactiveVal(NULL)
  session$onFlushed(function() {
    session$sendCustomMessage("catalogo", lapply(seq_len(nrow(indice)), function(i)
      list(id=indice$id[i], nome=indice$cidade[i], iso2=indice$pais_iso2[i],
           latitude=indice$latitude[i], longitude=indice$longitude[i])))
  }, once=TRUE)
  observeEvent(input$variavel, {
    choices <- setNames(c("valor","diferenca"),c(
      if(input$variavel=="temperatura_c") "Temperatura (°C)" else "Chuva (mm)","Diferença da média"))
    updateRadioButtons(session,"escala",choices=choices,
      selected=if(is.null(input$escala)) "valor" else input$escala,inline=TRUE)
  })
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
    if (!is.null(destino_globo()) && destino_globo() %in% d$id) selected <- destino_globo()
    destino_globo(NULL)
    updateSelectInput(session,"cidade", choices=setNames(d$id,d$cidade), selected=selected)
  })
  ponto <- reactive({
    req(input$cidade, input$pais)
    req(input$cidade %in% indice$id[indice$pais_iso2==input$pais])
    ler_ponto_mundial(input$cidade, "..")
  })
  serie <- reactive({ req(input$estacao, input$variavel); series_mundiais(ponto(), input$estacao, input$variavel) })
  output$contexto <- renderUI({ p <- ponto()$ponto
    cidade <- trimws(sub("\\s*\\([^)]*\\)\\s*$","",p$cidade))
    alias <- if(cidade!=trimws(p$cidade)) trimws(sub(cidade,"",p$cidade,fixed=TRUE)) else NULL
    tags$div(class=paste("contexto",if(nchar(cidade)>18) "nome-longo" else ""), tags$p(class="eyebrow pais-identidade",
      tags$img(src=paste0("vendor/flags/",tolower(p$pais_iso2),".svg"),alt="",width=32,height=24),
      nome_pais(p$pais_iso2,p$pais)), tags$h1(cidade),
      if(!is.null(alias)) tags$p(class="nome-alternativo",alias),
      tags$p(class="lugar-subtitulo",paste0(min(serie()$ano_sazonal),"–",max(serie()$ano_sazonal)," · ",tolower(rotulos_estacao[[input$estacao]]))))
  })
  output$disponibilidade <- renderUI({ x <- ponto()
    tags$p(class="disponibilidade", tags$span(class="status-fonte", "POWER disponível"),
      tags$span(class=if(x$ponto$era5_disponivel) "status-fonte" else "status-pendente",
        if (x$ponto$era5_disponivel) "ERA5 disponível · duas fontes" else "ERA5 ainda não adquirido"),
      tags$span(class="status-historico","Histórico, não previsão"))
  })
  output$resumo_valor <- renderUI({ a <- serie(); a <- a[a$ano_sazonal==max(a$ano_sazonal), ]
    a <- a[order(match(a$fonte,c("POWER","ERA5"))), ]
    tags$div(class="resumo resumo-fontes",
      tags$div(class="titulo-metrica", HTML(icone_metrica(input$variavel)),
        tags$h2(if(input$variavel=="temperatura_c") "Temperatura média" else "Chuva acumulada")),
      tags$p(class="recorte-comparacao", paste(rotulos_estacao[[input$estacao]], a$ano_sazonal[1], sep=" · "),tags$span(class="ultimo-ano","Último ano da base, não é o tempo agora")),
      tags$div(class="valores-fontes", lapply(seq_len(nrow(a)), function(i)
        tags$div(class=paste("valor-fonte",tolower(a$fonte[i])), tags$span(class="nome-fonte",a$fonte[i]),
          tags$div(tags$strong(num(a$valor[i])), tags$span(if(input$variavel=="temperatura_c") " °C" else " mm")),
          tags$small(paste(num(abs(a$diferenca[i])), if(input$variavel=="temperatura_c") "°C" else "mm",
            if(a$diferenca[i]>=0) "acima da média" else "abaixo da média"))))),
      tags$p(class="referencia-valores","Acima ou abaixo da média dos mesmos meses em 1991–2020, em cada fonte."))
  })
  output$historico <- renderPlotly({
    # Reuse styling; only actual sources enter the traces, never a missing-source placeholder.
    a <- serie(); p <- grafico_fontes(a, input$variavel, input$escala)
    p$x$attrs <- Filter(function(t) is.null(t$name) || t$name %in% unique(a$fonte), p$x$attrs)
    p <- plotly::layout(p,paper_bgcolor="#ffffff",plot_bgcolor="#ffffff",
      yaxis=list(gridcolor="#e4ebee"),font=list(family="Source Sans 3, sans-serif",color="#536771",size=13))
    # Only scatter traces are used. Local basic bundle avoids the full 3D/map payload
    # and avoids partial_bundle() downloading a dependency at application runtime.
    p <- plotly::plotly_build(p)
    j <- which(vapply(p$dependencies,function(d) identical(d$name,"plotly-main"),logical(1)))
    stopifnot(length(j)==1, p$dependencies[[j]]$version=="2.11.1")
    p$dependencies[[j]] <- htmltools::htmlDependency("plotly-main","2.11.1",
      src=c(file=normalizePath("www/vendor/plotly")),script="plotly-basic-2.11.1.min.js",all_files=FALSE)
    htmlwidgets::onRender(p, "function(el,x,label){el.setAttribute('aria-label',label);}",
      data=paste("Histórico de",ponto()$ponto$cidade,". Fontes:",paste(unique(a$fonte),collapse=", ")))
  })
  output$legenda <- renderUI(tagList(
    tags$p(class="legenda-dupla", lapply(intersect(c("POWER","ERA5"),unique(serie()$fonte)), function(f) tags$span(class=paste("chave",tolower(f)),f))),
    tags$p(class="nota", if(input$variavel=="temperatura_c") "Média das três médias mensais, em °C." else "Chuva somada nos três meses, em mm (1 mm = 1 litro/m²).",
      " Toque nas linhas para consultar os valores de cada ano.",
      if(input$estacao=="DJF") " Dezembro pertence ao ano seguinte; somente trimestres completos.")))
  output$local_mapa <- renderUI({ p <- ponto()$ponto
    tags$div(class="local-mapa",HTML(icone_metrica(input$variavel)),tags$div(tags$strong(p$cidade),
      tags$span(paste(num(abs(p$latitude),2),if(p$latitude<0) "° S" else "° N"," / ",num(abs(p$longitude),2),if(p$longitude<0) "° O" else "° L"))))
  })
  observe({ p <- ponto()$ponto; req(input$variavel)
    session$sendCustomMessage("mundial",list(id=p$id,nome=p$cidade,pais=nome_pais(p$pais_iso2,p$pais),iso2=p$pais_iso2,latitude=p$latitude,longitude=p$longitude,metrica=input$variavel,icone=icone_metrica(input$variavel,"white")))
  })
  output$resumo_local <- renderUI({ a <- serie(); comparacao <- comparar_mundial(a)
    tags$div(class="respostas-locais",
      tags$section(class="leitura-historico",tags$h3("O histórico"),tags$p(paste("Cada ano mostra",if(input$variavel=="temperatura_c") "a temperatura média" else "a chuva acumulada","de",tolower(rotulos_estacao[[input$estacao]]),"em",ponto()$ponto$cidade,". Assim, comparamos sempre a mesma época do ano."))),
      tags$section(class="leitura-fontes",tags$h3("A comparação"),
        if(!is.null(comparacao)) tagList(tags$p(class="distancia-destaque",tags$strong(num(comparacao$distancia)),tags$span(unidade_grafico(input$variavel))),
          tags$p(paste("de diferença média entre POWER e ERA5, em",comparacao$n,"temporadas. A distância entre as linhas não diz qual fonte é mais precisa.")))
        else tagList(tags$p(class="fonte-ausente","Uma fonte disponível"),tags$p("POWER já está aqui. ERA5 aguarda aquisição; sua ausência não significa zero."))),
      tags$section(class="conclusao-local",tags$h3("E o El Niño?"),tags$p("Ainda não calculada a associação nesta consulta mundial. O histórico sozinho não explica a causa das mudanças nem prevê o próximo ano.")))
  })
  output$cobertura_local <- renderUI({
    p <- ponto()$ponto; c <- cobertura[cobertura$pais_iso2==p$pais_iso2,,drop=FALSE]
    tags$p(if(nrow(c)==1 && c$pendencia_ranking=="complementacao_nacional_necessaria")
      paste(p$pais,": há localidades aprovadas, mas a seleção das três maiores ainda exige confirmação. Isso não invalida automaticamente o ponto exibido.")
      else paste(p$pais,": a decisão de ranking ou aplicabilidade está registrada no catálogo. Aprovação geográfica não equivale à validação observacional do clima."))
  })
  output$fontes <- renderUI({ x <- ponto()
    tagList(tags$p("Calendários desta base mundial: POWER em hora solar local (LST); ERA5 em UTC. A comparação pode ser sensível ao fechamento dos meses. A verificação por estações do piloto não foi estendida a todos estes pontos."),
      lapply(seq_len(nrow(x$fontes)), function(i) tags$details(tags$summary(x$fontes$fonte[i]),
        tags$p(paste("Calendário:",x$fontes$calendario[i],"·",nrow(x$mensal[x$mensal$fonte==x$fontes$fonte[i],]),"meses")),
        tags$p(tags$a(href=x$fontes$url[i],target="_blank",rel="noopener","Consulta original")),
        tags$p(paste("SHA-256 mensal:",x$fontes$sha256_mensal[i])))))
  })
  output$serie_csv <- downloadHandler(filename=function() paste0(input$cidade,"_",input$estacao,"_series.csv"),
    content=function(file) write_excel_csv2(exportar_mundial(ponto(),input$estacao,input$variavel),file))
  output$mensal_csv <- downloadHandler(filename=function() paste0(input$cidade,"_mensal.csv"),
    content=function(file) write_excel_csv2(left_join(ponto()$mensal,ponto()$fontes,by=c("id","fonte")) |>
      mutate(unidade_temperatura="°C",unidade_chuva="mm/mês",referencia_periodo="1991-2020",
        interpretacao="Historico descritivo; indices centrados retrospectivos; nao previsao"),file))
  output$ficha_txt <- downloadHandler(filename=function() paste0(input$cidade,"_",input$estacao,"_ficha.txt"),
    content=function(file) writeLines(enc2utf8(ficha_mundial(ponto(),input$estacao,input$variavel)),file,useBytes=TRUE))
}
shinyApp(ui,server)
