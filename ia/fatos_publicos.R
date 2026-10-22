# Presentation-only successor to frozen EXP_015 facts; calculations stay in the original helper.
ia_fatos_publicos <- function(id, epoca, variavel, escala = "valor", raiz = ".", ano = 2025L) {
  f <- ia_fatos(id, epoca, variavel, ano = as.integer(ano), raiz = raiz)
  e <- new.env(parent = globalenv())
  for (file in c("R/ler_mundial.R", "R/validar_piloto.R", "prototipo_revisado/explorador.R")) sys.source(file.path(raiz, file), envir=e)
  x <- e$ler_ponto_mundial(id, raiz)
  d <- e$preparar_sazonal(x$mensal)
  a <- dplyr::bind_rows(lapply(unique(d$fonte), function(source)
    dplyr::mutate(e$serie_temporadas(d[d$fonte==source & d$estacao==epoca,],variavel),fonte=source)))
  pairs <- merge(a[a$fonte=="POWER",c("ano_sazonal","valor")],a[a$fonte=="ERA5",c("ano_sazonal","valor")],by="ano_sazonal")
  pairs$gap <- abs(pairs$valor.x-pairs$valor.y)
  pairs <- pairs[order(-pairs$gap,pairs$ano_sazonal),]
  f$query$display_scale <- if (identical(escala, "diferenca")) "difference_from_own_baseline" else "absolute_value"
  p <- read.csv(file.path(raiz, "dados/mundial/integracao/pontos.csv"), na.strings = "", stringsAsFactors = FALSE, fileEncoding = "UTF-8")
  p <- p[p$id == id, , drop = FALSE]
  nomes <- jsonlite::fromJSON(file.path(raiz, "prototipo_mundial/paises-pt.json"))
  nome <- nomes[[p$pais_iso2]]
  if (!is.null(nome)) f$evidence$pt$scope <- sub(paste0(" · ", p$pais, " · "), paste0(" · ", nome, " · "), f$evidence$pt$scope, fixed = TRUE)
  for (lang in c("pt", "en")) {
    n <- function(v) formatC(v,digits=2,format="f",decimal.mark=if(lang=="pt") "," else ".")
    unit <- if(variavel=="temperatura_c") "°C" else "mm"
    f$evidence[[lang]]$year_extremes <- paste(vapply(c("POWER","ERA5"),function(source) {
      h <- a[a$fonte==source,]; if(!nrow(h)) return("")
      paste0(source,": ",if(lang=="pt") "máximo " else "maximum ",n(max(h$valor))," ",unit," (",paste(h$ano_sazonal[h$valor==max(h$valor)],collapse=", "),"); ",
        if(lang=="pt") "mínimo " else "minimum ",n(min(h$valor))," ",unit," (",paste(h$ano_sazonal[h$valor==min(h$valor)],collapse=", "),").")
    },""),collapse=" ")
    top <- head(pairs,3)
    f$evidence[[lang]]$year_disagreement <- if(nrow(top)) paste(
      if(lang=="pt") "Anos com maior distância absoluta entre as fontes:" else "Years with the largest absolute source difference:",
      paste(paste0(top$ano_sazonal,": ",n(top$gap)," ",unit," (POWER ",n(top$valor.x),"; ERA5 ",n(top$valor.y),")"),collapse=". "),
      if(lang=="pt") "Isso não identifica qual fonte é correta." else "This does not identify the correct source.") else
      if(lang=="pt") "A comparação exige as duas fontes nos mesmos anos." else "This comparison requires both sources for the same years."
    f$evidence[[lang]]$values <- sub(if (lang == "pt") " São valores" else " These are", if (lang == "pt") ". São valores" else ". These are", f$evidence[[lang]]$values, fixed = TRUE)
    f$evidence[[lang]]$anomalies <- sub(if (lang == "pt") " Diferença =" else " Difference =", if (lang == "pt") ". Diferença =" else ". Difference =", f$evidence[[lang]]$anomalies, fixed = TRUE)
    f$evidence[[lang]]$integrity <- if(lang=="pt") "Em Verificar estes dados, escolha o CSV baixado. O navegador calcula seu SHA-256, confere o índice e o manifesto e consulta o registro na Stellar Testnet. O arquivo fica no navegador. A correspondência verifica a versão dos bytes, não exatidão climática, causa ENSO, autoria ou esta resposta da IA. A consulta confia no Horizon por HTTPS, e a Testnet pode reiniciar." else "In Verify these data, choose your downloaded CSV. The browser calculates its SHA-256, checks the index and manifest and queries the Stellar Testnet record. Your file stays in the browser. A match verifies the recorded bytes, not climate accuracy, ENSO causality, authorship or this AI reply. Confirmation trusts Horizon over HTTPS, and Testnet can reset."
  }
  f$evidence$pt$missing <- "Esse valor não está disponível no recorte enviado à IA. Ausência não é zero. Consulte o gráfico ou baixe a série completa para investigar outros anos ou recortes."
  f$evidence$en$missing <- "That value is unavailable in the query sent to AI. Missing is not zero. Check the chart or download the full series to investigate other years or selections."
  f$evidence$pt$unclear <- "Não reconheci uma pergunta que eu consiga responder com segurança. Posso explicar valores e diferenças da média, listar anos com valores extremos ou maior divergência, e esclarecer fontes e ENSO. Escolha uma dessas perguntas ou ajuste o recorte."
  f$evidence$en$unclear <- "I could not identify a question I can answer safely. I can explain values and baseline differences, list years with extreme values or the largest source disagreement, and explain sources and ENSO. Choose one of these questions or adjust the selection."
  if(exists("enso_recorte",mode="function")) {
    groups <- tryCatch(enso_recorte(raiz,id,epoca,variavel),error=function(e)NULL)
    if(!is.null(groups)&&nrow(groups)) for(lang in c("pt","en"))
      f$evidence[[lang]]$enso <- paste(if(lang=="pt") "Não é possível atribuir a causa de um ano ao El Niño com esta comparação. Podemos examinar os grupos históricos classificados por RONI." else
        "This comparison cannot attribute a year's cause to El Niño. We can examine historical groups classified using RONI.",enso_texto(groups,lang,variavel))
  }
  f
}
