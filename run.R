if (dir.exists(".r-library")) .libPaths(c(normalizePath(".r-library"), .libPaths()))
args <- commandArgs(trailingOnly=TRUE)
language <- if (length(args)>=1) args[[1]] else "en"
stopifnot(language %in% c("en", "pt"))
port <- if (length(args)>=2) suppressWarnings(as.integer(args[[2]])) else 8080L
stopifnot(length(port)==1L, !is.na(port), port>=1024L, port<=65535L)
folder <- if(language=="en") "prototipo_mundial_en" else "prototipo_mundial"
stopifnot(file.exists(file.path(folder,"app.R")))
shiny::runApp(folder, port=port, host=Sys.getenv("HOST","127.0.0.1"), launch.browser=FALSE)
