# Comparação descritiva: mesmas temporadas, referências próprias de cada fonte.
series_fontes <- function(id, epoca, v) {
  a <- bind_rows(lapply(c("POWER", "ERA5"), function(origem) {
    serie_temporadas(recorte_piloto(id, epoca, origem), v) |> mutate(fonte = origem)
  }))
  stopifnot(identical(a$ano_sazonal[a$fonte == "POWER"], a$ano_sazonal[a$fonte == "ERA5"]),
            all(is.finite(a$valor)), all(is.finite(a$referencia)))
  a
}

grafico_fontes <- function(a, v, escala) {
  p <- plot_ly()
  for (origem in c("POWER", "ERA5")) {
    d <- a[a$fonte == origem, ]
    p <- p |> add_trace(x = d$ano_sazonal, y = if (escala == "valor") d$valor else d$diferenca,
      type = "scatter", mode = "lines", name = origem,
      line = list(color = if (origem == "POWER") "#bd4936" else "#207b94",
                  dash = if (origem == "POWER") "solid" else "dash", width = 2),
      text = sprintf("<b>%s · %s</b><br>Valor: %s %s<br>Média 1991–2020: %s %s<br>Diferença: %s %s",
        origem, d$ano_sazonal, num(d$valor, 1), unidade_grafico(v), num(d$referencia, 1),
        unidade_grafico(v), num(d$diferenca, 1, TRUE), unidade_grafico(v)),
      hoverinfo = "text", connectgaps = FALSE)
  }
  p |> layout(showlegend = FALSE, margin = list(l = 56, r = 12, b = 32, t = 12),
    paper_bgcolor = "white", plot_bgcolor = "white", separators = ",.",
    font = list(family = "Noto Sans, sans-serif", color = "#53616a", size = 12),
    xaxis = list(title = "", tickvals = c(1981, 1990, 2000, 2010, 2025), showgrid = FALSE, fixedrange = TRUE),
    yaxis = list(title = "", ticksuffix = if (v == "temperatura_c") " °C" else " mm",
      gridcolor = "#edf0f2", fixedrange = TRUE, zeroline = escala != "valor", zerolinecolor = "#87959d",
      rangemode = if (v != "temperatura_c" && escala == "valor") "tozero" else "normal"),
    hovermode = "closest", dragmode = FALSE) |>
    config(displayModeBar = FALSE, responsive = TRUE, scrollZoom = FALSE, locale = "pt-BR") |>
    htmlwidgets::onRender("function(el){el.setAttribute('role','img');el.setAttribute('aria-label','Histórico de POWER e ERA5 nos mesmos anos. Valores e referências disponíveis ao tocar nas linhas e no CSV.');}")
}

respostas_locais <- function(r, a, v) {
  stopifnot(nrow(r) == 2, setequal(r$fonte, c("POWER", "ERA5")))
  r <- r[match(c("POWER", "ERA5"), r$fonte), ]
  direcao <- if (v == "temperatura_c") c("temperatura menor", "temperatura maior") else c("menos chuva", "mais chuva")
  sinais <- ifelse(r$beta == 0, "nenhuma mudança estimada", ifelse(r$beta > 0, direcao[2], direcao[1]))
  distancia <- mean(abs(a$valor[a$fonte == "POWER"] - a$valor[a$fonte == "ERA5"]))
  list(
    historico = sprintf("Quando o índice do Pacífico aumenta, a análise estima %s na POWER e %s na ERA5. Consideramos a época do ano e a tendência ao longo do tempo.", sinais[1], sinais[2]),
    fontes = paste(if (sign(r$beta[1]) == sign(r$beta[2])) "As estimativas da relação com o Pacífico apontam na mesma direção." else "As estimativas da relação com o Pacífico apontam em direções diferentes.",
      sprintf("Já os valores do gráfico diferem, em média, %s %s entre as fontes (distância entre as linhas).", num(distancia, 1), unidade_grafico(v))),
    conclusao = if (all(r$p_holm_global96 > .05)) "A análise permanece exploratória: não confirma uma associação com o ENSO neste recorte. Consideramos as muitas comparações, e a calibração da incerteza ainda tem limitações. Isso não demonstra ausência de relação."
      else "Há evidência após a correção pelas comparações; ainda é necessário avaliar estabilidade entre fontes e períodos. Associação não prova causa."
  )
}

