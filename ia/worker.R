# Private input arrives over stdin, never arguments/files/browser. stdout is sanitized JSON.
if (.Platform$OS.type == "windows") invisible(Sys.setlocale("LC_ALL", "English_United States.utf8"))
source("ia/deepseek.R", encoding = "UTF-8")
run <- function() {
  input <- jsonlite::fromJSON(readLines(file("stdin"), n = 1L, warn = FALSE), simplifyVector = FALSE)
  if (as.numeric(Sys.time()) >= min(input$expires, 1794193200)) return(list(error = "expired"))
  payload <- input$payload
  bytes <- nchar(jsonlite::toJSON(payload, auto_unbox = TRUE), type = "bytes")
  stopifnot(identical(payload$model, "deepseek-flash"), payload$max_tokens == 400,
    identical(payload$thinking$type, "disabled"), bytes <= 18000L,
    length(input$api_key) == 1L, is.character(input$api_key), nchar(input$api_key) >= 10L)
  Sys.setenv(DEEPSEEK_API_KEY = input$api_key)
  on.exit(Sys.unsetenv("DEEPSEEK_API_KEY"))
  r <- ia_http(payload)
  if (!is.null(r$error)) return(list(error = r$error))
  intent <- ia_validar(r, input$language)
  usage <- lapply(c("prompt_tokens", "completion_tokens"), function(n) {
    v <- r$usage[[n]]
    if (is.numeric(v) && length(v) == 1L && is.finite(v) && v >= 0 && v <= 1000000) v else NULL
  })
  names(usage) <- c("prompt_tokens", "completion_tokens")
  if (is.null(intent)) return(list(error = "invalid_output", usage = usage))
  # Never return provider reasoning, raw errors, headers or keys to the parent process.
  list(choices = list(list(finish_reason = "stop", message = list(content = as.character(jsonlite::toJSON(
    list(language = input$language, intent = intent, evidence_ids = list(unname(ia_intencoes[[intent]]))), auto_unbox = TRUE))))), usage = usage)
}
result <- tryCatch(run(), error = function(e) list(error = "worker_error"))
cat(jsonlite::toJSON(result, auto_unbox = TRUE, null = "null", na = "null", digits = NA))
