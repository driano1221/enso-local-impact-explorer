if (.Platform$OS.type == "windows") Sys.setlocale("LC_ALL", "English_United States.utf8")
# Contratos/falhas locais com transporte simulado; não mede qualidade do modelo real.
source("ia/fatos.R", encoding = "UTF-8")
source("ia/deepseek.R", encoding = "UTF-8")
checks <- 0L
check <- function(x) { stopifnot(isTRUE(x)); checks <<- checks + 1L }
perto <- function(a, b) abs(a - b) < 1e-9
f <- ia_fatos("WUP-7802")
linha <- function(f, origem) f$numbers[f$numbers$fonte == origem, ]
check(perto(linha(f, "POWER")$valor, 22.28))
check(perto(linha(f, "POWER")$referencia, 21.36388888888889))
check(perto(linha(f, "ERA5")$valor, 21.207347670250893))
check(perto(linha(f, "ERA5")$diferenca, -.08150537634409005))
chuva <- ia_fatos("WUP-7802", variavel = "precipitacao_mm_mes")
check(perto(linha(chuva, "POWER")$valor, 118.32))
check(perto(linha(chuva, "ERA5")$valor, 165.20000135153532))
check(grepl("mm/quarter", chuva$evidence$en$values, fixed = TRUE))
check(grepl("0,38", f$evidence$pt$comparison, fixed = TRUE))
djf <- ia_fatos("WUP-7802", "DJF")
check(grepl("1982", djf$evidence$pt$scope, fixed = TRUE))
for (id in c("GN-3445133", "WUP-987", "WUP-2965")) {
  exemplo <- ia_fatos(id)
  check(nrow(exemplo$numbers) == 2L && all(is.finite(exemplo$numbers$valor)))
  check(grepl("Relevo", exemplo$evidence$pt$source_info, fixed = TRUE))
}
for (expr in list(quote(ia_fatos("../nao_aprovado")), quote(ia_fatos("WUP-7802", "DJF", ano = 1981)),
                  quote(ia_fatos("WUP-7802", ano = 2026)), quote(ia_fatos("WUP-7802", variavel = "temperatura_diaria"))))
  check(inherits(try(eval(expr), silent = TRUE), "try-error"))

fake <- function(intent = "value", lang = "pt") list(model = "mock-not-a-real-model-test",
  choices = list(list(finish_reason = "stop", message = list(content = as.character(jsonlite::toJSON(
    list(language = lang, intent = intent, evidence_ids = list(unname(ia_intencoes[[intent]]))), auto_unbox = TRUE))))),
  usage = list(prompt_tokens = 1000L, completion_tokens = 50L))
casos <- jsonlite::read_json("ia/casos.json")
check(length(casos) == 30L && sum(vapply(casos, function(c) c$split == "dev", logical(1))) == 12L)
for (c in casos) {
  p <- if (c$metric == "temperatura_c") f else chuva
  r <- ia_responder(c$question, p, c$language, transporte = function(payload) {
    check(identical(payload$model, "deepseek-flash"))
    check(identical(payload$thinking$type, "disabled"))
    check(identical(payload$response_format$type, "json_object"))
    check(is.null(payload$tools) && payload$max_tokens == 400L)
    fake(c$expected, c$language)
  })
  check(r$ok && identical(r$intent, c$expected))
  check(grepl(p$evidence[[c$language]][[ia_intencoes[[c$expected]]]], r$text, fixed = TRUE))
  check(grepl(p$evidence[[c$language]]$limits, r$text, fixed = TRUE))
}

invalidos <- list(nao_json = "not json", vazio = "", idioma = '{"language":"en","intent":"value","evidence_ids":["values"]}',
  inventado = '{"language":"pt","intent":"value","evidence_ids":["invented"]}',
  campo_extra = '{"language":"pt","intent":"value","evidence_ids":["values"],"text":"9999 graus"}',
  objeto = '{"language":"pt","intent":"value","evidence_ids":{"x":"values"}}',
  tipo = '{"language":"pt","intent":22,"evidence_ids":["values"]}')
