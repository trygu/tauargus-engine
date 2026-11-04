# The installed native package must load without bundled engine DLLs.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 2L)
lib <- normalizePath(args[[1]], winslash = "/")
pkg <- args[[2]]
ns <- loadNamespace(pkg, lib.loc = lib)
libs <- list.files(file.path(lib, pkg, "libs"), recursive = TRUE,
                   pattern = "\\.(so|dll|dylib)$", full.names = TRUE)
if (length(libs) != 1L)
  stop("Expected one R DLL, found ", length(libs), ": ", paste(basename(libs), collapse = ", "))
engine <- get("new_tauargus", ns)()
stopifnot(nzchar(get("tauargus_version", ns)(engine)))
meta <- get("tauargus_engine_meta", ns)()
stopifnot(length(meta) > 0L)
cat("Installed package loads with one native DLL; version and metadata calls pass\n")
