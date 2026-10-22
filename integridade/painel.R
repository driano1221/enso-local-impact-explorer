enso_integridade_ui <- function(lang) {
  en <- lang=="en"; t <- function(pt,en_text) if(en) en_text else pt
  shiny::tags$details(id="verificar-dados",class="enso-verificar",
    shiny::tags$summary(t("Verificar estes dados","Verify these data")),
    shiny::tags$div(class="proof-body",
      shiny::tags$p(t("Confira se o CSV baixado é igual à versão registrada na rede de testes. O arquivo fica no seu navegador.","Check whether your downloaded CSV matches the version recorded on the test network. The file stays in your browser.")),
      shiny::tags$div(class="proof-downloads",
        shiny::tags$button(type="button",`data-download`="serie_csv",t("Baixar CSV do gráfico","Download chart CSV")),
        shiny::tags$button(type="button",`data-download`="mensal_csv",t("Baixar CSV mensal","Download monthly CSV"))),
      shiny::tags$div(class="proof-controls",
        shiny::tags$div(shiny::tags$label(`for`="proof-kind",t("Tipo de CSV","CSV type")),shiny::tags$select(id="proof-kind",
          shiny::tags$option(value="serie",t("Dados do gráfico","Chart data")),shiny::tags$option(value="mensal",t("Registros mensais","Monthly records")))),
        # No id/name: Shiny's automatic file binding must not upload this local-only file.
        shiny::tags$div(shiny::tags$label(shiny::tags$span(t("Arquivo no seu computador","File on your computer")),shiny::tags$input(type="file",accept=".csv,text/csv",`data-local-csv`=""))),
        shiny::tags$button(type="button",`data-proof-check`="",t("Verificar arquivo","Verify file"))),
      shiny::tags$p(`data-proof-result`="",role="status",`aria-live`="polite",t("Selecione um CSV desta consulta.","Choose a CSV for this query.")),
      shiny::tags$details(shiny::tags$summary(t("Hashes e registro público","Hashes and public record")),
        shiny::tags$p(`data-network-status`="",t("A rede será consultada ao verificar.","The network is checked when you verify.")),
        shiny::tags$span(t("SHA-256 do manifesto","Manifest SHA-256")),shiny::tags$code(`data-manifest-sha`="","—"),
        shiny::tags$span(t("SHA-256 do arquivo escolhido","Chosen file SHA-256")),shiny::tags$code(`data-file-sha`="","—"),
        shiny::tags$span(t("SHA-256 esperado","Expected SHA-256")),shiny::tags$code(`data-expected-sha`="","—"),
        shiny::tags$a(`data-transaction`="",hidden=NA,target="_blank",rel="noopener",t("Ver transação na Stellar Testnet ↗","View Stellar Testnet transaction ↗"))),
      shiny::tags$small(t("A correspondência comprova a versão dos bytes registrada. Não comprova exatidão climática, causa ENSO ou previsão. A consulta confia na API pública Horizon por HTTPS. A Testnet pode reiniciar. Sem custo real.","A match establishes correspondence with the recorded bytes. It does not establish climate accuracy, ENSO causality or a forecast. Network confirmation trusts public Horizon over HTTPS. Testnet can reset. No real-money cost."))))
}
enso_integridade_inserir <- function(tag,lang) {
  if(inherits(tag,"shiny.tag")) {
    if(identical(tag$attribs$class,"evidencia")) tag$children <- c(tag$children,list(enso_integridade_ui(lang),enso_historico_ui(lang)))
    else tag$children <- lapply(tag$children,enso_integridade_inserir,lang=lang)
  } else if(is.list(tag)&&!inherits(tag,"html_dependency")) tag[] <- lapply(tag,enso_integridade_inserir,lang=lang)
  tag
}
enso_integridade_instalar <- function(input,session,lang) {
  shiny::observe({shiny::req(input$cidade,input$estacao,input$variavel)
    session$sendCustomMessage("enso-proof-query",list(lang=lang,id=input$cidade,season=input$estacao,variable=input$variavel))
  })
}
