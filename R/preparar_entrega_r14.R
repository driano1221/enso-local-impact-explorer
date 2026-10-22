# Exact exported CSV hashes + descriptive ENSO groups. Run once from project root.
if(.Platform$OS.type=="windows") invisible(Sys.setlocale("LC_ALL","English_United States.utf8"))
root <- normalizePath(".",winslash="/")
if(dir.exists(".r-library")) .libPaths(c(normalizePath(".r-library"),.libPaths()))
source(if(file.exists("publicacao/app.R"))"publicacao/app.R"else"app.R",encoding="UTF-8")
envs <- lapply(apps_enso,function(app) environment(app$server))
original_series <- lapply(envs,function(e)e$series_mundiais)
prepare <- envs$pt$preparar_sazonal
for(e in envs) {
  # Cache only inside this offline exporter, never inside the public application.
  e$series_mundiais <- function(x,epoca,v) serie_entrega
  environment(e$series_mundiais) <- e
  e$preparar_sazonal <- function(d) preparado_entrega
  environment(e$preparar_sazonal) <- e
}
source("R/fases_enso.R",encoding="UTF-8")
dest <- "dados/mundial/enso_descritivo_v1";proof <- "integridade/www/csv-r14"
stopifnot(!file.exists(file.path(proof,"csv-index.json")))
dir.create(dest,recursive=TRUE,showWarnings=FALSE);dir.create(proof,recursive=TRUE,showWarnings=FALSE)
indices <- read.csv("dados/enso.csv",stringsAsFactors=FALSE)
classified <- dplyr::bind_rows(lapply(split(indices,indices$indice),episodios_enso))
readr::write_csv(classified,file.path(dest,"fases.csv"))
entries <- list();groups <- list();summaries <- list();temp <- tempfile(fileext=".csv")
ids <- envs$pt$indice$id
stopifnot(length(ids)==684L,!anyDuplicated(ids))
for(i in seq_along(ids)) {
  started <- proc.time()[3]
  id <- ids[i];x <- envs$pt$ler_ponto_mundial(id,root)
  prepared <- prepare(x$mensal)
  for(e in envs) e$preparado_entrega <- prepared
  for(index in c("RONI","ONI")) {
    j <- match(as.character(x$mensal$data),classified$data_central[classified$indice==index])
    stopifnot(!anyNA(j),all(abs(x$mensal[[index]]-classified$valor[classified$indice==index][j])<1e-12))
  }
  for(lang in c("pt","en")) {
    e <- envs[[lang]]
    e$escrever_csv_publico(e$exportar_mensal_publico(x,lang),temp)
    entries[[paste(lang,id,"mensal",sep="|")]] <- digest::digest(file=temp,algo="sha256")
  }
  for(season in c("DJF","MAM","JJA","SON")) for(variable in c("temperatura_c","precipitacao_mm_mes")) {
    base <- original_series$pt(x,season,variable)
    for(e in envs) e$serie_entrega <- base
    if(i==1L) stopifnot(identical(base,original_series$en(x,season,variable)))
    for(lang in c("pt","en")) {
      e <- envs[[lang]];a <- e$exportar_mundial(x,season,variable)
      stopifnot(nrow(a)==if(season=="DJF") 88 else 90,all(is.finite(a$valor)))
      e$escrever_csv_publico(a,temp)
      entries[[paste(lang,id,season,variable,"serie",sep="|")]] <- digest::digest(file=temp,algo="sha256")
    }
    a <- a[c("id","estacao","variavel","fonte","ano_sazonal","valor","referencia","diferenca")]
    for(index in c("RONI","ONI")) {
      g <- grupos_enso(a,classified[classified$indice==index,])
      s <- resumo_fases_enso(g);stopifnot(sum(s$n)==nrow(a))
      s$id <- id;s$estacao <- season;s$variavel <- variable;s$indice <- index
      groups[[length(groups)+1L]] <- g;summaries[[length(summaries)+1L]] <- s
    }
  }
  if(i==1 || i%%20==0 || i==length(ids)) {cat(i,"/",length(ids),"verified locations; last point",round(proc.time()[3]-started,2),"seconds\n");flush.console()}
}
unlink(temp)
readr::write_csv(dplyr::bind_rows(groups),file.path(dest,"anos.csv"))
readr::write_csv(dplyr::bind_rows(summaries),file.path(dest,"resumos.csv"))
stopifnot(length(entries)==length(ids)*18L)
jsonlite::write_json(list(schema="enso-csv-index-v1",locations=length(ids),precision_decimals=6L,
  interpretation="Exact bytes of generated chart/monthly CSVs. Not climate accuracy or causality.",
  entries=entries),file.path(proof,"csv-index.json"),auto_unbox=TRUE,digits=NA)
index <- file.path(proof,"csv-index.json")
jsonlite::write_json(list(schema="enso-public-bundle-v1",scope="CSV hash index, not the full software release",
  files=list(list(path="csv-index.json",bytes=unname(file.info(index)$size),sha256=digest::digest(file=index,algo="sha256")))),
  file.path(proof,"manifest.json"),auto_unbox=TRUE,pretty=TRUE)
jsonlite::write_json(list(scope="Retrospective descriptive phase groups; no confidence intervals or p-values",
  protocol="competicao/experimentos/EXP_017_fases_e_integridade_20261022.md",locations=length(ids),
  enso_input_sha256=digest::digest(file="dados/enso.csv",algo="sha256"),
  point_index_sha256=digest::digest(file="dados/mundial/integracao/pontos.csv",algo="sha256"),
  hashes=lapply(setNames(c("fases.csv","anos.csv","resumos.csv"),c("fases","anos","resumos")),function(n) digest::digest(file=file.path(dest,n),algo="sha256"))),
  file.path(dest,"manifesto.json"),auto_unbox=TRUE,pretty=TRUE)
cat("PASS: descriptive groups and12312 exact CSV export hashes; no inferential models fitted.\n")
