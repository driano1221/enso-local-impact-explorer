# Leitura sob demanda para Shiny/exportacao. Nao modifica o painel piloto.
ler_ponto_mundial <- function(id, raiz = ".") {
  pasta <- file.path(raiz, "dados/mundial/integracao")
  indice <- read.csv(file.path(pasta, "pontos.csv"), na.strings = "", stringsAsFactors = FALSE, fileEncoding = "UTF-8")
  ponto <- indice[indice$id == id, , drop = FALSE]
  stopifnot(length(id) == 1L, nrow(ponto) == 1L)
  ponto$era5_disponivel <- tolower(ponto$era5_disponivel) == "true"
  ponto$inferencia_disponivel <- tolower(ponto$inferencia_disponivel) == "true"
  caminho <- file.path(pasta, "pontos", paste0(ponto$id, ".csv"))
  stopifnot(identical(digest::digest(file = caminho, algo = "sha256"), ponto$sha256))
  d <- read.csv(caminho, na.strings = "", stringsAsFactors = FALSE)
  d$data <- as.Date(d$data)
  fontes <- read.csv(file.path(pasta, "fontes.csv"), na.strings = "", stringsAsFactors = FALSE, fileEncoding = "UTF-8")
  fontes <- fontes[fontes$id == id, , drop = FALSE]
  stopifnot(nrow(d) == ponto$registros, !anyDuplicated(d[c("id", "fonte", "data")]),
            all(table(d$fonte) == 540L), setequal(unique(d$fonte), fontes$fonte))
  # Campos esperados pelas funcoes existentes; ID textual evita colisao WUP/GeoNames.
  d$cidade_id <- d$id
  d$cidade <- ponto$cidade
  list(ponto = ponto, mensal = d, fontes = fontes,
       aviso = "Exploratório; modelos mundiais ainda não calculados. POWER LST e ERA5 UTC.")
}
