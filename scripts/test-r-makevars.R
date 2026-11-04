# Generated Makevars must stay portable even when configure runs on Windows.
args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args) == 1L, file.exists(args[[1L]]))
bytes <- readBin(args[[1L]], "raw", n=file.info(args[[1L]])$size)
stopifnot(length(bytes) > 0L, !any(bytes == as.raw(13L)),
          identical(tail(bytes, 1L), as.raw(10L)))
cat("Generated Makevars uses LF line endings\n")
