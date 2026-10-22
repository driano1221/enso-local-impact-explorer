if(.Platform$OS.type=="windows")invisible(Sys.setlocale("LC_ALL","English_United States.utf8"))
app <- source(if(file.exists("publicacao/app.R"))"publicacao/app.R"else"app.R",encoding="UTF-8")$value
source("R/fases_enso.R",encoding="UTF-8")
data <- enso_leitura(root_enso);d <- data$summary
stopifnot(nrow(d)==65664L,length(unique(d$id))==684L,all(is.finite(d$media)),all(d$q1<=d$q3),all(d$n>0))
counts <- aggregate(n~id+estacao+variavel+indice+fonte,d,sum)
stopifnot(all(counts$n==ifelse(counts$estacao=="DJF",44L,45L)))
phases <- data$phases
for(year in c(1983,1998)) stopifnot(phases$fase[phases$indice=="RONI" & phases$ano==year & phases$estacao=="DJF"]=="nino")
for(lang in c("pt","en")) {
  env <- environment(apps_enso[[lang]]$server)
  x <- env$ler_ponto_mundial("WUP-1014",root_enso)
  a <- env$series_mundiais(x,"DJF","precipitacao_mm_mes")
  stopifnot(abs(a$valor[a$fonte=="POWER" & a$ano_sazonal==1983]-2.17)<1e-10,
    abs(a$valor[a$fonte=="ERA5" & a$ano_sazonal==1983]-208.30000267922878)<1e-8)
  temp <- tempfile(fileext=".csv")
  env$escrever_csv_publico(env$exportar_mensal_publico(x,lang),temp)
  header <- readLines(temp,n=1,warn=FALSE)
  stopifnot(grepl(if(lang=="en")"original_sha256" else "sha256_original",header,fixed=TRUE))
  env$escrever_csv_publico(data.frame(value=540.3000000000001),temp)
  stopifnot(grepl(if(lang=="en")"540.3" else "540,3",paste(readLines(temp,warn=FALSE),collapse="\n"),fixed=TRUE))
  unlink(temp)
  html <- htmltools::renderTags(enso_integridade_inserir(enso_ai_inserir(apps_enso[[lang]]$ui,lang),lang))$html
  stopifnot(grepl('id="verificar-dados"',html,fixed=TRUE),grepl('id="enso-historico"',html,fixed=TRUE),
    grepl('id="sobre-projeto"',html,fixed=TRUE),!grepl("deepseek",html,ignore.case=TRUE),
    grepl('data-local-csv',html,fixed=TRUE),!grepl('id="proof-file"',html,fixed=TRUE))
  shiny::testServer(apps_enso[[lang]]$server,{
    session$setInputs(pais="PE",cidade="WUP-1014",estacao="DJF",variavel="precipitacao_mm_mes",escala="valor",ano_inspecao=1983)
    stopifnot(grepl("1983",output$resumo_valor$html),grepl(if(lang=="pt")"208,3" else "208.3",output$resumo_valor$html,fixed=TRUE))
  })
}
shiny::testServer(function(input,output,session)enso_historico_instalar(input,output,session,"pt",root_enso),{
  session$setInputs(cidade="WUP-1014",estacao="DJF",variavel="precipitacao_mm_mes",ano_inspecao=1983)
  html <- output$enso_historico$html
  stopifnot(grepl("1983",html),grepl("El Niño",html,fixed=TRUE),grepl("não um intervalo de confiança",html,fixed=TRUE),grepl("n =",html,fixed=TRUE))
})
cat("PASS: all684 phase summaries/counts, known episodes, Trujillo raw totals, PT/EN export contracts, rounding, inspected-year cards and shared evidence UI.\n")
