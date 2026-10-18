# Apresentação descritiva; não reestima os modelos congelados de 7/10.
library(plotly)

serie_temporadas <- function(d, variavel) {
  stopifnot(variavel %in% c("temperatura_c", "precipitacao_mm_mes"), all(table(d$ano_sazonal) == 3))
  temp <- variavel == "temperatura_c"
  ref <- if (temp) "temperatura_referencia_c" else "precipitacao_referencia_mm_mes"
  f <- if (temp) mean else sum
  d |> group_by(ano_sazonal) |>
    summarise(valor = f(.data[[variavel]]), referencia = f(.data[[ref]]), .groups = "drop") |>
    mutate(diferenca = valor - referencia)
}
unidade_grafico <- function(v) if (v == "temperatura_c") "°C" else "mm/trimestre"
icone_metrica <- function(v, cor = "currentColor") {
  desenho <- if (v == "temperatura_c")
    '<path d="M9 14.5V5a3 3 0 0 1 6 0v9.5a5 5 0 1 1-6 0Z"/><path d="M12 8v9"/><circle cx="12" cy="18" r="1.5" fill="currentColor" stroke="none"/>'
  else '<path d="M12 2C9 7 5 11 5 15a7 7 0 0 0 14 0c0-4-4-8-7-13Z"/><path d="M8 15a4 4 0 0 0 4 4"/>'
  sprintf('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 26" fill="none" stroke="%s" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">%s</svg>', cor, desenho)
}
grafico_historico <- function(d, v, escala = "valor") {
  a <- serie_temporadas(d, v); temp <- v == "temperatura_c"
  cor <- if (temp) cor_destaque else cor_principal
  y <- if (escala == "valor") a$valor else a$diferenca
  ref <- if (escala == "valor") a$referencia else rep(0, nrow(a))
  unidade <- unidade_grafico(v)
  texto <- sprintf("<b>%s</b><br>%s: %s %s<br>Média 1991–2020: %s %s<br>Diferença: %s %s",
    a$ano_sazonal, if (temp) "Temperatura média" else "Chuva acumulada", num(a$valor, 1), unidade,
    num(a$referencia, 1), unidade, num(a$diferenca, 1, TRUE), unidade)
  plot_ly() |>
    add_trace(x = a$ano_sazonal, y = ref, type = "scatter", mode = "lines", name = "Média 1991–2020",
      line = list(color = "#87959d", dash = "dash", width = 1), hoverinfo = "skip") |>
    add_trace(x = a$ano_sazonal, y = y, type = "scatter", mode = "lines+markers", name = "Histórico",
      line = list(color = cor, width = 2), marker = list(size = 4, color = cor), text = texto,
      hoverinfo = "text", connectgaps = FALSE) |>
    add_trace(x = tail(a$ano_sazonal, 1), y = tail(y, 1), type = "scatter", mode = "markers",
      marker = list(size = 9, color = cor, line = list(color = "white", width = 2)),
      text = tail(texto, 1), hoverinfo = "text", showlegend = FALSE) |>
    layout(showlegend = FALSE, margin = list(l = 57, r = 14, b = 35, t = 14),
      paper_bgcolor = "white", plot_bgcolor = "white", separators = ",.",
      font = list(family = "Noto Sans, sans-serif", color = "#53616a", size = 12),
      xaxis = list(title = "", tickvals = c(1981, 1990, 2000, 2010, 2025), showgrid = FALSE,
                   zeroline = FALSE, fixedrange = TRUE),
      yaxis = list(title = "", ticksuffix = if (temp) " °C" else " mm", gridcolor = "#edf0f2",
        zeroline = FALSE, fixedrange = TRUE, rangemode = if (temp || escala != "valor") "normal" else "tozero"),
      hoverlabel = list(bgcolor = "#1A252F", font = list(color = "white", size = 12)),
      dragmode = FALSE) |>
    config(displayModeBar = FALSE, responsive = TRUE, scrollZoom = FALSE, locale = "pt-BR") |>
    htmlwidgets::onRender("function(el,x,data){el.setAttribute('role','img');el.setAttribute('aria-label',data);}",
      data = sprintf("Histórico de %s em %s, %s a %s. Escala: %s. Último valor: %s %s; referência: %s %s. Dados disponíveis em Baixar dados.",
        if (temp) "temperatura média" else "chuva acumulada", d$cidade[1], min(a$ano_sazonal), max(a$ano_sazonal),
        if (escala == "valor") "valor absoluto" else "diferença da média", num(tail(a$valor, 1), 1), unidade,
        num(tail(a$referencia, 1), 1), unidade))
}

