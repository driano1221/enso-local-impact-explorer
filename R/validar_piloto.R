# Executar da raiz: Rscript R/validar_piloto.R. Plano congelado em competicao/experimentos/.
# Preserva os dados/modelos de 4/10; produz somente dados/validacao/ e cache próprio.
suppressPackageStartupMessages({library(dplyr); library(readr); library(tidyr)})

preparar_sazonal <- function(d) {
  stopifnot(!anyDuplicated(d[c("fonte", "cidade_id", "data")]))
  d |>
    mutate(ano = as.integer(format(data, "%Y")), mes = as.integer(format(data, "%m")),
           tendencia = ano + (mes - 1) / 12 - 2000,
           estacao = case_when(mes %in% c(12, 1, 2) ~ "DJF", mes %in% 3:5 ~ "MAM",
                               mes %in% 6:8 ~ "JJA", TRUE ~ "SON"),
           ano_sazonal = ano + as.integer(mes == 12)) |>
    group_by(fonte, cidade_id, estacao, ano_sazonal) |> filter(n() == 3L) |> ungroup() |>
    arrange(fonte, cidade_id, estacao, data)
}

desenho <- function(d, variavel, indice, quadratica = FALSE) {
  stopifnot(nrow(d) >= 30, all(diff(d$data) > 0),
            !anyNA(d[c(variavel, indice, "mes", "tendencia", "ano_sazonal")]))
  f <- if (quadratica) ~ indice + factor(mes) + tendencia + I(tendencia^2) else ~ indice + factor(mes) + tendencia
  X <- model.matrix(f, data = mutate(d, indice = .data[[indice]]))
  y <- d[[variavel]]
  m <- lm.fit(X, y)
  stopifnot(m$rank == ncol(X), all(is.finite(m$coefficients)))
  h <- rowSums(qr.Q(m$qr)^2)
  stopifnot(max(h) < .99)
  list(X = X, y = y, ajuste = m, h = h,
       w = unname(qr.coef(m$qr, diag(nrow(X)))["indice", ]),
       ano = d$ano_sazonal, data = d$data)
}

multiplicadores_dwb <- function(n, B, L, semente) {
  stopifnot(n > L, B >= 1999, L >= 1)
  set.seed(semente)
  z <- matrix(rnorm((n + L - 1L) * B), nrow = n + L - 1L)
  W <- matrix(0, n, B)
  for (j in seq_len(L)) W <- W + z[seq_len(n) + j - 1L, , drop = FALSE]
  W / sqrt(L)
}

inferir_dwb <- function(m, L = 3L, B = 9999L, semente = 20261007L) {
  anos <- unique(m$ano)
  stopifnot(all(diff(anos) == 1L))
  W <- multiplicadores_dwb(length(anos), B, L, semente)
  e <- m$ajuste$residuals / sqrt(1 - m$h)
  contribuicao <- drop(rowsum(m$w * e, m$ano, reorder = FALSE))
  delta <- drop(contribuicao %*% W)
  X0 <- m$X[, colnames(m$X) != "indice", drop = FALSE]
  nulo <- lm.fit(X0, m$y)
  e0 <- nulo$residuals / sqrt(1 - rowSums(qr.Q(nulo$qr)^2))
  delta0 <- drop(drop(rowsum(m$w * e0, m$ano, reorder = FALSE)) %*% W)
  beta <- unname(m$ajuste$coefficients["indice"])
  p <- (1 + sum(abs(delta0) >= abs(beta))) / (B + 1)
  limites <- beta - quantile(delta, c(.975, .025), names = FALSE)
  curto <- beta - quantile(head(delta, 1999L), c(.975, .025), names = FALSE)
  tibble(beta, ic95_inferior = limites[1], ic95_superior = limites[2],
         p_bruto = p, erro_mc_p = sqrt(p * (1 - p) / (B + 1)),
         ic1999_inferior = curto[1], ic1999_superior = curto[2],
         meses = length(m$y), anos = length(anos), L = L, B = B, semente = semente,
         alavancagem_max = max(m$h))
}

