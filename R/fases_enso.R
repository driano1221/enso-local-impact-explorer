# Retrospective descriptive groups; no uncertainty/significance claim.
episodios_enso <- function(d) {
  stopifnot(!anyDuplicated(d$data_central),all(is.finite(d$valor)))
  d <- d[order(as.Date(d$data_central)),]
  dates <- as.Date(d$data_central)
  month <- as.integer(format(dates,"%Y"))*12L+as.integer(format(dates,"%m"))
  stopifnot(all(diff(month)==1L))
  sign <- ifelse(d$valor>=.5,1L,ifelse(d$valor<=-.5,-1L,0L))
  runs <- rle(sign); run <- rep(seq_along(runs$lengths),runs$lengths)
  persistent <- runs$lengths[run]>=5 & sign!=0
  d$fase <- ifelse(persistent,ifelse(sign>0,"nino","nina"),"transicao")
  d$episodio <- ifelse(persistent,paste0(d$indice,"-",format(dates[match(run,run)],"%Y-%m")),NA_character_)
  d
}
grupos_enso <- function(a,indices) {
  stopifnot(!anyDuplicated(a[c("fonte","ano_sazonal")]))
  j <- match(paste(a$ano_sazonal,a$estacao),paste(indices$ano,indices$estacao))
  stopifnot(!anyNA(j))
  a$indice <- indices$indice[j];a$indice_valor <- indices$valor[j]
  a$fase <- indices$fase[j];a$episodio <- indices$episodio[j]
  a
}
resumo_fases_enso <- function(a) {
  dplyr::bind_rows(lapply(split(a,interaction(a$fonte,a$fase,drop=TRUE)),function(d) {
    data.frame(fonte=d$fonte[1],fase=d$fase[1],n=nrow(d),
      episodios=length(unique(stats::na.omit(d$episodio))),
      media=mean(d$diferenca),q1=unname(quantile(d$diferenca,.25,type=7)),
      q3=unname(quantile(d$diferenca,.75,type=7)),
      anos=paste(sort(d$ano_sazonal),collapse=", "))
  }))
}
