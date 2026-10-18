# Keep internal column names stable; translate only the exported copy.
export_names <- c(ano_sazonal="season_year",valor="value",referencia="reference",diferenca="difference",
  fonte="source",cidade="city",pais="country",estacao="season",variavel="variable",unidade="unit",
  referencia_periodo="reference_period",interpretacao="interpretation",calendario="calendar",
  sha256_original="original_sha256",sha256_mensal="monthly_sha256",data="date",ano="year",mes="month",
  temperatura_c="air_temperature_c",precipitacao_mm_mes="rainfall_mm_month",cidade_id="city_id",
  unidade_temperatura="temperature_unit",unidade_chuva="rainfall_unit",
  temperatura_referencia_c="reference_air_temperature_c",precipitacao_referencia_mm_mes="reference_rainfall_mm_month",
  temperatura_anomalia_c="air_temperature_anomaly_c",precipitacao_anomalia_mm_mes="rainfall_anomaly_mm_month")
english_export <- function(x) {
  if ("variavel" %in% names(x)) x$variavel <- ifelse(x$variavel=="temperatura_c","air_temperature_c","rainfall_mm_month")
  if ("unidade" %in% names(x)) x$unidade <- sub("mm/trimestre","mm/season",x$unidade,fixed=TRUE)
  if ("status" %in% names(x)) x$status <- "exploratory; no global observational validation"
  n <- names(x); matched <- n %in% names(export_names); n[matched] <- unname(export_names[n[matched]]); names(x) <- n
  x
}
write_excel_csv2 <- function(x,file,...) readr::write_excel_csv(english_export(x),file,...)
unidade_grafico <- function(v) if(v=="temperatura_c") "°C" else "mm"
