# Only export representation changes; cached data and statistical calculations stay intact.
escrever_csv_publico <- function(d, file) {
  for (name in names(d)) if (is.double(d[[name]])) d[[name]] <- round(d[[name]], 6)
  # Resolve the existing language-specific writer in the application environment.
  write_excel_csv2(d, file, num_threads=1)
}
exportar_mensal_publico <- function(x, lang) {
  dplyr::left_join(x$mensal,x$fontes,by=c("id","fonte")) |>
    dplyr::mutate(unidade_temperatura="°C",unidade_chuva=if(lang=="pt") "mm/mês" else "mm/month",
      referencia_periodo="1991-2020",interpretacao=if(lang=="pt")
        "Historico descritivo; indices centrados retrospectivos; nao previsao" else
        "Descriptive historical records; retrospective centred indices; not a forecast")
}
