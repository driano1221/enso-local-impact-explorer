# Run from the repository root: Rscript deploy.R ACCOUNT APP_NAME
if (.Platform$OS.type=="windows") Sys.setlocale("LC_ALL","English_United States.utf8")
if(dir.exists(".r-library")) .libPaths(c(normalizePath(".r-library"),.libPaths()))
stopifnot(requireNamespace("rsconnect",quietly=TRUE))
args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args)==2L)
manifest <- jsonlite::fromJSON("manifest.json")
stopifnot(manifest$schema=="enso-public-bundle-v1")
files <- manifest$files$path
stopifnot(!anyDuplicated(files),!any(grepl("(^/|^[A-Za-z]:|\\\\|(^|/)\\.\\.(/|$))",files)))
for(i in seq_along(files)) stopifnot(file.info(files[[i]])$size==manifest$files$bytes[[i]],
    digest::digest(file=files[[i]],algo="sha256")==manifest$files$sha256[[i]])
# Posit generates its own manifest in the temporary bundle; never upload it as source.
stopifnot(!"manifest.json" %in% files)
rsconnect::deployApp(appDir=getwd(),appFiles=files,appPrimaryDoc="app.R",appName=args[[2]],
    appTitle="ENSO Local - historical climate explorer",appMode="shiny",account=args[[1]],server="shinyapps.io",
    recordDir=file.path(getwd(),"rsconnect"),launch.browser=FALSE,appVisibility="public",envManagementPy=FALSE)
