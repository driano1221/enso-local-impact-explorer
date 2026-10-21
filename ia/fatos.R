# Adaptador local: reutiliza o leitor e a agregação aprovados; não inicia Shiny.
ia_fatos <- function(id, epoca = "SON", variavel = "temperatura_c", ano = 2025L, raiz = ".") {
  stopifnot(length(id) == 1L, is.character(id), !is.na(id),
    length(epoca) == 1L, epoca %in% c("SON", "DJF", "MAM", "JJA"),
    length(variavel) == 1L, variavel %in% c("temperatura_c", "precipitacao_mm_mes"),
    length(ano) == 1L, is.numeric(ano), is.finite(ano), ano == as.integer(ano))
  e <- new.env(parent = globalenv())
  for (f in c("R/ler_mundial.R", "R/validar_piloto.R", "prototipo_revisado/explorador.R"))
    sys.source(file.path(raiz, f), envir = e)
  x <- e$ler_ponto_mundial(id, raiz)
  d <- e$preparar_sazonal(x$mensal)
  a <- dplyr::bind_rows(lapply(unique(d$fonte), function(f)
    dplyr::mutate(e$serie_temporadas(d[d$fonte == f & d$estacao == epoca, ], variavel), fonte = f)))
  s <- a[a$ano_sazonal == ano, ]
  stopifnot(nrow(s) == nrow(x$fontes), all(is.finite(s$valor)), all(is.finite(s$referencia)))
  pares <- merge(a[a$fonte == "POWER", c("ano_sazonal", "valor")],
                 a[a$fonte == "ERA5", c("ano_sazonal", "valor")], by = "ano_sazonal")
  unidade <- if (variavel == "temperatura_c") "°C" else "mm/trimestre"
  n <- function(v, lang) formatC(v, digits = 2, format = "f", decimal.mark = if (lang == "pt") "," else ".")
  textos <- function(lang) {
    pt <- lang == "pt"
    unidade <- if (!pt && variavel != "temperatura_c") "mm/quarter" else unidade
    medida <- if (variavel == "temperatura_c") {
      if (pt) "temperatura média do ar" else "mean air temperature"
    } else if (pt) "chuva acumulada" else "total rainfall"
    valores <- paste(vapply(seq_len(nrow(s)), function(i) sprintf("%s: %s %s", s$fonte[i], n(s$valor[i], lang), unidade), ""), collapse = "; ")
    anomalias <- paste(vapply(seq_len(nrow(s)), function(i) {
      if (pt) sprintf("%s: valor %s; referência %s; diferença %s %s", s$fonte[i], n(s$valor[i], lang), n(s$referencia[i], lang), n(s$diferenca[i], lang), unidade)
      else sprintf("%s: value %s; baseline %s; difference %s %s", s$fonte[i], n(s$valor[i], lang), n(s$referencia[i], lang), n(s$diferenca[i], lang), unidade)
    }, ""), collapse = "; ")
    list(
      scope = if (pt) sprintf("%s · %s · %s · %s. Consulta %s/%s, ano sazonal; base disponível %s–%s.", x$ponto$cidade, x$ponto$pais, medida, unidade, epoca, ano, min(a$ano_sazonal), max(a$ano_sazonal)) else sprintf("%s · %s · %s · %s. %s/%s seasonal-year query; available years %s–%s.", x$ponto$cidade, x$ponto$pais, medida, unidade, epoca, ano, min(a$ano_sazonal), max(a$ano_sazonal)),
      values = paste(ano, valores, if (pt) "São valores absolutos, não diferenças da média." else "These are absolute values, not anomalies."),
      anomalies = paste(ano, anomalias, if (pt) "Diferença = valor menos referência própria de 1991–2020 para os mesmos meses. Não é efeito do ENSO nem teste de significância." else "Difference = value minus each source's own 1991–2020 baseline for the same months. This is not an ENSO effect or a significance test."),
      comparison = if (nrow(pares)) {
        gap <- n(mean(abs(pares$valor.x - pares$valor.y)), lang)
        if (pt) sprintf("Distância absoluta média POWER/ERA5: %s %s em %s temporadas pareadas. Não é a diferença apenas de %s e não indica qual fonte é mais precisa.", gap, unidade, nrow(pares), ano)
        else sprintf("Mean absolute POWER/ERA5 gap: %s %s across %s paired seasons. This is not the gap for %s alone and does not rank source accuracy.", gap, unidade, nrow(pares), ano)
      } else if (pt) "Comparação indisponível; ausência não é zero." else "Comparison unavailable; missing is not zero.",
      units = if (variavel == "temperatura_c") {
        if (pt) "Temperatura: média das três médias mensais, com pesos iguais, em °C." else "Temperature: equally weighted mean of three monthly means, in °C."
      } else if (pt) "Chuva: soma dos três totais mensais em mm/trimestre. 1 mm equivale a 1 litro por m²; não é chuva diária." else "Rainfall: sum of three monthly totals in mm/quarter. 1 mm equals 1 litre per m²; this is not daily rainfall.",
      season = if (pt) "SON: setembro–novembro; DJF: dezembro–fevereiro; MAM: março–maio; JJA: junho–agosto. Em DJF, dezembro pertence ao ano seguinte; só entram trimestres completos. DJF/1981 não está disponível." else "SON: September–November; DJF: December–February; MAM: March–May; JJA: June–August. In DJF, December belongs to the following seasonal year; only complete quarters are used. DJF/1981 is unavailable.",
      enso = if (pt) "ENSO inclui El Niño, La Niña e condições neutras no Pacífico tropical. Não há associação mundial liberada nesta consulta: o histórico não permite atribuir as diferenças ao El Niño nem provar ausência de relação." else "ENSO includes El Niño, La Niña and neutral conditions in the tropical Pacific. No global ENSO association is released for this query: this history cannot attribute differences to El Niño or prove no relationship exists.",
      forecast = if (pt) "O painel não fornece previsão para o próximo ano, risco de enchente ou recomendação de plantio. O último ano da base é 2025, não o tempo de hoje." else "The dashboard does not provide next-year forecasts, flood risk or planting advice. The last year in this dataset is 2025, not today's weather.",
      source_info = if (pt) "POWER é um produto NASA; ERA5 é uma reanálise ECMWF/Copernicus, aqui distribuída pela Open-Meteo/API ou AWS. São estimativas de grade próximas ao ponto, não medições de cada bairro. POWER usa calendário LST e ERA5 UTC. Relevo e representatividade podem contribuir para divergências; estações não validam automaticamente todas as cidades." else "POWER is a NASA product; ERA5 is an ECMWF/Copernicus reanalysis, distributed here via Open-Meteo/API or AWS. These are grid estimates near a reference point, not measurements for each neighbourhood. POWER uses LST and ERA5 UTC. Terrain and representativeness can contribute to discrepancies; station checks do not automatically validate every city.",
      integrity = if (pt) "A prova Stellar Testnet r7 verifica os arquivos listados naquela release congelada. Não comprova exatidão climática, causa ENSO, autoria civil ou esta resposta nova da IA; a Testnet pode reiniciar." else "The r7 Stellar Testnet proof verifies listed files in that frozen release. It does not establish climate accuracy, ENSO causality, civil authorship or this new AI answer; the Testnet can reset.",
      missing = if (pt) "Essa informação não está disponível no recorte selecionado. Não vou substituir ausência por zero ou inventar valores; selecione local, medida e ano disponíveis." else "That information is unavailable in the selected query. Missing data cannot be replaced by zero or invented values; choose an available location, measure and year.",
      unclear = if (pt) "Preciso de uma pergunta mais específica sobre o local, a medida e a época selecionados. Posso explicar valores, diferenças, fontes e limites desta consulta." else "Please ask a more specific question about the selected location, measure and season. I can explain values, anomalies, sources and limits of this query.",
      limits = if (pt) "Descrição retrospectiva de células de grade; não demonstra causa nem prevê o futuro." else "Retrospective description of grid cells; it does not establish causality or forecast the future."
    )
  }
  list(query = list(id = id, cidade = x$ponto$cidade, epoca = epoca, variavel = variavel, ano = ano),
    numbers = as.data.frame(s), monthly_sha256 = x$ponto$sha256,
    sources = as.data.frame(x$fontes[c("fonte", "url", "sha256_mensal", "calendario")]),
    evidence = list(pt = textos("pt"), en = textos("en")))
}
