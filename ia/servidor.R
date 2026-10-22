source(file.path(root_enso, "ia/fatos.R"), encoding = "UTF-8", local = TRUE)
source(file.path(root_enso, "ia/fatos_publicos.R"), encoding = "UTF-8", local = TRUE)
source(file.path(root_enso, "ia/deepseek.R"), encoding = "UTF-8", local = TRUE)
enso_ai_expira <- 1794193200 # End of 08/11/2026 in Brasilia. No automatic renewal.

enso_ai_runtime <- function(root, config = NULL, worker = file.path(root, "ia/worker.R")) {
  if (is.null(config)) {
    path <- Sys.getenv("ENSO_PRIVATE_CONFIG", file.path(root, ".enso-runtime.json"))
    config <- if (file.exists(path)) tryCatch(jsonlite::read_json(path, simplifyVector = TRUE), error = function(e) list()) else list()
  }
  e <- new.env(parent = emptyenv())
  e$config <- config; e$worker <- worker; e$root <- root
  e$active <- 0L; e$requests <- numeric(); e$cache <- list()
  e
}
enso_ai_enabled <- function(state) is.character(state$config$api_key) && length(state$config$api_key) == 1L &&
  nchar(state$config$api_key) >= 10L && is.numeric(state$config$expires) && length(state$config$expires) == 1L &&
  is.finite(state$config$expires) && as.numeric(Sys.time()) < min(state$config$expires, enso_ai_expira)

enso_ai_ui <- function(lang) {
  pt <- lang == "pt"
  shiny::tags$details(class = "enso-assistente", id = "enso-assistente",
    shiny::tags$summary(shiny::tags$small(class="selo-ia",if (pt) "IA" else "AI"),shiny::tags$span(class="enso-ai-convite",shiny::tags$strong(if (pt) "Converse com os dados" else "Ask the data"),shiny::tags$span(if (pt) "Tire uma dúvida sobre o gráfico, as fontes ou o El Niño." else "Explore a question about the chart, its sources or El Niño."))),
    shiny::tags$div(class = "enso-assistente-corpo",
      shiny::tags$p(class = "enso-ai-intro", if (pt) "Pergunte sobre o que está vendo no gráfico. A resposta usa os dados da cidade, da medida e da época que você escolheu." else "Ask about what you see in the chart. Answers use the data for the place, measure and season you selected."),
      shiny::tags$div(class = "enso-ai-sugestoes", lapply(if (pt) c("O que significa a diferença da média?", "Isso foi causado pelo El Niño?", "Qual fonte é mais precisa?") else c("What does the difference from the baseline mean?", "Was this caused by El Niño?", "Which source is more accurate?"), function(q)
        shiny::tags$button(type = "button", `data-enso-question` = q, q))),
      shiny::textAreaInput("enso_question", if (pt) "Sua pergunta" else "Your question", rows = 2, width = "100%",
        placeholder = if (pt) "Por exemplo: essa diferença é a temperatura real?" else "For example: is this difference the actual temperature?"),
      shiny::tags$p(class = "enso-ai-privacidade", if (pt) "Sua pergunta e os dados desta consulta serão enviados a um serviço de IA para preparar a resposta. Evite informações pessoais. Até 500 caracteres." else "Your question and the data for this query will be sent to an AI service to prepare the answer. Avoid personal information. Up to 500 characters."),
      shiny::actionButton("enso_ask", if (pt) "Enviar pergunta" else "Ask", class = "enso-ai-enviar"),
      shiny::tags$div(id = "enso-ai-status", role = "status", `aria-live` = "polite", tabindex = "-1", shiny::uiOutput("enso_ai_answer"))))
}
enso_ai_inserir <- function(tag, lang) {
  if (inherits(tag, "shiny.tag")) {
    if (identical(tag$attribs$class, "evidencia")) tag$children <- c(tag$children, list(enso_ai_ui(lang)))
    else tag$children <- lapply(tag$children, enso_ai_inserir, lang = lang)
  } else if (is.list(tag) && !inherits(tag, "html_dependency")) tag[] <- lapply(tag, enso_ai_inserir, lang = lang)
  tag
}

