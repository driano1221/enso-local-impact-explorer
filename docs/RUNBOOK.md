# ENSO Local Impact Explorer

Historical climate evidence for local questions. Select a place, season and measure; compare NASA POWER and ERA5 when available; download chart data, monthly records and a factsheet. This package contains both the Portuguese dashboard and its English version, using the same calculations.

**[Live dashboard — English](https://kl5ug0-adriano-pires.shinyapps.io/enso-local-preview/?lang=en)** · **[Português (Brasil)](https://kl5ug0-adriano-pires.shinyapps.io/enso-local-preview/?lang=pt)** · **[Source code](https://github.com/driano1221/enso-local-impact-explorer)**

The header switches between English and Brazilian Portuguese while retaining the query. The moon/sun button switches light/dark appearance; the preference is stored locally in the browser. Information buttons explain POWER, ERA5 and the four three-month periods, and work with pointer, touch or keyboard (Esc closes). The opening explains the dashboard and introduces El Niño and La Niña as phases of ENSO. Language and appearance do not change climate calculations or source coverage.

This package contains a versioned preview, including the data it uses. Read `SNAPSHOT.json` for this package's exact frozen POWER/ERA5 coverage, record counts and unresolved catalogue cases. A live preview or a newer local dataset may have a different snapshot. Later acquisitions do not change this package automatically. A published preview is not a final competition submission.

The refined interface separates the inspected historical year from the full-history source comparison. The latter labels its actual year range and number of paired seasons; reference values and the annual distribution remain available. On phones, the selected city and climate result appear before an expandable location view, which loads the globe when opened. Larger explanatory text and separate ENSO control/cross-section rows improve reading without changing the data or scientific calculations.

## AI evidence interpreter

“Ask about these data” opens a small, optional interpreter below the local summary. DeepSeek classifies a question; R displays reviewed explanations with the selected real data and source links. It does not produce forecasts or infer an El Niño cause. Requests require explicit submission; the credential stays on the server. The public package runs without a key. See [AI operation, privacy and configuration](../ia/README.md). “Understand the phenomenon” now opens the ENSO tab and briefly highlights/focuses its phase controls, including on mobile and with reduced motion.

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

### Historical ENSO groups

The summary under the local record groups seasons using the frozen NOAA RONI ERSSTv6 snapshot: at least five consecutive overlapping three-month periods at or beyond +0.5 / −0.5. It uses the central month of each displayed quarter and shows ONI as a sensitivity view. Neutral/transition includes fluctuations outside persistent episodes. DJF starts in 1982; the other quarters start in 1981.

The table gives the mean anomaly from each source’s own 1991–2020 baseline, the middle 50% of seasons, and counts of seasons and episodes. These are descriptive statistics, **not confidence intervals**. No significance, causal effect or forecast is claimed. Long-term trends and other factors can confound the comparison; years within one episode and the two source products are not independent replications. The earlier global inferential procedure was not released after synthetic calibration failed the specified coverage checks.

`dados/mundial/enso_descritivo_v1/manifesto.json` records the descriptive cache hashes and inputs. The app reads `fases.csv` and `resumos.csv`; the larger per-year intermediate can be regenerated and is deliberately not shipped. R tests check counts for every location, phase episodes and Trujillo’s raw rainfall totals. Trujillo was selected after inspecting its disagreement and is an illustrative retrospective example, not an independent validation set.

### Terrain and local representativeness

The terrain and elevation represented by a grid can differ from the city or station. In a documented 2019–2021 comparison, selected ERA5 cells in Bishkek and Almaty averaged 6.61 °C and 5.53 °C below station observations across the same 35 complete months in each city. A fixed 3×3 neighbourhood showed smaller differences in lower-elevation cells directly to the north, but those cells are different locations about 20–30 km from the stations. This is evidence of spatial sensitivity, not proof that elevation explains the entire difference or a reason to replace the selected cell with the best-matching neighbour.

The original source values and cell selections are retained. Station relocation/instrument histories remain incomplete; recent rainfall lacked complete primary-station months under the study's coverage rule. A temperature check does not validate rainfall or all locations worldwide. Source agreement, successful cache checks and reproducible aggregation do not by themselves establish local accuracy. The station investigation is documented research; these notes do not imply a new automatic warning or correction in the dashboard.

## Reproduce and verify

Every included file is listed with size and SHA-256 in `manifest.json`. Verify the entire extracted package using Python's standard library:

```text
python verificar_pacote.py
```

That verifies bytes, not scientific truth or the authenticity of a replaceable local manifest. Preserve the ZIP checksum through a separate trusted channel. The full software release uses its separate matching receipt distributed with the release. Inside **Verify these data**, a second manifest covers the hash index for all 12,312 chart/monthly CSV exports in PT/EN. The browser hashes the chosen file locally, verifies the index digest and checks the manifest memo through the public Horizon HTTPS endpoint. Files are not uploaded. A byte change, another selected query, a different language or a CSV re-saved by an editor can fail the check. This does not prove climate accuracy, authorship or the integrity of future AI replies. Testnet can reset. CSV numerical presentation is rounded to six decimal places; internal climate calculations are unchanged.

To rebuild integrated files offline and run the included checks:

```text
python -m pip install -r requirements-data.txt
python R/integrar_mundial.py
python R/testar_integracao_mundial.py
Rscript R/testar_leitor_mundial.R
Rscript R/testar_interface_mundial.R
Rscript R/testar_ingles.R
Rscript R/testar_bilingue.R
```

Rebuilding changes the package manifest's recorded bytes if any output differs. Work on a copy when experimenting. The monthly inputs, integration source, catalogue and source hashes are included; raw HTTP responses, station investigations, heavy synthetic experiments and private project correspondence are excluded. `proveniencia_publica.json` retains source URLs, retrieval times, requested coordinates, calendars, original response hashes and POWER API versions. Re-downloading a live source can yield a revised response; it cannot be assumed to recreate an earlier raw snapshot.

The shared `R/validar_piloto.R` is sourced for seasonal utilities. Do not execute its pilot analysis entry point inside this descriptive package: the separate pilot inputs are deliberately not included.

Optional future data acquisition uses `R/adquirir_mundial.py` and `requirements-acquisition.txt`. It is not needed to view or reproduce this bundled snapshot. Respect provider quotas, sequential ERA5 requests and the cooldown recorded after HTTP 429; do not run acquisition during a provider pause. Raw downloads are written under `dados/originais/` and excluded from Git. Re-downloading can return revised data and is not proof of the original bytes. No acquisition is triggered by dashboard use.

## Sources, licences and attribution

Original project code: Adriano Pires Cunha, MIT, see `LICENSE`. Data, fonts, flags, textures and bundled libraries retain their own licences and attribution. See [CREDITS.md](../CREDITS.md). No endorsement by NASA, Copernicus/ECMWF, Open-Meteo, NOAA, UN, GeoNames or the competition organizers is implied.

## Português

Esta prévia reúne o painel mundial e a versão inglesa. A cobertura exata pertence a `SNAPSHOT.json`; novas aquisições não alteram silenciosamente o pacote. Execute `Rscript run.R pt 8081` na raiz, com as dependências instaladas. O histórico e os grupos ENSO são descritivos, com lacunas explícitas e sem previsão ou causalidade. A altitude e o terreno da grade podem diferir dos da cidade ou estação; a investigação de Bishkek/Almaty mostrou sensibilidade espacial, sem correção dos valores ou troca das células. A comparação de temperatura não valida chuva. `python verificar_pacote.py` confere o pacote. Em **Verificar estes dados**, o navegador confere o CSV do gráfico ou mensal com o índice ancorado na Stellar Testnet. A prova integral da release é separada e precisa corresponder à versão entregue. Não há custo real nem envio do arquivo escolhido. Vídeo e submissão final ainda pertencem às etapas de entrega.
