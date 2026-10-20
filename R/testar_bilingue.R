if(.Platform$OS.type=="windows") Sys.setlocale("LC_ALL","English_United States.utf8")
app <- source(if(file.exists("publicacao/app.R")) "publicacao/app.R" else "app.R",encoding="UTF-8")$value
stopifnot(inherits(app,"shiny.appobj"),idioma_enso("?lang=pt-br")=="pt",idioma_enso("?lang=en")=="en",idioma_enso("?lang=invalid")=="en")
stopifnot("vendor" %in% names(shiny::resourcePaths()),file.exists(file.path(shiny::resourcePaths()[["vendor"]],"flags/br.svg")))
query_ui <- htmltools::renderTags(escala_inicial_ui(apps_enso$en$ui,"diferenca"))$html
stopifnot(grepl('value="diferenca" checked',query_ui,fixed=TRUE),!grepl('value="valor" checked',query_ui,fixed=TRUE))
for(lang in c("pt","en")) {
  rendered <- htmltools::renderTags(apps_enso[[lang]]$ui)
  html <- paste(rendered$head,rendered$html)
  stopifnot(grepl(paste0("ui-",lang,"/preferencias.js"),html,fixed=TRUE),
    grepl("data-language",html,fixed=TRUE),grepl("ajuda-epoca",html,fixed=TRUE),!grepl("status-historico",html,fixed=TRUE))
  x <- apps_enso[[lang]]
  shiny::testServer(x$server, {
    session$setInputs(pais="BR",cidade="WUP-7802",estacao="SON",variavel="temperatura_c",escala="valor")
    stopifnot(grepl("22",output$resumo_valor$html),grepl("ajuda-power",output$resumo_valor$html),
      grepl("ajuda-era5",output$disponibilidade$html),!grepl("status-historico",output$disponibilidade$html))
    a <- serie();stopifnot(nrow(a)==90,setequal(unique(a$fonte),c("POWER","ERA5")))
  })
}
cat("PASS: bilingual route validation, language-specific resources, tooltips and existing climate calculations.\n")