exportar_series_fontes <- function(s, epoca, v) {
  series_fontes(s$f$cidade_id, epoca, v) |> mutate(cidade = s$f$cidade,
    variavel = v, unidade = unidade_grafico(v), estacao = epoca,
    url_fonte = ifelse(fonte == "POWER", s$f$url, s$e$url),
    identificador_fonte = ifelse(fonte == "POWER", paste("MD5", s$f$md5), paste("SHA-256", s$e$sha256)))
}

instalar_comparacao <- function(input, output, session, selecao) {
  ambas <- reactive(series_fontes(selecao()$f$cidade_id, input$estacao, input$variavel))
  output$historico <- renderPlotly({ req(input$escala); grafico_fontes(ambas(), input$variavel, input$escala) })
  output$resumo_valor <- renderUI({
    a <- ambas(); a <- a[a$ano_sazonal == max(a$ano_sazonal), ]
    tags$div(class = "resumo resumo-fontes",
      tags$div(class = "titulo-metrica", HTML(icone_metrica(input$variavel)),
        tags$h2(if (input$variavel == "temperatura_c") "Temperatura média" else "Chuva acumulada")),
      tags$p(class = "recorte-comparacao", paste(rotulos_estacao[[input$estacao]], a$ano_sazonal[1], sep = " · ")),
      tags$div(class = "valores-fontes", lapply(seq_len(nrow(a)), function(i) {
        tags$div(class = paste("valor-fonte", tolower(a$fonte[i])),
          tags$span(class = "nome-fonte", a$fonte[i]),
          tags$div(tags$strong(num(a$valor[i], 1)), tags$span(if (input$variavel == "temperatura_c") " °C" else " mm")),
          tags$small(paste(num(abs(a$diferenca[i]), 1), if (input$variavel == "temperatura_c") "°C" else "mm",
            if (a$diferenca[i] >= 0) "acima" else "abaixo", "da média")))
      })))
  })
  output$legenda_grafico <- renderUI(tagList(
    tags$p(class = "legenda-dupla", tags$span(class = "chave power", "POWER"), tags$span(class = "chave era5", "ERA5")),
    tags$p(class = "nota", if (input$variavel == "temperatura_c") "Cada ponto é a média das três médias mensais." else "Cada ponto soma a chuva dos três meses. 1 mm = 1 litro por m².",
      " As duas fontes estimam o clima em grades. Cada uma tem sua própria média de 1991–2020.",
      if (input$estacao == "DJF") " Dezembro pertence ao ano seguinte.")))
  output$resumo_local <- renderUI({
    r <- ajustes |> filter(cidade_id == as.numeric(input$cidade), estacao == input$estacao,
                           variavel == input$variavel, indice == input$indice)
    textos <- respostas_locais(r, ambas(), input$variavel)
    tags$div(class = "respostas-locais",
      tags$section(tags$h3("O que apareceu no histórico?"), tags$p(textos$historico)),
      tags$section(tags$h3("As fontes concordam?"), tags$p(textos$fontes)),
      tags$section(class = "conclusao-local", tags$h3("O que podemos concluir?"), tags$p(textos$conclusao)))
  })
  output$fonte_detalhes <- renderUI(tags$p(class = "nota", paste("Detalhes abaixo:", input$fonte, "· índice", input$indice,
    ". A seleção da fonte altera estes detalhes; o histórico e o resumo sempre comparam as duas.")))
  output$serie_csv <- downloadHandler(
    filename = function() paste0("serie_trimestral_", input$cidade, "_", input$estacao, "_POWER_ERA5.csv"),
    content = function(file) write_excel_csv2(exportar_series_fontes(selecao(), input$estacao, input$variavel), file))
}
