# Native console output must be visible to R sinks.
library(tauargusengine)
work <- tempfile(); dir.create(work)
in_file <- file.path(work, "bad.jj")
writeLines("99", in_file)
text <- capture.output(result <- rounder_do_round(new_rounder(), "SCIP", in_file, 5))
stopifnot(result[[1]] != 0, any(grepl("Controlled Rounding Solver", text, fixed=TRUE)))
unlink(work, recursive=TRUE)
cat("Native output is captured by R\n")
