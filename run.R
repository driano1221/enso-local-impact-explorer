if (dir.exists(".r-library")) .libPaths(c(normalizePath(".r-library"), .libPaths()))
args <- commandArgs(trailingOnly=TRUE)
language <- if (length(args)>=1) args[[1]] else "en"
stopifnot(language %in% c("en", "pt"))
port <- if (length(args)>=2) suppressWarnings(as.integer(args[[2]])) else 8080L
stopifnot(length(port)==1L, !is.na(port), port>=1024L, port<=65535L)
Sys.setenv(ENSO_LANGUAGE=language)
shiny::runApp(source("app.R",encoding="UTF-8")$value, port=port, host=Sys.getenv("HOST","127.0.0.1"), launch.browser=FALSE)
