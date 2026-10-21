# Presentation-only successor to frozen EXP_015 facts; calculations stay in the original helper.
ia_fatos_publicos <- function(id, epoca, variavel, escala = "valor", raiz = ".") {
  f <- ia_fatos(id, epoca, variavel, raiz = raiz)
  f$query$display_scale <- if (identical(escala, "diferenca")) "difference_from_own_baseline" else "absolute_value"
  p <- read.csv(file.path(raiz, "dados/mundial/integracao/pontos.csv"), na.strings = "", stringsAsFactors = FALSE, fileEncoding = "UTF-8")
  p <- p[p$id == id, , drop = FALSE]
  nomes <- jsonlite::fromJSON(file.path(raiz, "prototipo_mundial/paises-pt.json"))
  nome <- nomes[[p$pais_iso2]]
  if (!is.null(nome)) f$evidence$pt$scope <- sub(paste0(" · ", p$pais, " · "), paste0(" · ", nome, " · "), f$evidence$pt$scope, fixed = TRUE)
  for (lang in c("pt", "en")) {
    f$evidence[[lang]]$values <- sub(if (lang == "pt") " São valores" else " These are", if (lang == "pt") ". São valores" else ". These are", f$evidence[[lang]]$values, fixed = TRUE)
    f$evidence[[lang]]$anomalies <- sub(if (lang == "pt") " Diferença =" else " Difference =", if (lang == "pt") ". Diferença =" else ". Difference =", f$evidence[[lang]]$anomalies, fixed = TRUE)
    f$evidence[[lang]]$integrity <- sub(if (lang == "pt") "Stellar Testnet r7" else "r7 Stellar Testnet", if (lang == "pt") "Stellar Testnet da versão publicada" else "published release's Stellar Testnet", f$evidence[[lang]]$integrity, fixed = TRUE)
  }
  f$evidence$pt$missing <- "Esse valor não está disponível no recorte enviado à IA. Ausência não é zero. Consulte o gráfico ou baixe a série completa para investigar outros anos ou recortes."
  f$evidence$en$missing <- "That value is unavailable in the query sent to AI. Missing is not zero. Check the chart or download the full series to investigate other years or selections."
  f
}
