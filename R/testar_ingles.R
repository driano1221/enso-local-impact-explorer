if (.Platform$OS.type == "windows") Sys.setlocale("LC_ALL","English_United States.utf8")
root <- getwd()
pt <- new.env(parent=globalenv()); en <- new.env(parent=globalenv())
setwd(file.path(root,"prototipo_mundial")); source("app.R",local=pt,encoding="UTF-8")
setwd(file.path(root,"prototipo_mundial_en")); source("app.R",local=en,encoding="UTF-8")
ids <- c("GN-3445133","GN-3040686","WUP-2994")
for(id in ids) for(season in c("SON","DJF","MAM","JJA")) for(variable in c("temperatura_c","precipitacao_mm_mes")) {
  x <- en$ler_ponto_mundial(id,"..")
  original <- pt$series_mundiais(x,season,variable)
  translated <- en$series_mundiais(x,season,variable)
  stopifnot(identical(original,translated), identical(pt$comparar_mundial(original),en$comparar_mundial(translated)))
  export <- en$english_export(en$exportar_mundial(x,season,variable))
  stopifnot(identical(export$value,original$valor),identical(export$difference,original$diferenca),
    all(export$interpretation=="Descriptive historical records; not a forecast or an ENSO effect"),
    all(export$variable==if(variable=="temperatura_c") "air_temperature_c" else "rainfall_mm_month"))
  file <- tempfile(fileext=".csv"); en$write_excel_csv2(en$exportar_mundial(x,season,variable),file)
  roundtrip <- readr::read_csv(file,show_col_types=FALSE)
  stopifnot(isTRUE(all.equal(roundtrip$value,original$valor)),all(c("source","monthly_sha256","reference_period") %in% names(roundtrip)))
  sheet <- en$ficha_mundial(x,season,variable)
  stopifnot(any(grepl("Global inference has not been released",sheet)),!any(grepl("Temperatura:|Chuva:|Referência:",sheet)))
}
stopifnot(en$num(23.5)=="23.5",pt$num(23.5)=="23,5")
source(file.path(root,"R/fixture_fonte_unica.R"))
fixture <- fixture_fonte_unica(en$indice,en$ler_ponto_mundial)
en$indice <- fixture$indice
en$ler_ponto_mundial <- fixture$leitor
shiny::testServer(en$server, {
  session$setInputs(pais="BR",cidade="GN-3445133",estacao="SON",variavel="temperatura_c",escala="valor")
  stopifnot(grepl("Mean air temperature",output$resumo_valor$html),grepl("About POWER",output$disponibilidade$html),!grepl("status-historico",output$disponibilidade$html))
  chart <- jsonlite::fromJSON(output$historico,simplifyVector=FALSE)
  stopifnot(length(chart$x$data)==2,all(grepl("Value:",unlist(lapply(chart$x$data,`[[`,"text")))))
  session$setInputs(pais="AD",cidade="GN-3040686",estacao="DJF",variavel="precipitacao_mm_mes",escala="diferenca")
  stopifnot(grepl("ERA5 not yet acquired",output$disponibilidade$html),grepl("Total rainfall",output$resumo_valor$html),nrow(serie())==44)
})
cat("PASS: 24 PT/EN comparisons, identical climate values, English CSV round trips and factsheets, reactive dual/single-source states.\n")