inferir_pares <- function(m, L = 3L, B = 3999L, semente = 20261007L) {
  set.seed(semente)
  anos <- unique(m$ano)
  linhas <- split(seq_along(m$ano), factor(m$ano, levels = anos))
  betas <- replicate(B, {
    inicios <- sample(seq_along(anos), ceiling(length(anos) / L), replace = TRUE)
    pos <- head(unlist(lapply(inicios, function(k) ((k - 1L + seq_len(L) - 1L) %% length(anos)) + 1L)), length(anos))
    idx <- unlist(linhas[pos], use.names = FALSE)
    unname(lm.fit(m$X[idx, , drop = FALSE], m$y[idx])$coefficients["indice"])
  })
  stopifnot(all(is.finite(betas)))
  q <- quantile(betas, c(.025, .975), names = FALSE)
  tibble(beta = unname(m$ajuste$coefficients["indice"]), ic95_inferior = q[1], ic95_superior = q[2], L, B)
}

distancia_km <- function(lat1, lon1, lat2, lon2) {
  a <- sin((lat2 - lat1) * pi / 360)^2 + cos(lat1*pi/180)*cos(lat2*pi/180)*sin((lon2-lon1)*pi/360)^2
  6371 * 2 * asin(pmin(1, sqrt(a)))
}

agregar_era5 <- function(j, id, nome) {
  stopifnot(!isTRUE(j$error), j$daily_units$temperature_2m_mean == "°C",
            j$daily_units$precipitation_sum == "mm", j$utc_offset_seconds == -10800)
  d <- tibble(data = as.Date(j$daily$time), temperatura_c = j$daily$temperature_2m_mean,
              precipitacao_mm_dia = j$daily$precipitation_sum)
  esperado <- seq(as.Date("1981-01-01"), as.Date("2025-12-31"), by = "day")
  stopifnot(identical(d$data, esperado), !anyDuplicated(d$data),
            all(is.finite(d$temperatura_c)), all(is.finite(d$precipitacao_mm_dia)),
            all(d$temperatura_c > -80 & d$temperatura_c < 60), all(d$precipitacao_mm_dia >= 0))
  mensal <- d |> mutate(data = as.Date(format(data, "%Y-%m-01"))) |>
    group_by(data) |> summarise(temperatura_c = mean(temperatura_c),
      precipitacao_mm_mes = sum(precipitacao_mm_dia), dias_mes = n(), .groups = "drop") |>
    mutate(cidade_id = id, cidade = nome, fonte = "ERA5")
  stopifnot(nrow(mensal) == 540L, all(mensal$dias_mes == as.integer(lubridate::days_in_month(mensal$data))))
  mensal
}

