source("R/fases_enso.R",encoding="UTF-8")
mk <- function(v) data.frame(data_central=seq(as.Date("2000-01-01"),by="month",length.out=length(v)),valor=v,indice="RONI")
stopifnot(all(episodios_enso(mk(c(0,rep(.5,4),0)))$fase=="transicao"))
x <- episodios_enso(mk(c(0,rep(.5,5),0,rep(-.5,6),0)))
stopifnot(identical(x$fase,c("transicao",rep("nino",5),"transicao",rep("nina",6),"transicao")),
  length(unique(na.omit(x$episodio)))==2,all(is.na(x$episodio[x$fase=="transicao"])))
print("PASS: persistence, thresholds, episode identity and transitions.")
