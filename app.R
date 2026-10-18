if (dir.exists(".r-library")) .libPaths(c(normalizePath(".r-library"), .libPaths()))
language <- Sys.getenv("ENSO_LANGUAGE", "en")
stopifnot(language %in% c("en", "pt"))
shiny::shinyAppDir(if(language=="en") "prototipo_mundial_en" else "prototipo_mundial")