executar_validacao <- function() {
  inicio <- Sys.time()
  options(timeout = 180)
  dir.create("dados/validacao", showWarnings = FALSE)
  dir.create("dados/originais/validacao_20261007", showWarnings = FALSE)
  protocolo <- "competicao/experimentos/PROTOCOLO_VALIDACAO_20261007.md"
  entradas <- c(protocolo, "R/validar_piloto.R", "R/testar_validacao.R",
                "dados/piloto_clima_enso.csv", "dados/diagnostico_piloto.csv", "dados/revisao_piloto.csv", "dados/enso.csv")
  hashes <- tibble(arquivo = entradas, sha256 = vapply(entradas, digest::digest, "", file = TRUE, algo = "sha256"))
  manifesto <- "dados/validacao/manifesto_entrada.csv"
  if (file.exists(manifesto)) {
    anterior <- read_csv(manifesto, show_col_types = FALSE)
    stopifnot(identical(anterior$arquivo, hashes$arquivo), identical(unname(anterior$sha256), unname(hashes$sha256)))
  }
  else write_csv(hashes, manifesto)
  cidades <- read_csv("dados/revisao_piloto.csv", show_col_types = FALSE) |> arrange(cidade_id)
  power <- read_csv("dados/piloto_clima_enso.csv", show_col_types = FALSE) |>
    select(cidade_id, cidade, data, temperatura_c, precipitacao_mm_mes, dias_mes, RONI, ONI) |>
    mutate(fonte = "POWER")
  fontes <- list(); clima_era <- list()
  for (i in seq_len(nrow(cidades))) {
    c <- cidades[i, ]
    url <- sprintf(paste0("https://archive-api.open-meteo.com/v1/archive?latitude=%.5f&longitude=%.5f",
      "&start_date=1981-01-01&end_date=2025-12-31&daily=temperature_2m_mean,precipitation_sum",
      "&models=era5&timezone=Etc%%2FGMT%%2B3&elevation=nan&cell_selection=nearest&temperature_unit=celsius&precipitation_unit=mm"),
      c$latitude, c$longitude)
    arquivo <- sprintf("dados/originais/validacao_20261007/era5_%s_1981_2025.json", c$cidade_id)
    if (!file.exists(arquivo)) {
      temp <- paste0(arquivo, ".part")
      download.file(url, temp, mode = "wb", quiet = TRUE)
      j <- jsonlite::fromJSON(temp)
      stopifnot(!isTRUE(j$error), file.info(temp)$size > 0)
      agregar_era5(j, c$cidade_id, c$cidade)
      stopifnot(file.rename(temp, arquivo))
    }
    j <- jsonlite::fromJSON(arquivo)
    km <- distancia_km(c$latitude, c$longitude, j$latitude, j$longitude)
    stopifnot(km < 50)
    clima_era[[i]] <- agregar_era5(j, c$cidade_id, c$cidade)
    fontes[[i]] <- tibble(cidade_id = c$cidade_id, cidade = c$cidade, arquivo, url,
      sha256 = digest::digest(file = arquivo, algo = "sha256"),
      consultado_utc = format(file.info(arquivo)$mtime, tz = "UTC", usetz = TRUE),
      latitude_pedido = c$latitude, longitude_pedido = c$longitude,
      latitude_grade = j$latitude, longitude_grade = j$longitude, altitude_grade_m = j$elevation,
      distancia_km = km, modelo = "ERA5", resolucao_graus = .25,
      fuso = j$timezone, utc_offset_seconds = j$utc_offset_seconds,
      dias = length(j$daily$time), meses = 540L, licenca = "CC BY 4.0; Open-Meteo / ECMWF / Copernicus")
    cat("ERA5 conferido:", c$cidade, "\n")
  }
  meta <- bind_rows(fontes)
  meta_path <- "dados/validacao/fontes_era5.csv"
  if (file.exists(meta_path)) stopifnot(identical(read_csv(meta_path, show_col_types = FALSE)$sha256, meta$sha256))
  write_csv(meta, meta_path)
  era <- bind_rows(clima_era) |> left_join(select(power, cidade_id, data, RONI, ONI),
    by = c("cidade_id", "data"), relationship = "one-to-one")
  stopifnot(nrow(era) == 1620L, !anyNA(era))
  write_csv(era, "dados/validacao/era5_mensal.csv")

  # Comparação de produtos, sem recalibrar uma fonte para aproximar a outra.
  mensal <- bind_rows(power, era) |> mutate(ano = as.integer(format(data, "%Y")), mes = as.integer(format(data, "%m")))
  longo <- mensal |> pivot_longer(c(temperatura_c, precipitacao_mm_mes), names_to = "variavel", values_to = "valor")
  ref <- longo |> filter(ano >= 1991, ano <= 2020) |> group_by(fonte, cidade_id, variavel, mes) |>
    summarise(referencia = mean(valor), n = n(), .groups = "drop")
  stopifnot(all(ref$n == 30))
  pares <- longo |> left_join(select(ref, -n), by = c("fonte", "cidade_id", "variavel", "mes"), relationship = "many-to-one") |>
    mutate(anomalia = valor - referencia) |>
    select(cidade_id, cidade, data, ano, mes, variavel, fonte, valor, anomalia) |>
    pivot_wider(names_from = fonte, values_from = c(valor, anomalia)) |> arrange(cidade_id, variavel, data)
  stopifnot(nrow(pares) == 3240, !anyNA(pares))
  comparacoes <- lapply(split(pares, interaction(pares$cidade_id, pares$variavel, drop = TRUE)), function(p) {
    delta <- p$valor_ERA5 - p$valor_POWER
    r1 <- residuals(lm(valor_POWER ~ factor(mes) + ano, p))
    r2 <- residuals(lm(valor_ERA5 ~ factor(mes) + ano, p))
    tibble(cidade_id = p$cidade_id[1], cidade = p$cidade[1], variavel = p$variavel[1], n = nrow(p),
      vies = mean(delta), mae = mean(abs(delta)), rmse = sqrt(mean(delta^2)),
      cor_bruta = cor(p$valor_POWER, p$valor_ERA5), cor_anomalia = cor(p$anomalia_POWER, p$anomalia_ERA5),
      cor_sem_mes_tendencia = cor(r1, r2), media_POWER = mean(p$valor_POWER), media_ERA5 = mean(p$valor_ERA5))
  }) |> bind_rows()
  write_csv(pares, "dados/validacao/comparacao_mensal.csv")
  write_csv(comparacoes, "dados/validacao/comparacao_fontes.csv")

  b <- preparar_sazonal(mensal)
  descartes <- mensal |> anti_join(select(b, fonte, cidade_id, data), by = c("fonte", "cidade_id", "data"))
  stopifnot(nrow(descartes) == 18L, nrow(b) == 3222L)
  write_csv(descartes, "dados/validacao/meses_excluidos_djf.csv")
  setTimeLimit(elapsed = 1800, transient = TRUE)
  principal <- list(); sensibilidades <- list(); pares_boot <- list(); mc <- list(); residuos <- list(); previsoes <- list()
  k <- 0L
  for (fonte_ in c("POWER", "ERA5")) for (id in cidades$cidade_id) {
    for (epoca in c("DJF", "MAM", "JJA", "SON")) {
      d <- b |> filter(fonte == fonte_, cidade_id == id, estacao == epoca) |> arrange(data)
      stopifnot(nrow(d) == if (epoca == "DJF") 132L else 135L)
      for (v in c("temperatura_c", "precipitacao_mm_mes")) for (ind in c("RONI", "ONI")) {
        k <- k + 1L
        chave <- tibble(fonte = fonte_, cidade_id = id, cidade = d$cidade[1], estacao = epoca, variavel = v, indice = ind)
        m <- desenho(d, v, ind)
        principal[[k]] <- bind_cols(chave, inferir_dwb(m))
        mc[[k]] <- bind_cols(chave, inferir_dwb(m, semente = 20261008L))
        pares_boot[[k]] <- bind_cols(chave, inferir_pares(m))
        a <- aggregate(m$ajuste$residuals, list(ano = m$ano), mean)
        ac <- as.numeric(acf(a$x, lag.max = 5, plot = FALSE)$acf)[-1]
        residuos[[k]] <- bind_cols(chave, tibble(ano_sazonal = m$ano, data = m$data,
          ajustado = m$ajuste$fitted.values, residuo = m$ajuste$residuals,
          alavancagem = m$h, acf_ano_lag1 = ac[1], acf_ano_lag2 = ac[2], acf_ano_lag3 = ac[3],
          acf_ano_lag4 = ac[4], acf_ano_lag5 = ac[5],
          cor_abs_residuo_tempo = cor(abs(m$ajuste$residuals), d$tendencia)))
        for (cen in c("periodo_1981_2000", "periodo_2001_2025", "tendencia_quadratica", "L1", "L5")) {
          ds <- if (cen == "periodo_1981_2000") filter(d, ano_sazonal <= 2000) else
            if (cen == "periodo_2001_2025") filter(d, ano_sazonal >= 2001) else d
          L <- if (cen == "L1") 1L else if (cen == "L5") 5L else 3L
          ms <- desenho(ds, v, ind, quadratica = cen == "tendencia_quadratica")
          sensibilidades[[length(sensibilidades) + 1L]] <- bind_cols(chave, tibble(cenario = cen), inferir_dwb(ms, L))
        }
        for (corte in c(2000, 2005, 2010, 2015, 2020)) {
          treino <- d$ano_sazonal <= corte
          teste <- d$ano_sazonal > corte & d$ano_sazonal <= corte + 5
          stopifnot(sum(teste) == 15L, max(d$data[treino]) < min(d$data[teste]), !any(treino & teste))
          fit1 <- lm.fit(m$X[treino, , drop = FALSE], m$y[treino])
          X0 <- m$X[, colnames(m$X) != "indice", drop = FALSE]
          fit0 <- lm.fit(X0[treino, , drop = FALSE], m$y[treino])
          previsoes[[length(previsoes) + 1L]] <- bind_cols(chave, tibble(corte = corte,
            treino_n = sum(treino), treino_ultima_data = max(d$data[treino]), data = d$data[teste],
            ano_sazonal = d$ano_sazonal[teste], observado = m$y[teste],
            estimativa_enso = drop(m$X[teste, , drop = FALSE] %*% fit1$coefficients),
            estimativa_referencia = drop(X0[teste, , drop = FALSE] %*% fit0$coefficients)))
        }
      }
    }
    cat("Inferência e janelas concluídas:", fonte_, id, "\n")
  }
  p <- bind_rows(principal) |> mutate(p_holm_global96 = p.adjust(p_bruto, "holm"), p_by_global96 = p.adjust(p_bruto, "BY"),
                                    p_holm_principal24 = NA_real_)
  prim <- p$fonte == "POWER" & p$indice == "RONI"
  stopifnot(nrow(p) == 96, sum(prim) == 24)
  p$p_holm_principal24[prim] <- p.adjust(p$p_bruto[prim], "holm")
  s <- bind_rows(sensibilidades); pr <- bind_rows(previsoes)
  stopifnot(nrow(s) == 480L, nrow(pr) == 7200L, !anyNA(pr),
            !anyDuplicated(pr[c("fonte", "cidade_id", "estacao", "variavel", "indice", "data")]))
  write_csv(p, "dados/validacao/inferencia_principal.csv")
  write_csv(s, "dados/validacao/sensibilidades.csv")
  write_csv(bind_rows(pares_boot), "dados/validacao/bootstrap_pares.csv")
  write_csv(bind_rows(mc), "dados/validacao/monte_carlo_semente2.csv")
  write_csv(bind_rows(residuos), "dados/validacao/residuos.csv")
  write_csv(pr, "dados/validacao/estimativas_temporais.csv")
  metricas <- function(g) g |> summarise(n = n(), rmse_enso = sqrt(mean((observado-estimativa_enso)^2)),
    rmse_ref = sqrt(mean((observado-estimativa_referencia)^2)), mae_enso = mean(abs(observado-estimativa_enso)),
    mae_ref = mean(abs(observado-estimativa_referencia)), .groups = "drop") |>
    mutate(ganho_rmse_pct = 100 * (rmse_ref-rmse_enso)/rmse_ref, ganho_mae_pct = 100*(mae_ref-mae_enso)/mae_ref)
  grupos <- c("fonte", "cidade_id", "cidade", "estacao", "variavel", "indice")
  mt <- metricas(group_by(pr, across(all_of(c(grupos, "corte")))))
  total <- metricas(group_by(pr, across(all_of(grupos)))) |>
    left_join(mt |> group_by(across(all_of(grupos))) |> summarise(janelas_rmse_melhor = sum(ganho_rmse_pct > 0), .groups = "drop"),
              by = grupos, relationship = "one-to-one") |>
    mutate(ganho_temporal_na_fonte = ganho_rmse_pct > 0 & ganho_mae_pct > 0 & janelas_rmse_melhor >= 4)
  write_csv(mt, "dados/validacao/metricas_janelas.csv")
  write_csv(total, "dados/validacao/metricas_temporais.csv")
  # Não alterar os 48 ajustes originais. Comparação rastreável com o snapshot de 4/10.
  velho <- read_csv("dados/diagnostico_piloto.csv", show_col_types = FALSE)
  comparacao <- filter(p, fonte == "POWER") |> left_join(select(velho, cidade_id, estacao, variavel, indice,
    beta_piloto = beta, ic_piloto_inf = ic95_inferior, ic_piloto_sup = ic95_superior),
    by = c("cidade_id", "estacao", "variavel", "indice"), relationship = "one-to-one") |>
    mutate(diferenca_beta = beta-beta_piloto)
  stopifnot(max(abs(comparacao$diferenca_beta[comparacao$estacao != "DJF"])) < 1e-9)
  write_csv(comparacao, "dados/validacao/comparacao_piloto.csv")
  stopifnot(identical(vapply(entradas, digest::digest, "", file = TRUE, algo = "sha256"), hashes$sha256 |> setNames(entradas)))
  resumo <- list(inicio_utc = format(inicio, tz = "UTC", usetz = TRUE), fim_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
    segundos = as.numeric(difftime(Sys.time(), inicio, units = "secs")), fonte_meses = nrow(era), meses_sazonais = nrow(b),
    inferencias = nrow(p), sensibilidades = nrow(s), estimativas_temporais = nrow(pr), janelas = nrow(mt),
    holm_principal24 = sum(p$p_holm_principal24 <= .05, na.rm = TRUE), holm_global96 = sum(p$p_holm_global96 <= .05),
    metodo = "DWB HC2; multiplicadores anuais gaussianos MA(L), Bartlett; p nulo restrito; IC individual básico",
    estado = "retrospectivo exploratório; fonte alternativa não equivale a observação de estação; compreensão humana pendente")
  jsonlite::write_json(resumo, "dados/validacao/execucao.json", pretty = TRUE, auto_unbox = TRUE)
  writeLines(capture.output(sessionInfo()), "dados/validacao/ambiente_R.txt")
  print(comparacoes, width = Inf)
  print(resumo)
}

if (sys.nframe() == 0L) executar_validacao()