for (x in invalidos) {
  resp <- fake(); resp$choices[[1]]$message$content <- x
  r <- ia_responder("Explique", f, transporte = function(payload) resp)
  check(!r$ok && identical(r$error, "invalid_output") && !grepl("9999", r$text))
}
resp <- fake(); resp$choices[[1]]$finish_reason <- "length"
check(!ia_responder("Explique", f, transporte = function(payload) resp)$ok)
resp <- fake(); resp$choices[[1]]$message$tool_calls <- list(list(name = "execute_code"))
check(!ia_responder("Explique", f, transporte = function(payload) resp)$ok)
for (x in list(NULL, 23L, list(usage = "bad"), list(error = "Authorization Bearer SENTINEL"))) {
  r <- ia_responder("Explique", f, transporte = function(payload) x)
  check(!r$ok && !grepl("SENTINEL", jsonlite::toJSON(r, auto_unbox = TRUE)))
}
chamadas <- 0L
erro <- function(payload) { chamadas <<- chamadas + 1L; list(error = "http_429") }
r <- ia_responder("Explique", f, transporte = erro)
check(chamadas == 1L && identical(r$error, "http_429"))
r <- ia_responder("Explique", f, transporte = function(payload) stop("SENTINEL bearer secret"))
check(identical(r$error, "transport_error") && !grepl("SENTINEL", jsonlite::toJSON(r, auto_unbox = TRUE)))
b <- ia_orcamento(.00001, 2L)
r <- ia_responder("Explique", f, orcamento = b, transporte = erro)
check(r$error == "budget_exhausted" && b$chamadas == 0L && chamadas == 1L)
b <- ia_orcamento(.10, 2L)
for (i in 1:3) r <- ia_responder("Explique", f, orcamento = b, transporte = function(payload) fake())
check(b$chamadas == 2L && r$error == "budget_exhausted")
anterior <- Sys.getenv("DEEPSEEK_API_KEY", unset = NA_character_)
tryCatch({
  Sys.unsetenv("DEEPSEEK_API_KEY")
  b <- ia_orcamento()
  check(identical(ia_responder("Explique", f, orcamento = b)$error, "key_missing") && b$chamadas == 0L)
  Sys.setenv(DEEPSEEK_API_KEY = "DUMMY_SENTINEL_NOT_A_KEY")
  payload <- ia_payload("Explique", f, "pt")
  check(!grepl("DUMMY_SENTINEL", jsonlite::toJSON(payload, auto_unbox = TRUE)))
}, finally = if (is.na(anterior)) Sys.unsetenv("DEEPSEEK_API_KEY") else Sys.setenv(DEEPSEEK_API_KEY = anterior))
for (q in c("", paste(rep("x", 2001), collapse = "")))
  check(inherits(try(ia_payload(q, f, "pt"), silent = TRUE), "try-error"))

baseline <- "competicao/evidencias/enquadramento_textos_20261019/preservacao_antes.json"
# The integration intentionally changes the bilingual entry; research evidence is not shipped.
protegidos <- if (file.exists(baseline)) jsonlite::read_json(baseline, simplifyVector = TRUE) else character()
protegidos <- protegidos[names(protegidos) != "R/app_bilingue.R"]
check(all(vapply(names(protegidos), function(p) identical(digest::digest(file = p, algo = "sha256"), unname(protegidos[[p]])), logical(1))))
saida <- if (dir.exists("competicao")) "competicao/evidencias/deepseek_preparacao_20261020" else file.path(tempdir(), "enso-ai-local-check")
dir.create(saida, recursive = TRUE, showWarnings = FALSE)
jsonlite::write_json(list(status = "PASS", checks = checks, simulated_fixture_cases = length(casos),
  real_api_calls = 0L, protected_files_unchanged = length(protegidos),
  example_BH_SON_2025 = list(temperature = f$numbers, rainfall = chuva$numbers),
  warning = "Mocks check contracts and controlled rendering, not model classification quality."),
  file.path(saida, "testes_locais.json"), pretty = TRUE, auto_unbox = TRUE)
cat(sprintf("PASS %s checks, %s casos PT/EN simulados, %s hashes preservados. Zero chamadas reais.\n", checks, length(casos), length(protegidos)))
