# Local QA transport only; not selected by public URL or production configuration.
if (.Platform$OS.type == "windows") invisible(Sys.setlocale("LC_ALL", "English_United States.utf8"))
input <- jsonlite::fromJSON(readLines(file("stdin"), n = 1L, warn = FALSE), simplifyVector = FALSE)
Sys.sleep(1)
question <- jsonlite::fromJSON(input$payload$messages[[2]]$content)$question
if (grepl("TESTE402", question, fixed = TRUE)) {
  cat('{"error":"http_402"}')
} else {
  intent <- if (grepl("El Ni", question, fixed = TRUE)) "enso" else "anomaly"
  id <- if (intent == "enso") "enso" else "anomalies"
  message <- as.character(jsonlite::toJSON(list(language = input$language, intent = intent, evidence_ids = list(id)), auto_unbox = TRUE))
  cat(jsonlite::toJSON(list(choices = list(list(finish_reason = "stop", message = list(content = message))),
    usage = list(prompt_tokens = 100L, completion_tokens = 20L)), auto_unbox = TRUE))
}