instalar_explorador <- function(input, output, session, selecao) {
  serie <- reactive(serie_temporadas(selecao()$d, input$variavel))
  observeEvent(input$variavel, updateRadioButtons(session, "escala", choices = setNames(c("valor", "diferenca"),
    c(if (input$variavel == "temperatura_c") "Temperatura (°C)" else "Chuva total (mm)", "Diferença da média")),
    selected = if (is.null(isolate(input$escala))) "valor" else isolate(input$escala)))
  output$historico <- renderPlotly({req(input$escala); grafico_historico(selecao()$d, input$variavel, input$escala)})
  output$resumo_valor <- renderUI({
    a <- tail(serie(), 1); v <- input$variavel; temp <- v == "temperatura_c"
    tags$div(class = if (temp) "resumo temperatura" else "resumo chuva",
      tags$div(class = "titulo-metrica", HTML(icone_metrica(v)),
        tags$h2(if (temp) "Temperatura média" else "Chuva acumulada")),
      tags$div(class = "valor-linha", tags$strong(class = "valor", num(a$valor, 1)),
        tags$span(class = "unidade", if (temp) "°C" else "mm"),
        tags$span(class = "recorte-valor", paste(tolower(rotulos_estacao[[input$estacao]]), a$ano_sazonal,
          sep = " · "))),
      tags$p(class = "comparativo", "Cerca de ", tags$strong(paste(num(abs(a$diferenca), 1), if (temp) "°C" else "mm",
          if (a$diferenca >= 0) "acima" else "abaixo")), " da média de 1991–2020, para estes meses."))
  })
  output$legenda_grafico <- renderUI({
    temp <- input$variavel == "temperatura_c"
    tagList(tags$p(class = "legenda-serie", tags$span(class = "tracejado"),
      if (is.null(input$escala) || input$escala == "valor") "Média de 1991–2020" else "Zero = média de 1991–2020",
      tags$span(class = "fonte-serie", paste(input$fonte, "·", nrow(serie()), "temporadas"))),
      tags$p(class = "nota", if (temp) "Cada ponto é a média das três médias mensais, em °C. Estimativa de grade, não medição de uma estação."
        else "Cada ponto soma a chuva dos três meses, em mm. 1 mm equivale a 1 litro por m². Estimativa de grade.",
        if (input$estacao == "DJF") " Dezembro pertence à temporada do ano seguinte."))
  })
  output$qualidade_local <- renderUI({
    s <- selecao()
    titulo <- if (s$r$cidade_id == 3470127 && s$r$variavel == "precipitacao_mm_mes") "Chuva de BH: divergência importante em agosto de 2019"
      else if (s$r$cidade_id == 3455671 && s$r$variavel == "precipitacao_mm_mes") "Chuva de Ouro Preto: as fontes divergem"
      else if (s$r$cidade_id == 3445133 && s$r$variavel == "temperatura_c") "Temperatura de Viçosa: diferença entre fontes em maio de 2024"
      else "Conferência com estações: cobertura ainda parcial"
    tags$details(class = "aviso-qualidade", tags$summary(titulo),
      tags$p(alerta_qualidade(s$r$cidade_id, s$r$variavel)))
  })
  output$equacao <- renderUI({
    a <- tail(serie(), 1); u <- if (input$variavel == "temperatura_c") "°C" else "mm"
    tags$div(class = "equacao", `aria-label` = "Como calculamos a diferença",
      tags$div(tags$strong(paste(num(a$valor, 2), u)), tags$span(paste("Valor em", a$ano_sazonal))),
      tags$span(class = "operador", "−"),
      tags$div(tags$strong(paste(num(a$referencia, 2), u)), tags$span("Média de 1991–2020")),
      tags$span(class = "operador", "≈"),
      tags$div(class = "resultado-equacao", tags$strong(paste(num(a$diferenca, 2, TRUE), u)), tags$span("Diferença (anomalia)")))
  })
  output$local_mapa <- renderUI({
    s <- selecao()
    tags$div(class = "local-mapa", HTML(icone_metrica(input$variavel)), tags$div(tags$strong(s$f$cidade),
      tags$span(sprintf("%s° S · %s° O", num(abs(s$f$latitude), 3), num(abs(s$f$longitude), 3))),
      if (input$fonte == "ERA5") tags$span(sprintf("Centro da célula ERA5: %s° S · %s° O", num(abs(s$e$latitude_grade), 2), num(abs(s$e$longitude_grade), 2)))))
  })
  observeEvent(list(input$cidade, input$variavel), {
    s <- selecao()
    session$sendCustomMessage("localizador", list(id = s$f$cidade_id, nome = s$f$cidade, metrica = input$variavel))
    session$sendCustomMessage("cor-metrica", list(cor = if (input$variavel == "temperatura_c") cor_destaque else cor_principal))
  })
  output$serie_csv <- downloadHandler(filename = function() paste0("serie_trimestral_", input$cidade, "_", input$estacao, "_", input$fonte, ".csv"),
    content = function(file) write_excel_csv2(serie() |> mutate(cidade = selecao()$f$cidade, fonte = input$fonte,
      variavel = input$variavel, unidade = unidade_grafico(input$variavel), estacao = input$estacao,
      url_fonte = selecao()$origem_url, identificador_fonte = selecao()$origem_hash), file))
}
