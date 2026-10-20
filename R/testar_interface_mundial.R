if (.Platform$OS.type == "windows") Sys.setlocale("LC_ALL", "English_United States.utf8")
setwd("prototipo_mundial")
source("app.R", encoding="UTF-8")
for(id in c("GN-3445133","GN-3041563",indice$id[indice$pais_iso2=="NA"][1])) {
  x <- ler_ponto_mundial(id,"..")
  for(epoca in names(rotulos_estacao)) for(v in c("temperatura_c","precipitacao_mm_mes")) {
    a <- exportar_mundial(x,epoca,v)
    stopifnot(nrow(a)==if(epoca=="DJF") 44*nrow(x$fontes) else 45*nrow(x$fontes),
      all(is.finite(a$valor)),!anyNA(a$url),setequal(a$fonte,x$fontes$fonte),
      all(a$diferenca==a$valor-a$referencia))
  }
}
source("../R/fixture_fonte_unica.R")
fixture <- fixture_fonte_unica(indice, ler_ponto_mundial)
indice <- fixture$indice
ler_ponto_mundial <- fixture$leitor
testServer(server, {
  unica <- indice[indice$fontes=="POWER", ][1, ]
  stopifnot(nrow(unica)==1L,!is.na(unica$id))
  session$setInputs(pais=unica$pais_iso2,cidade=unica$id,estacao="SON",variavel="temperatura_c",escala="valor")
  stopifnot(nrow(serie())==45,grepl("ainda não adquirido",output$disponibilidade$html))
  h <- jsonlite::fromJSON(output$historico,simplifyVector=FALSE)
  stopifnot(length(h$x$data)==1)
  deps <- h$deps
  stopifnot(any(vapply(deps,function(d) any(grepl("plotly-basic",unlist(d))),logical(1))))
  session$setInputs(pais="AD",cidade="GN-3041563",estacao="DJF",variavel="precipitacao_mm_mes",escala="diferenca")
  stopifnot(nrow(serie())==88,grepl("duas fontes",output$disponibilidade$html))
  h <- jsonlite::fromJSON(output$historico,simplifyVector=FALSE)
  stopifnot(length(h$x$data)==2)
  stopifnot(grepl("Ainda não calculada",output$resumo_local$html))
  a <- serie(); esperado <- comparar_mundial(a)
  stopifnot(identical(esperado,comparar_mundial(a[nrow(a):1,])),esperado$n==44)
  falta <- a[-1,]
  stopifnot(inherits(try(comparar_mundial(falta),silent=TRUE),"try-error"))
  ficha <- ficha_mundial(ponto(),"DJF","precipitacao_mm_mes")
  stopifnot(any(grepl("mm/trimestre",ficha,fixed=TRUE)),
    any(grepl("Inferência mundial não liberada",ficha,fixed=TRUE)),
    all(vapply(ponto()$fontes$sha256_mensal,function(h) any(grepl(h,ficha,fixed=TRUE)),logical(1))))
  session$setInputs(pais=unica$pais_iso2,cidade=unica$id,estacao="SON",variavel="temperatura_c")
  stopifnot(is.null(comparar_mundial(serie())),any(grepl("Somente POWER",ficha_mundial(ponto(),"SON","temperatura_c"))))
  out <- exportar_mundial(ponto(),"SON","temperatura_c")
  stopifnot(all(out$referencia_periodo=="1991-2020"),all(is.finite(out$latitude)))
  # A globe click keeps the target city when the browser subsequently updates country.
  session$setInputs(globo_selecao="GN-3445133")
  stopifnot(identical(destino_globo(),"GN-3445133"))
  session$setInputs(pais="BR")
  stopifnot(is.null(destino_globo()))
  session$setInputs(cidade="GN-3445133")
  stopifnot(ponto()$ponto$cidade=="Viçosa")
  session$setInputs(globo_selecao="not-a-catalogue-id")
  stopifnot(is.null(destino_globo()),ponto()$ponto$cidade=="Viçosa")
})
cat("PASS: agregações, exportação, fonte única/dupla, ausência, DJF e servidor reativo.\n")
