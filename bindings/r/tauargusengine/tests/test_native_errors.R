# Invalid native input must raise an R error without terminating the process.
library(tauargusengine)
pkg <- getNamespaceName(environment(new_hitas))
lib <- dirname(find.package(pkg))
quote_r <- function(x) paste(capture.output(dput(unname(as.character(x)))), collapse = "")
for (case in c("missing-parameters", "missing-files", "unwritable-output",
               "wrong-pointer", "expired-pointer", "rounder-format", "rounder-dimension")) {
  child <- tempfile(fileext = ".R")
  output <- tempfile(fileext = ".log")
  writeLines(c(
    paste0("library(", quote_r(pkg), ", lib.loc=", quote_r(lib), ", character.only=TRUE)"),
    "work <- tempfile(); dir.create(work); setwd(work)",
    "writeLines(character(), 'parameters.dat')",
    paste0("writeLines(", quote_r("99"), ", 'bad.jj')"),
    paste0("pars <- ", if (case == "missing-parameters") "'absent.dat'" else "'parameters.dat'"),
    paste0("case <- ", quote_r(case)),
    "result <- tryCatch({",
    "if (case == 'wrong-pointer') tauargus_version(new_hitas())",
    "else if (case == 'expired-pointer') tauargus_version(unserialize(serialize(new_tauargus(), NULL)))",
    "else if (grepl('rounder', case)) { if (case == 'rounder-dimension') writeLines(c('0', '1'), 'bad.jj'); rounder_do_round(new_rounder(), 'SCIP', 'bad.jj', 5) }",
    "else hitas_a_hitas(new_hitas(), pars, 'missing-files.dat', tau_out_dir=if (case == 'unwritable-output') paste0(work, '/missing/') else paste0(work, '/'))",
    "}, error=identity)",
    "if (grepl('rounder', case)) stopifnot(is.numeric(result), result[[1]] != 0) else stopifnot(inherits(result, 'error'))",
    "stopifnot(nzchar(tauargus_version(new_tauargus())))",
    "cat('native error handled; R remains usable\n')"), child)
  status <- system2(file.path(R.home("bin"), "Rscript"), shQuote(child),
                    stdout = output, stderr = output, timeout = 30)
  if (status != 0L) stop(case, " terminated child R (status ", status,
                          "): ", paste(readLines(output), collapse = "\n"))
  unlink(c(child, output))
}
cat("Native error subprocess checks passed\n")
