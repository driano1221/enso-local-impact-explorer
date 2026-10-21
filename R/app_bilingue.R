# One Shiny endpoint; each session keeps its own existing PT or EN UI/server.
root_enso <- normalizePath(".",winslash="/")
idioma_enso <- function(query,default=Sys.getenv("ENSO_LANGUAGE","en")) {
  q <- shiny::parseQueryString(if(is.null(query)) "" else query)
  lang <- if(length(q$lang)==1L) tolower(q$lang) else default
  if(lang %in% c("pt","pt-br")) "pt" else "en"
}
prefixar_recursos <- function(tag,prefix) {
  if(inherits(tag,"shiny.tag")) {
    for(a in intersect(names(tag$attribs),c("href","src","data-src"))) {
      value <- tag$attribs[[a]]
      if(is.character(value) && length(value)==1L && nzchar(value) && !grepl("^(#|/|[a-zA-Z]+:)",value))
        tag$attribs[[a]] <- paste0(prefix,"/",value)
    }
    tag$children <- lapply(tag$children,prefixar_recursos,prefix=prefix)
  } else if(is.list(tag) && !inherits(tag,"html_dependency")) tag[] <- lapply(tag,prefixar_recursos,prefix=prefix)
  tag
}
apps_enso <- lapply(c(pt="prototipo_mundial",en="prototipo_mundial_en"),function(folder) {
  path <- file.path(root_enso,folder)
  env <- new.env(parent=globalenv())
  old <- setwd(path); on.exit(setwd(old))
  source("app.R",local=env,encoding="UTF-8")
  list(ui=env$ui,server=env$server,path=path)
})
for(lang in names(apps_enso)) {
  prefix <- paste0("ui-",lang)
  shiny::addResourcePath(prefix,file.path(apps_enso[[lang]]$path,"www"))
  approved <- if(lang=="pt") file.path(root_enso,"prototipo_revisado/www") else file.path(apps_enso[[lang]]$path,"www/aprovado-en")
  shiny::addResourcePath(paste0(prefix,"/aprovado"),approved)
  apps_enso[[lang]]$ui <- prefixar_recursos(apps_enso[[lang]]$ui,prefix)
}
source(file.path(root_enso,"ia/servidor.R"),local=TRUE,encoding="UTF-8")
enso_ai_state <- enso_ai_runtime(root_enso)
shiny::addResourcePath("enso-ai",file.path(root_enso,"ia/www"))
# Reactive country flags use the shared vendor URL rather than a UI prefix.
shiny::addResourcePath("vendor",file.path(apps_enso$pt$path,"www/vendor"))
escala_inicial_ui <- function(tag,value) {
  if(inherits(tag,"shiny.tag")) {
    if(tag$name=="input" && identical(tag$attribs$name,"escala"))
      tag$attribs$checked <- if(identical(tag$attribs$value,value)) "checked" else NULL
    tag$children <- lapply(tag$children,escala_inicial_ui,value=value)
  } else if(is.list(tag) && !inherits(tag,"html_dependency")) tag[] <- lapply(tag,escala_inicial_ui,value=value)
  tag
}
shiny::shinyApp(ui=function(request) {
  lang <- idioma_enso(request$QUERY_STRING)
  ui <- apps_enso[[lang]]$ui
  ui <- enso_ai_inserir(ui,lang)
  ui[[length(ui)+1L]] <- shiny::tags$head(shiny::tags$link(rel="stylesheet",href="enso-ai/assistente.css?v=altas1"),shiny::tags$script(src="enso-ai/assistente.js?v=ia1"))
  q <- shiny::parseQueryString(if(is.null(request$QUERY_STRING)) "" else request$QUERY_STRING)
  if(length(q$escala)==1L && q$escala %in% c("valor","diferenca")) ui <- escala_inicial_ui(ui,q$escala)
  ui[[length(ui)+1L]] <- shiny::tags$div(style="display:none",`aria-hidden`="true",shiny::textInput("ui_language",NULL,value=lang))
  ui
},server=function(input,output,session) {
  lang <- shiny::isolate(input$ui_language)
  if(is.null(lang) || !lang %in% names(apps_enso)) lang <- idioma_enso(shiny::isolate(session$clientData$url_search))
  apps_enso[[lang]]$server(input,output,session)
  enso_ai_instalar(input,output,session,lang,enso_ai_state)
})
