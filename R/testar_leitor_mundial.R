if (.Platform$OS.type == "windows") Sys.setlocale("LC_ALL", "English_United States.utf8")
source("R/ler_mundial.R", encoding="UTF-8")
source("R/validar_piloto.R", encoding="UTF-8")
indice <- read.csv("dados/mundial/integracao/pontos.csv", na.strings="", stringsAsFactors=FALSE)
indice$era5_disponivel <- tolower(indice$era5_disponivel) == "true"
ids <- unique(na.omit(c(indice$id[indice$era5_disponivel][1], indice$id[!indice$era5_disponivel][1],
                indice$id[indice$pais_iso2=="NA"][1], "GN-3445133")))
for (id in ids) {
  x <- ler_ponto_mundial(id)
  d <- preparar_sazonal(x$mensal)
  stopifnot(nrow(d)==537L*nrow(x$fontes), all(d$ano_sazonal>=1981), all(d$ano_sazonal<=2025),
            !any(d$estacao=="DJF" & d$ano_sazonal==1981))
  cat(id, nrow(x$mensal), nrow(d), paste(x$fontes$fonte,collapse="/"), "\n")
}
stopifnot(inherits(try(ler_ponto_mundial("../nao_aprovado"),silent=TRUE),"try-error"))
cat("PASS leitor R, identidade, cobertura e DJF continuo.\n")
