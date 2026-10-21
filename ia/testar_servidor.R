if (.Platform$OS.type == "windows") invisible(Sys.setlocale("LC_ALL", "English_United States.utf8"))
app <- source(if (file.exists("publicacao/app.R")) "publicacao/app.R" else "app.R", encoding = "UTF-8")$value
state <- enso_ai_runtime(root_enso, list(api_key = "DUMMY_NOT_A_PROVIDER_KEY", expires = 1794193200), file.path(root_enso, "ia/testes/worker_fake.R"))
for (lang in c("pt", "en")) {
  ui <- htmltools::renderTags(enso_ai_inserir(apps_enso[[lang]]$ui, lang))$html
  stopifnot(length(gregexpr('id="enso-assistente"', ui, fixed = TRUE)[[1]]) == 1L,
    !grepl("DUMMY_NOT_A_PROVIDER_KEY", ui, fixed = TRUE), !grepl("deepseek", ui, ignore.case = TRUE))
}
original <- ia_fatos("WUP-7802", "SON", "temperatura_c")
publico <- ia_fatos_publicos("WUP-7802", "SON", "temperatura_c")
stopifnot(identical(original$numbers, publico$numbers), identical(original$sources, publico$sources),
  grepl("Brasil", publico$evidence$pt$scope, fixed = TRUE), grepl("°C. São", publico$evidence$pt$values, fixed = TRUE))
shiny::testServer(function(input, output, session) {
  enso_ai_instalar(input, output, session, "pt", state)
  output$heartbeat <- shiny::renderText(input$test_tick)
}, {
  session$setInputs(cidade = "WUP-7802", estacao = "SON", variavel = "temperatura_c", escala = "valor", enso_question = "A diferença é a temperatura real?")
  session$setInputs(enso_ask = 1)
  stopifnot(state$active == 1L)
  session$setInputs(test_tick = "alive")
  stopifnot(output$heartbeat == "alive")
  start <- Sys.time()
  while (state$active && as.numeric(difftime(Sys.time(), start, units = "secs")) < 20) {
    later::run_now(.1); session$flushReact()
  }
  later::run_now(.1); session$flushReact()
  stopifnot(state$active == 0L, grepl("22,28", output$enso_ai_answer$html, fixed = TRUE),
    !grepl("DUMMY", output$enso_ai_answer$html, fixed = TRUE))
  count <- length(state$requests)
  session$setInputs(enso_ask = 2)
  stopifnot(state$active == 0L, length(state$requests) == count,
    grepl("mesma consulta", output$enso_ai_answer$html, fixed = TRUE))
  session$setInputs(cidade = "GN-3445133")
  stopifnot(grepl("seleção mudou", output$enso_ai_answer$html, fixed = TRUE))
  session$setInputs(enso_question = list(a = "bad", b = "bad"), enso_ask = 3)
  stopifnot(state$active == 0L, grepl("500", output$enso_ai_answer$html, fixed = TRUE))
})
cancel_state <- enso_ai_runtime(root_enso, list(api_key = "DUMMY_NOT_A_PROVIDER_KEY", expires = 1794193200), file.path(root_enso, "ia/testes/worker_fake.R"))
shiny::testServer(function(input, output, session) {
  enso_ai_instalar(input, output, session, "en", cancel_state)
}, {
  session$setInputs(cidade = "WUP-7802", estacao = "SON", variavel = "temperatura_c", escala = "valor", enso_question = "Difference from baseline?")
  session$setInputs(enso_ask = 1)
  stopifnot(cancel_state$active == 1L)
  session$setInputs(cidade = "GN-3445133")
  stopifnot(cancel_state$active == 0L)
  later::run_now(1.5); session$flushReact()
  stopifnot(grepl("selection changed", output$enso_ai_answer$html, fixed = TRUE), length(cancel_state$cache) == 0L)
})
state$config$expires <- 1
stopifnot(!enso_ai_enabled(state))
state$config <- list()
stopifnot(!enso_ai_enabled(state))
cat("PASS: selection facts unchanged, country/punctuation, typed input, nonblocking subprocess, cache/no new call, selection invalidation, no credential in UI, missing config. No API charges.\n")
