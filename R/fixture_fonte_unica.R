# Test-only: retain the missing-source contract even when acquisition is complete.
fixture_fonte_unica <- function(indice, leitor, id = "GN-3040686") {
  force(leitor)
  force(id)
  stopifnot(sum(indice$id == id) == 1L)
  indice$fontes[indice$id == id] <- "POWER"
  indice$era5_disponivel[indice$id == id] <- FALSE
  indice$registros[indice$id == id] <- 540L
  ler <- function(ponto_id, ...) {
    x <- leitor(ponto_id, ...)
    if (identical(ponto_id, id)) {
      x$mensal <- x$mensal[x$mensal$fonte == "POWER", , drop = FALSE]
      x$fontes <- x$fontes[x$fontes$fonte == "POWER", , drop = FALSE]
      x$ponto$fontes <- "POWER"
      x$ponto$era5_disponivel <- FALSE
      x$ponto$registros <- 540L
      stopifnot(nrow(x$mensal) == 540L, nrow(x$fontes) == 1L)
    }
    x
  }
  list(indice = indice, leitor = ler)
}
