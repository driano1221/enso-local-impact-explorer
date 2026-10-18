# ENSO Local Impact Explorer

Historical climate evidence for local questions. Select a place, season and measure; compare NASA POWER and ERA5 when available; download chart data, monthly records and a factsheet. This package contains both the approved Portuguese dashboard and its English version, using the same calculations.

**[Live English preview](https://kl5ug0-adriano-pires.shinyapps.io/enso-local-preview/)** · **[Source code](https://github.com/driano1221/enso-local-impact-explorer)**

This repository contains a versioned public preview, including the data it uses. The current snapshot has **684 reference points with POWER and 126 with ERA5**, covering 1981–2025. Read `SNAPSHOT.json` for the exact frozen coverage and its 39 unresolved catalogue cases. Later acquisitions do not change this snapshot automatically. This is not the final competition submission.

## Start the dashboard

Install R 4.3 or newer. From the extracted package root, open R and restore the recorded dependencies into a project library:

```r
install.packages("renv", repos="https://cloud.r-project.org")
dir.create(".r-library", showWarnings=FALSE)
renv::restore(project=getwd(), library=file.path(getwd(),".r-library"), prompt=FALSE)
.libPaths(c(file.path(getwd(),".r-library"), .libPaths()))
source("run.R")
```

That opens the English version at `http://127.0.0.1:8080`. Installation needs internet; the dashboard reads the bundled climate files and visual resources locally. Links to original sources open external websites when requested. Browsers must support JavaScript; the 3D view has a fallback when WebGL is unavailable.

With dependencies already on R's library path, use:

```text
Rscript run.R en 8080
Rscript run.R pt 8081
```

Run one command per terminal, always from the package root. For hosting, `app.R` selects English by default, or Portuguese when `ENSO_LANGUAGE=pt`. Keep the **whole package** together; app subfolders depend on shared code and data outside them. A host must support R/Shiny and its persistent communication transports. This shinyapps.io preview uses HTTPS SockJS/XHR; native WebSocket is disabled by that host. `HOST=0.0.0.0` is available for a configured server; the local default is loopback only.

The runtime includes the previously tested provider attribution and lazy JSON/srcdoc loading for the approved ENSO illustration. This avoids the hosting platform injecting duplicate scripts and conflicting asset bases into the illustration. The local interface and hosted interface use the same source files.

To deploy to your own configured shinyapps.io account, install `rsconnect` as an optional deployment tool and run `Rscript deploy.R ACCOUNT APP_NAME`. The script verifies the listed file hashes and uploads only those files. `manifest.json` is our SHA-256 integrity record; Posit generates a separate dependency manifest in its temporary bundle. Do not overwrite or include the root integrity manifest as a source file in a platform dependency manifest. Credentials and deployment records are excluded from version control; never put tokens in code.

`renv.lock` records the R versions used in preparation. On 18 October, the r2 candidate was tested after restoring all 81 locked R packages into an initially empty library, with installed-package cache reuse disabled and no runtime access to the global user library. Python data checks used a fresh venv. Both languages passed reader/interface/export and browser checks at desktop and 320px, including real CSV downloads and the ENSO globe. The same Windows OS and R 4.3.1 executable were used; this does not establish compatibility with another OS or a public host. Some packages were compiled from source using RBuildTools 4.3; an appropriate build toolchain may be needed if compatible binaries are unavailable. Optional Python data checks use `requirements-data.txt`; the blockchain verifier has separate requirements under `integridade/`.

## What the numbers mean

- Climate history is 1981–2025, not today's weather or a forecast. The catalogue uses approved reference points; grid cells are not measurements of every neighbourhood or the municipal territory.
- Temperature is the equally weighted mean of three monthly means, in °C. Rainfall is the sum of three monthly totals, in mm/season; 1 mm is 1 litre/m².
- The difference from average uses each source's own 1991–2020 baseline. It is not an effect attributed to El Niño.
- DJF assigns December to the following year: 44 complete seasons, 1982–2025. The other displayed seasons have 45 years.
- POWER uses local solar time; ERA5 uses UTC. Product and grid differences can affect comparisons. Agreement between sources is not independent validation, and disagreement alone does not identify the correct source.
- Global ENSO inference has not been released. This package contains the descriptive world dashboard; it does not offer the separate pilot's exploratory regressions as global conclusions. ONI/RONI are centred historical indices and include future information relative to the central month.
- The goal remains all capitals and the three most populous cities per country, plus Viçosa, Ouro Preto and Belo Horizonte. Unresolved catalogue ranking/boundary cases are counted in `SNAPSHOT.json` and listed in `dados/mundial/pendencias_catalogo_20261016.csv`. Missing ERA5 means not yet acquired, never zero rainfall or no uncertainty.

## Reproduce and verify

Every included file is listed with size and SHA-256 in `manifest.json`. Verify the entire extracted package using Python's standard library:

```text
python verificar_pacote.py
```

That verifies bytes, not scientific truth or the authenticity of a replaceable local manifest. Preserve the ZIP checksum through a separate trusted channel. This full candidate manifest has **not** been anchored on blockchain. The separate, real two-export Stellar Testnet demonstration is documented in `integridade/README.md` and can be checked using its fixed original transaction ID.

To rebuild integrated files offline and run the included checks:

```text
python -m pip install -r requirements-data.txt
python R/integrar_mundial.py
python R/testar_integracao_mundial.py
Rscript R/testar_leitor_mundial.R
Rscript R/testar_interface_mundial.R
Rscript R/testar_ingles.R
```

Rebuilding changes the package manifest's recorded bytes if any output differs. Work on a copy when experimenting. The monthly inputs, integration source, catalogue and source hashes are included; raw HTTP responses, station investigations, heavy synthetic experiments and private project correspondence are excluded. `proveniencia_publica.json` retains source URLs, retrieval times, requested coordinates, calendars, original response hashes and POWER API versions. Re-downloading a live source can yield a revised response; it cannot be assumed to recreate an earlier raw snapshot.

The shared `R/validar_piloto.R` is sourced for seasonal utilities. Do not execute its pilot analysis entry point inside this descriptive package: the separate pilot inputs are deliberately not included.

Optional future data acquisition uses `R/adquirir_mundial.py` and `requirements-acquisition.txt`. It is not needed to view or reproduce this bundled snapshot. Respect provider quotas, sequential ERA5 requests and the cooldown recorded after HTTP 429; do not run acquisition during a provider pause. Raw downloads are written under `dados/originais/` and excluded from Git. Re-downloading can return revised data and is not proof of the original bytes. No acquisition is triggered by dashboard use.

## Sources, licences and attribution

Original project code: Adriano Pires Cunha, MIT, see `LICENSE`. Data, fonts, flags, textures and bundled libraries retain their own licences and attribution. See [CREDITS.md](CREDITS.md). No endorsement by NASA, Copernicus/ECMWF, Open-Meteo, NOAA, UN, GeoNames or the competition organizers is implied.

## Português

Esta prévia reúne o painel mundial aprovado e a versão inglesa: POWER em 684 pontos e ERA5 em 126. A cobertura exata está em `SNAPSHOT.json`; novas aquisições não alteram silenciosamente o pacote. Execute `Rscript run.R pt 8081` na raiz, com as dependências instaladas. O histórico é descritivo, tem lacunas explícitas e não prevê impactos locais. `python verificar_pacote.py` confere os arquivos; a demonstração blockchain protege apenas os dois exports indicados em `integridade/README.md`. Vídeo e submissão final ainda pertencem às etapas de entrega.
