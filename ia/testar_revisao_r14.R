if(.Platform$OS.type=="windows") invisible(Sys.setlocale("LC_ALL","English_United States.utf8"))
app <- source(if(file.exists("publicacao/app.R"))"publicacao/app.R"else"app.R",encoding="UTF-8")$value
f <- ia_fatos_publicos("WUP-7802","SON","temperatura_c",raiz=".",ano=2015L)
stopifnot(f$query$ano==2015,abs(f$numbers$valor[f$numbers$fonte=="POWER"]-24.05)<1e-8,
  grepl("2023",f$evidence$en$year_extremes),grepl("2015",f$evidence$pt$scope))
for(lang in c("pt","en")) {
  b <- nchar(jsonlite::toJSON(ia_payload("Which year was the warmest in each source?",f,lang),auto_unbox=TRUE),type="bytes")
  cat(lang,"payload bytes",b,"\n");stopifnot(b<18000)
}
cat("PASS: inspected2015 values, historical extrema and bounded bilingual payload.\n")
state <- enso_ai_runtime(root_enso,list(api_key="DUMMY_NOT_A_PROVIDER_KEY",expires=1794193200),file.path(root_enso,"ia/testes/worker_fake.R"))
shiny::testServer(function(input,output,session) enso_ai_instalar(input,output,session,"pt",state),{
  session$setInputs(cidade="WUP-7802",estacao="SON",variavel="temperatura_c",escala="valor",ano_inspecao=2015,
    enso_question="Qual foi a temperatura em2015?")
  session$setInputs(enso_ask=1)
  stopifnot(state$active==1L)
  start <- Sys.time()
  while(state$active && as.numeric(difftime(Sys.time(),start,units="secs"))<20){later::run_now(.1);session$flushReact()}
  later::run_now(.1);session$flushReact()
  stopifnot(grepl("24,05",output$enso_ai_answer$html,fixed=TRUE),grepl("2015",output$enso_ai_answer$html,fixed=TRUE))
  # A new year and Ask arriving in the same reactive flush must not cancel the new job.
  Sys.sleep(5.1)
  session$setInputs(ano_inspecao=2023,enso_question="Qual foi a temperatura no ano consultado?",enso_ask=2)
  stopifnot(state$active==1L)
  start <- Sys.time()
  while(state$active && as.numeric(difftime(Sys.time(),start,units="secs"))<20){later::run_now(.1);session$flushReact()}
  later::run_now(.1);session$flushReact()
  stopifnot(grepl("2023",output$enso_ai_answer$html,fixed=TRUE),!grepl("A seleção mudou",output$enso_ai_answer$html,fixed=TRUE))
})
cat("PASS: session routes inspected2015 without using2025.\n")
