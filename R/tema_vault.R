# Base de graficos do vault (R). Uso: source("C:/obsidian/Base_de_Conhecimento/15_Design_Graficos/codigo/tema_vault.R")
# Regras de onde vem cada valor: 15_Design_Graficos/regras-de-design-aprovadas.md.
# Exemplos aplicados (e o que foi rejeitado): 15_Design_Graficos/galeria-design.md.
# Origem: R/00_tema.R do post do oceano (C:\projetos\oceano-2026), generalizado.
# Ao mudar algo aqui que mude o visual, atualizar a regra e a galeria junto.
library(ggplot2)

# ---- Paletas aprovadas (secao "Qual Paleta Usar"). Uma por uso, nao misturar. ----
paleta_graficos <- c(destaque = "#C0392B", principal = "#2980B9", contexto = "#7F8C8D", estrutura = "#1A252F")
paleta_reveal <- c(fundo = "#0b0b0d", texto = "#f4efe6", destaque = "#E85D2A")      # deck HTML proprio, Playfair Display
# slides academicos: off-white + verde/teal/mostarda/coral, Trebuchet MS -> ver slides PASTIS (sem hex fechado ainda)

cor_destaque <- paleta_graficos[["destaque"]]    # o que o grafico quer mostrar (uma serie so)
cor_principal <- paleta_graficos[["principal"]]  # serie de referencia; lado "abaixo" da divergente
cor_secundaria <- paleta_graficos[["contexto"]]  # contexto
cor_estrutura <- paleta_graficos[["estrutura"]]  # texto, eixos
cor_terra <- "#C3C8CC"                           # terra/sem dado em mapa

fonte <- "Noto Sans"   # instalada no Windows; se faltar, systemfonts::system_fonts() para conferir

# ---- Tema ----
# titulo, subtitulo e caption; theme() simples para servir tambem no plot_annotation do patchwork
tema_titulos <- function(base_size = 13) {
  theme(
    text = element_text(family = fonte),
    plot.title = element_text(face = "bold", size = base_size * 1.45, color = cor_estrutura, hjust = 0,
                              margin = margin(b = 6), lineheight = 1.1),
    plot.subtitle = element_text(color = "gray35", size = base_size * 0.92, lineheight = 1.25, hjust = 0,
                                 margin = margin(b = 14)),
    plot.caption = element_text(color = "gray50", size = base_size * 0.68, hjust = 0,
                                margin = margin(t = 14), lineheight = 1.2),
    plot.title.position = "plot",
    plot.caption.position = "plot",
    plot.background = element_rect(fill = "white", color = NA),
    plot.margin = margin(28, 30, 20, 26)
  )
}

# grade so horizontal, sem titulo de eixo (a unidade vai no rotulo), sem legenda (anotacao direta)
tema_vault <- function(base_size = 13) {
  theme_minimal(base_size = base_size, base_family = fonte) +
    tema_titulos(base_size) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_blank(),
      panel.grid.major.y = element_line(color = "gray90", linewidth = 0.3),
      axis.text = element_text(color = "gray40"),
      axis.title = element_blank(),
      legend.position = "none"
    )
}

# divergente centrada numa referencia (anomalia, variacao): azul abaixo, branco na referencia, vermelho acima
escala_divergente <- function(limites, meio = 0, passo = NULL, aesthetics = "fill") {
  if (is.null(passo)) {
    scale_fill_gradient2(low = cor_principal, mid = "white", high = cor_destaque, midpoint = meio,
                         limits = limites, oob = scales::squish, guide = "none", aesthetics = aesthetics)
  } else {
    scale_fill_steps2(low = cor_principal, mid = "white", high = cor_destaque, midpoint = meio,
                      breaks = seq(limites[1], limites[2], by = passo), limits = limites,
                      oob = scales::squish, guide = "none", aesthetics = aesthetics)
  }
}

# ---- Saida ----
# post em rede 4:5: 7,2 x 9 pol a 300 dpi = 2160 x 2700 px
salvar_post <- function(p, arquivo, w = 7.2, h = 9) {
  dir.create(dirname(arquivo), showWarnings = FALSE, recursive = TRUE)
  ggsave(arquivo, p, width = w, height = h, dpi = 300, device = ragg::agg_png, bg = "white")
  invisible(arquivo)
}
# paisagem para blog/relatorio (11 x 6,9 pol = 3300 x 2070 px); titulo em uma linha
salvar_web <- function(p, arquivo, w = 11, h = 6.9) salvar_post(p, arquivo, w, h)

# ---- Texto: idioma e numeros ----
# IDIOMA=en|pt vem do ambiente; nunca depender do locale do R (gerou "17 junho" em grafico em ingles)
idioma <- Sys.getenv("IDIOMA", "pt")
tr <- function(en, pt) if (idioma == "pt") pt else en
sep_dec <- function() tr(".", ",")
num <- function(x, d = 2, sinal = FALSE) {
  formatC(x, format = "f", digits = d, decimal.mark = sep_dec(), big.mark = tr(",", "."),
          flag = if (sinal) "+" else "")
}
pct <- function(x, d = 0) paste0(num(100 * x, d), "%")
quebra_linha <- function(x) gsub("\n", " ", x)   # titulo de post (2 linhas) virando titulo web (1 linha)

meses_pt <- c("jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez")
meses_pt_longo <- c("janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto",
                    "setembro", "outubro", "novembro", "dezembro")
mes_abrev <- function(x) {
  m <- as.integer(format(as.Date(x), "%m"))
  if (idioma == "pt") meses_pt[m] else month.abb[m]
}
data_txt <- function(x) {
  x <- as.Date(x); d <- as.integer(format(x, "%d")); m <- as.integer(format(x, "%m"))
  tr(sprintf("%d %s", d, month.name[m]), sprintf("%s de %s", ifelse(d == 1, "1º", d), meses_pt_longo[m]))
}
# eixo de datas com meses no idioma certo: scale_x_date(labels = rotulo_mes)
rotulo_mes <- function(x) ifelse(is.na(x), NA, mes_abrev(x))

# ---- Mapa-mundi (Equal Earth) ----
# regra: publico geral = Greenwich (lon0 = 0); Pacifico (lon0 = -160) so para publico tecnico de ENSO
crs_equal_earth <- function(lon0 = 0) sprintf("+proj=eqearth +lon_0=%g +datum=WGS84", lon0)
# silhueta do globo projetado, para recortar raster (o inverso da Equal Earth devolve valor fora da Terra)
silhueta_globo <- function(lon0 = 0) {
  lat <- seq(-90, 90, by = 0.5)
  ajusta <- function(x) ((x + 180) %% 360) - 180
  anti <- ajusta(lon0 + 180)
  borda <- rbind(cbind(ajusta(anti - 1e-6), lat), cbind(ajusta(anti + 1e-6), rev(lat)))
  xy <- sf::sf_project("EPSG:4326", crs_equal_earth(lon0), borda)
  terra::vect(list(rbind(xy, xy[1, ])), type = "polygons", crs = crs_equal_earth(lon0))
}
