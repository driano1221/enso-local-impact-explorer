grafico_fontes <- function(a, v, escala) {
  p <- plot_ly()
  for (origem in c("POWER", "ERA5")) {
    d <- a[a$fonte == origem, ]
    p <- p |> add_trace(x = d$ano_sazonal, y = if (escala == "valor") d$valor else d$diferenca,
      type = "scatter", mode = "lines", name = origem,
      line = list(color = if (origem == "POWER") "#bd4936" else "#207b94",
                  dash = if (origem == "POWER") "solid" else "dash", width = 2),
      text = sprintf("<b>%s · %s</b><br>Value: %s %s<br>1991–2020 average: %s %s<br>Difference: %s %s",
        origem, d$ano_sazonal, num(d$valor, 1), unidade_grafico(v), num(d$referencia, 1),
        unidade_grafico(v), num(d$diferenca, 1, TRUE), unidade_grafico(v)),
      hoverinfo = "text", connectgaps = FALSE)
  }
  p |> layout(showlegend = FALSE, margin = list(l = 56, r = 12, b = 32, t = 12),
    paper_bgcolor = "white", plot_bgcolor = "white", separators = ".,",
    font = list(family = "Noto Sans, sans-serif", color = "#53616a", size = 12),
    xaxis = list(title = "", tickvals = c(1981, 1990, 2000, 2010, 2025), showgrid = FALSE, fixedrange = TRUE),
    yaxis = list(title = "", ticksuffix = if (v == "temperatura_c") " °C" else " mm",
      gridcolor = "#edf0f2", fixedrange = TRUE, zeroline = escala != "valor", zerolinecolor = "#87959d",
      rangemode = if (v != "temperatura_c" && escala == "valor") "tozero" else "normal"),
    hovermode = "closest", dragmode = FALSE) |>
    config(displayModeBar = FALSE, responsive = TRUE, scrollZoom = FALSE, locale = "en") |>
    htmlwidgets::onRender("function(el){el.setAttribute('role','img');el.setAttribute('aria-label','Historical POWER and ERA5 records for the same years. Values and references are available on the lines and in the CSV.');}")
}