enso_ai_instalar <- function(input, output, session, lang, state) {
  pt <- lang == "pt"; answer <- shiny::reactiveVal(NULL); job <- NULL; seen <- NULL; last <- 0
  message_text <- function(code) {
    if (code == "expired") return(if (pt) "O período de demonstração da IA terminou. O histórico, as fontes e os downloads continuam disponíveis." else "The AI demonstration period has ended. History, sources and downloads remain available.")
    if (code == "busy") return(if (pt) "Há consultas em processamento. Aguarde um momento e tente novamente." else "Other queries are being processed. Please wait a moment and try again.")
    if (code == "input") return(if (pt) "Escreva uma pergunta de até 500 caracteres sobre esta consulta." else "Write a question of up to 500 characters about this query.")
    if (code == "changed") return(if (pt) "A seleção mudou. Faça sua pergunta novamente para este recorte." else "The selection changed. Ask again for this query.")
    if (code == "rate") return(if (pt) "Aguarde alguns segundos antes de enviar outra pergunta." else "Please wait a few seconds before sending another question.")
    if (code == "waiting") return(if (pt) "Preparando a resposta… Você pode continuar olhando os gráficos." else "Preparing your answer… You can keep exploring the charts.")
    if (code == "http_402") return(if (pt) "O saldo de demonstração da IA está indisponível. Explore o resumo, as fontes e os downloads abaixo." else "The AI demonstration balance is unavailable. Explore the summary, sources and downloads.")
    if (code == "http_429") return(if (pt) "A IA atingiu um limite temporário. Tente mais tarde; os dados continuam disponíveis." else "AI reached a temporary limit. Try later; the data remain available.")
    if (pt) "Não foi possível consultar a IA agora. O resumo, as fontes e os downloads continuam disponíveis." else "AI could not be consulted now. The summary, sources and downloads remain available."
  }
  selection <- function() shiny::isolate(c(input$cidade, input$estacao, input$variavel, input$escala,
    if(is.null(input$ano_inspecao)) "2025" else as.character(input$ano_inspecao)))
  busy <- function(value) session$sendCustomMessage("enso-ai-status", list(busy = value))
  show_message <- function(code) answer(list(message = message_text(code)))
  show_unavailable <- function(code,facts) answer(list(message=message_text(code),fallback=facts))
  finish <- function() {
    if (!is.null(job)) {
      if (job$process$is_alive()) job$process$kill()
      job <<- NULL; state$active <- max(0L, state$active - 1L)
    }
    if (!session$isClosed()) busy(FALSE)
  }
  session$onSessionEnded(finish)
  shiny::observeEvent(list(input$cidade, input$estacao, input$variavel, input$escala, input$ano_inspecao), {
    current <- selection()
    if (!is.null(seen) && !identical(seen, current)) {
      had_answer <- !is.null(answer()) || !is.null(job)
      if (!is.null(job)) finish()
      if(had_answer) show_message("changed")
    }
    seen <<- current
  }, ignoreInit = TRUE, priority = 100)
  output$enso_ai_answer <- shiny::renderUI({
    x <- answer(); if (is.null(x)) return(NULL)
    if (!is.null(x$message)) return(shiny::tagList(shiny::tags$p(class = "enso-ai-mensagem", x$message),
      if(!is.null(x$fallback)) shiny::tags$div(class="enso-ai-conclusao",
        shiny::tags$h3(if(pt) "Resumo calculado no painel, sem interpretação por IA" else "Dashboard summary, calculated without AI interpretation"),
        shiny::tags$p(x$fallback$evidence[[lang]]$scope),
        shiny::tags$p(x$fallback$evidence[[lang]]$values),
        shiny::tags$p(x$fallback$evidence[[lang]]$anomalies),
        shiny::tags$p(x$fallback$evidence[[lang]]$limits))))
    shiny::tagList(
      shiny::tags$p(class = "enso-ai-origem", if (isTRUE(x$cached)) if (pt) "Resposta para a mesma consulta" else "Answer for the same query" else if (pt) "Resposta com base nos dados selecionados" else "Answer based on the selected data"),
      shiny::tags$div(class="enso-ai-conclusao",shiny::tags$h3(if(pt) "O que podemos dizer" else "What we can say"),
        shiny::tags$p(if(x$result$intent=="value") {
          if(pt) paste("Os valores abaixo descrevem o trimestre escolhido em",x$facts$query$ano) else paste("The values below describe the selected season in",x$facts$query$ano)
        } else if(x$result$intent=="anomaly") {
          if(pt) "A diferença compara o valor com a média dos mesmos meses em 1991–2020, em cada fonte. Não é efeito do ENSO (El Niño ou La Niña) nem teste de significância." else "The difference compares the value with the same months in each source's 1991–2020 baseline. This is not an ENSO effect or a significance test."
        } else x$facts$evidence[[lang]][[ia_intencoes[[x$result$intent]]]])),
      shiny::tags$p(class="enso-ai-recorte",x$facts$evidence[[lang]]$scope),
      if(x$result$intent %in% c("value","anomaly","comparison","units","season")) shiny::tags$div(class="enso-ai-numeros",lapply(order(match(x$facts$numbers$fonte,c("POWER","ERA5"))),function(i) {
        d <- x$facts$numbers[i,]; n <- function(v) formatC(v,digits=2,format="f",decimal.mark=if(pt) "," else ".")
        u <- if(x$facts$query$variavel=="temperatura_c") "°C" else if(pt) "mm/trimestre" else "mm/quarter"
        shiny::tags$section(class=paste("enso-ai-numero",tolower(d$fonte)),shiny::tags$h4(d$fonte),
          shiny::tags$p(class="enso-ai-valor",paste(n(d$valor),u)),
          shiny::tags$p(paste(if(pt) "Referência 1991–2020:" else "1991–2020 baseline:",n(d$referencia),u)),
          shiny::tags$p(paste(if(pt) "Diferença da média:" else "Difference from baseline:",n(d$diferenca),u)))
      })),
      shiny::tags$p(class="enso-ai-limite",shiny::tags$strong(if(pt) "Limite desta leitura. " else "Reading limit. "),x$facts$evidence[[lang]]$limits),
      shiny::tags$div(class = "enso-ai-fontes", lapply(seq_len(nrow(x$facts$sources)), function(i) {
        url <- x$facts$sources$url[i]
        if (grepl("^https://", url)) shiny::tags$a(href = url, target = "_blank", rel = "noopener", paste(x$facts$sources$fonte[i], "↗"))
      })))
  })
  shiny::observeEvent(input$enso_ask, {
    if (!is.null(job)) return()
    q <- input$enso_question
    if (!is.character(q) || length(q) != 1L || is.na(q)) { show_message("input"); return() }
    q <- trimws(q)
    if (!nzchar(q) || nchar(q) > 500L || nchar(q, type = "bytes") > 2000L) { show_message("input"); return() }
    sel <- selection()
    if (length(sel) != 5L || anyNA(sel)) { show_message("input"); return() }
    seen <<- sel
    f <- tryCatch(ia_fatos_publicos(sel[1], sel[2], sel[3], sel[4], state$root, ano=as.integer(sel[5])), error = function(e) NULL)
    if (is.null(f)) { show_message("input"); return() }
    f <- ia_preparar_ranking(f,q)
    key <- digest::digest(list(q, f, lang, ia_prompt_versao), algo = "sha256")
    if (!is.null(state$cache[[key]])) { answer(c(state$cache[[key]], list(cached = TRUE))); return() }
    if (!enso_ai_enabled(state)) { show_unavailable(if (as.numeric(Sys.time()) >= enso_ai_expira) "expired" else "unavailable",f); return() }
    now <- as.numeric(Sys.time()); state$requests <- state$requests[state$requests > now - 60]
    if (now - last < 5) { show_message("rate"); return() }
    if (state$active >= 3L || length(state$requests) >= 30L) { show_message("busy"); return() }
    payload <- ia_payload(q, f, lang)
    if (nchar(jsonlite::toJSON(payload, auto_unbox = TRUE), type = "bytes") > 18000L) { show_message("input"); return() }
    p <- NULL
    result <- tryCatch({
      env <- Sys.getenv(); env["R_LIBS"] <- paste(.libPaths(), collapse = .Platform$path.sep)
      p <- processx::process$new(file.path(R.home("bin"), "Rscript"), c("--vanilla", state$worker),
        wd = state$root, env = env, stdin = "|", stdout = "|", stderr = "|", cleanup = TRUE, cleanup_tree = TRUE, windows_hide_window = TRUE)
      p$write_input(paste0(jsonlite::toJSON(list(payload = payload, language = lang,
        api_key = state$config$api_key, expires = min(state$config$expires, enso_ai_expira)), auto_unbox = TRUE), "\n"))
      list(process = p, selection = sel, facts = f, question = q, key = key, started = now)
    }, error = function(e) { if (!is.null(p) && p$is_alive()) p$kill(); NULL })
    if (is.null(result)) { show_message("unavailable"); return() }
    job <<- result; state$active <- state$active + 1L; state$requests <- c(state$requests, now); last <<- now
    show_message("waiting"); busy(TRUE)
    pid <- result$process$get_pid()
    poll <- function() {
      if (is.null(job) || session$isClosed() || job$process$get_pid() != pid) return()
      if (job$process$is_alive() && as.numeric(Sys.time()) - job$started < 45) { later::later(poll, .12); return() }
      task <- job
      if (task$process$is_alive()) { finish(); show_message("unavailable"); return() }
      raw <- task$process$read_all_output()
      response <- tryCatch(if (nchar(raw, type = "bytes") <= 16384L) jsonlite::fromJSON(raw, simplifyVector = FALSE) else NULL, error = function(e) NULL)
      # Operational counts only: never log questions, answers, provider errors or credentials.
      usage <- response$usage
      if (is.numeric(usage$prompt_tokens) && is.numeric(usage$completion_tokens))
        cat("ENSO_AI_USAGE ", jsonlite::toJSON(list(at = format(Sys.time(), tz = "UTC", usetz = TRUE),
          model = "deepseek-flash", prompt_tokens = usage$prompt_tokens,
          completion_tokens = usage$completion_tokens), auto_unbox = TRUE), "\n", sep = "")
      finish()
      if (!identical(task$selection, selection())) { show_message("changed"); return() }
      r <- tryCatch(ia_responder(task$question, task$facts, lang, transporte = function(payload) response), error = function(e) NULL)
      if (is.null(r) || !isTRUE(r$ok)) { show_unavailable(if (!is.null(r$error)) r$error else "unavailable",task$facts); return() }
      r$audit$seconds <- as.numeric(Sys.time()) - task$started
      entry <- list(result = r, facts = task$facts)
      state$cache[[task$key]] <- entry
      if (length(state$cache) > 200L) state$cache <- tail(state$cache, 200L)
      answer(c(entry, list(cached = FALSE)))
    }
    later::later(poll, .12)
  }, ignoreInit = TRUE)
}
