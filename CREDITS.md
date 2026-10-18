# Sources and third-party notices

Checked during preparation on 17 October 2026. The project's MIT licence applies to original code only. It does not relicense datasets, fonts, textures or third-party libraries. Exact retrieval times and source hashes are in `proveniencia_publica.json` and `dados/mundial/integracao/fontes.csv`.

## Climate and catalogue data

- **NASA POWER / MERRA-2:** data obtained from the NASA Langley Research Center POWER Project, funded through the NASA Earth Science Division. This package uses the Monthly and Annual API; versions and retrieval dates are recorded per response in the public provenance file, rather than copying an hourly-version citation. Monthly T2M is retained in °C; PRECTOTCORR in mm/day is multiplied by calendar days to obtain monthly rainfall. [POWER referencing guide](https://power.larc.nasa.gov/docs/referencing/), [meteorology methodology](https://power.larc.nasa.gov/docs/methodology/meteorology/).
- **ERA5 / Copernicus Climate Change Service / ECMWF, via Open-Meteo:** [Weather data by Open-Meteo.com](https://open-meteo.com/), [API data licence](https://open-meteo.com/en/licence), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Daily air temperature is averaged by month; daily rainfall is summed; baselines, differences and seasonal summaries are derived by this project. No original Open-Meteo server software is distributed here. These are derived reanalysis estimates, not observations of the full municipality. The public deployment should retain clear Open-Meteo attribution beside its data/source presentation.
- **NOAA CPC:** ONI/RONI ERSSTv6 historical index snapshot acquired on 4 October 2026. [ONI](https://www.cpc.ncep.noaa.gov/products/analysis_monitoring/enso/oni/v6/), [RONI](https://www.cpc.ncep.noaa.gov/products/analysis_monitoring/enso/roni/). Centred indices are retrospective. Their inclusion does not authorize claims of operational forecasting.
- **UN DESA World Urbanization Prospects 2025:** population/reference-city selection, supplemented by national official sources. [WUP downloads](https://population.un.org/wup/downloads), [methodological context](https://population.un.org/wup/faqs). The package distributes the derived catalogue, not the original UN workbooks. Source-specific URLs and geographic unit decisions remain in the catalogue. Do not present urban agglomeration and municipal definitions as interchangeable.
- **GeoNames:** coordinates and reference-point identifiers where used, [CC BY 4.0](https://www.geonames.org/about.html). Original identifiers and source URLs are preserved. National catalogue supplements retain their own source attribution; availability of a table is not a claim that every ranking is homologated.

## Maps, graphics and interface assets

- **Natural Earth:** public-domain cartography, [terms](https://www.naturalearthdata.com/about/terms-of-use/). Land polygons were simplified/combined for the illustrative globe. Borders are context, not climate observations or a statement on sovereignty.
- **IBGE:** simplified public cartographic meshes used in the shared regional locator; geometries projected and reduced for display. Original endpoint URLs and hashes are in `dados/cartografia/fontes.json`. They are visual context and do not define the support of a climate grid cell.
- **Three.js r180:** MIT; licence and provenance under `prototipo_revisado/www/vendor/three/` and the corresponding English asset folder.
- **Anatomy:** Ryan / wheresryan22, MIT, commit e6600ffc4e8e6620eeb45bf49bcdbd5e4b84163f. The preserved `iso-kit.js` generates the original educational ocean section; it does not simulate ENSO physics. Licence under `vendor/anatomy/` in the shared assets.
- **Plotly.js basic 2.11.1:** MIT, original licence under each app's `www/vendor/plotly/`.
- **Source Sans 3:** Adobe, SIL OFL 1.1; original OFL under `www/vendor/source-sans/`.
- **Instrument Serif:** Instrument / Google Fonts, SIL OFL 1.1; original OFL retained in `www/vendor/instrument-serif/` for the bundled font files.
- **flag-icons v7.3.2:** Panayiotis Lipiridis and contributors, MIT; original licence under `www/vendor/flags/`.
- **Earth day texture:** Solar System Scope, [CC BY 4.0](https://www.solarsystemscope.com/textures/), obtained as the 4096px example texture from Three.js r180. Used as an illustrative globe surface; not current satellite weather. Exact URL/hash in each app's `www/vendor/assets-manifest.json`.
- R packages and the optional Python Stellar SDK are installed dependencies, not vendored packages. Their own licences apply. Versions are recorded in the respective lockfiles.

Design galleries and the Huashu, Figures4papers and Diagram Design repositories were consulted as references. Their screenshots, figures, documents and repositories are **not** included. In particular, the Figures4papers noncommercial assets have not been copied into this package.
