# Build the native libraries bundled with the tauargusengine source package.
#
# Invoked by `configure` (Unix) and `configure.win` (Windows) during
# R CMD INSTALL, from the package root. It builds, from the package's own
# sources only (no external checkout):
#
#   1. HiGHS, static and minimal            -> src/.ta/highs
#   2. the five tauargus-engine libraries    -> src/.ta/engine
#
# The engine and solver are static archives linked into the R DLL. No
# engine shared libraries or build-machine runtime paths are installed.
# Requires CMake >= 3.16 and the C/C++ toolchain used by R.

local({
  stop_if <- function(cond, msg) if (cond) stop("\nconfigure: ", msg, call. = FALSE)

  # All paths absolute: configure runs from the package root, but the
  # generated Makevars is consumed by make from src/.
  pkg_root   <- normalizePath(".", winslash = "/")
  build      <- file.path(pkg_root, "src", ".ta")
  # The bundled sources live in top-level directories (not inst/): R only
  # installs the standard package directories, so they stay out of the
  # installed package without configure having to remove them. That keeps
  # configure read-only on the sources, which matters because R CMD build
  # runs configure (via its temporary install) on the tree it tars.
  highs_src  <- file.path(pkg_root, "tools", "highs")
  engine_src <- file.path(pkg_root, "tools", "engine")
  highs_bld  <- file.path(build, "highs-build")
  engine_bld <- file.path(build, "engine-build")
  highs_pre  <- file.path(build, "highs")
  engine_pre <- file.path(build, "engine")
  eng_lib    <- file.path(engine_pre, "lib")

  stop_if(!dir.exists(highs_src), "tools/highs/ (bundled HiGHS sources) is missing")
  stop_if(!dir.exists(engine_src), "tools/engine/ (bundled engine sources) is missing")
  if (!nzchar(Sys.which("cmake")))
    stop("cmake not found on PATH; install CMake >= 3.16 first")

  is_win <- .Platform$OS.type == "windows"
  is_mac <- identical(Sys.info()[["sysname"]], "Darwin")
  jobs   <- "2"

  # On Windows the CMake "MinGW Makefiles" generator requires the Rtools
  # g++ on PATH, and R CMD INSTALL does not always put the compiler
  # directory there for configure scripts. Add it explicitly.
  if (is_win && !nzchar(Sys.which("g++"))) {
    for (rt in c(Sys.getenv("RTOOLS44_HOME"), Sys.getenv("RTOOLS43_HOME"),
                 "C:/Rtools44", "C:/Rtools")) {
      bin <- file.path(rt, "mingw64", "bin")
      if (nzchar(rt) && dir.exists(bin)) {
        Sys.setenv(PATH = paste(bin, Sys.getenv("PATH"),
                                sep = .Platform$path.sep))
        break
      }
    }
    if (!nzchar(Sys.which("g++")))
      stop("g++ (Rtools MinGW toolchain) not found on PATH")
  }

  # Use R's compiler choices and flags, preserving explicit installer
  # environment settings. Do not discard hardening or user flags.
  r_config <- function(name) {
    value <- Sys.getenv(name)
    if (nzchar(value)) return(value)
    value <- system2(file.path(R.home("bin"), "R"),
                     c("CMD", "config", name), stdout = TRUE)
    stop_if(!is.null(attr(value, "status")), paste("R CMD config failed for", name))
    paste(value, collapse = " ")
  }
  cc <- r_config("CC")
  cxx <- r_config("CXX")
  Sys.setenv(CC = cc, CXX = cxx)
  cppflags <- r_config("CPPFLAGS")
  toolchain <- c(paste0("-DCMAKE_C_FLAGS=", r_config("CFLAGS"), " ", cppflags, " -fexceptions"),
                 paste0("-DCMAKE_CXX_FLAGS=", r_config("CXXFLAGS"), " ", cppflags),
                 paste0("-DCMAKE_EXE_LINKER_FLAGS=", r_config("LDFLAGS")),
                 paste0("-DCMAKE_SHARED_LINKER_FLAGS=", r_config("LDFLAGS")),
                 "-DCMAKE_POSITION_INDEPENDENT_CODE=ON",
                 "-DCMAKE_C_FLAGS_RELEASE=-DNDEBUG",
                 "-DCMAKE_CXX_FLAGS_RELEASE=-DNDEBUG")
  # Match an explicit standard selected by R instead of overriding it with
  # the standalone engine's C++11 default.
  if (grepl("-std=(gnu|c)\\+\\+[0-9]+", cxx)) {
    standard <- sub(".*-std=(gnu|c)\\+\\+([0-9]+).*", "\\2", cxx)
    toolchain <- c(toolchain, paste0("-DCMAKE_CXX_STANDARD=", standard))
  }

  # Forward slashes everywhere: they survive both the shell and GNU make.
  sl <- function(p) gsub("\\\\", "/", p, fixed = TRUE)
  sl_highs_src  <- sl(highs_src)
  sl_engine_src <- sl(engine_src)
  sl_highs_bld  <- sl(highs_bld)
  sl_engine_bld <- sl(engine_bld)
  sl_highs_pre  <- sl(highs_pre)
  sl_engine_pre <- sl(engine_pre)

  # R's system2 is unsafe for both platforms: on Unix it only shQuotes
  # the command and passes the args to the shell unquoted (a -D flag
  # containing $ORIGIN is expanded to an empty variable), and on Windows
  # it does not quote multi-word args at all ("-G MinGW Makefiles"
  # arrives as three arguments). Build the command line by hand with
  # explicit quoting; cmake output streams to the install log and the
  # exit status is returned.
  q_win <- function(a) {
    if (grepl("[ \\t\"']", a))
      paste0("\"", gsub("\"", "\\\"", a, fixed = TRUE), "\"")
    else a
  }
  q_posix <- function(a) paste0("'", gsub("'", "'\\''", a, fixed = TRUE), "'")
  run <- function(args) {
    cat(paste0("configure: cmake ", paste(args, collapse = " "), "\n"))
    if (is_win)
      line <- paste("cmake", paste(vapply(args, q_win, character(1)), collapse = " "))
    else
      line <- paste("cmake", paste(vapply(args, q_posix, character(1)), collapse = " "))
    ok <- system(line)
    stop_if(ok != 0, "cmake failed (see output above)")
  }

  gen <- if (is_win) list("-G", "MinGW Makefiles") else list()

  # Clean rebuild.
  unlink(build, recursive = TRUE)
  dir.create(build, recursive = TRUE, showWarnings = FALSE)

  # 1) HiGHS: static, no tests/examples/exe/extras/zlib.
  run(c("-S", sl_highs_src, "-B", sl_highs_bld, gen,
        "-DCMAKE_BUILD_TYPE=Release", toolchain,
        "-DBUILD_SHARED_LIBS=OFF",
        "-DFAST_BUILD=ON",
        "-DBUILD_TESTING=OFF",
        "-DBUILD_EXAMPLES=OFF",
        "-DBUILD_CXX_EXE=OFF",
        "-DCMAKE_INSTALL_DOCDIR=",
        "-DBUILD_SHARED_EXTRAS_LIB=OFF",
        "-DZLIB=OFF",
        paste0("-DCMAKE_INSTALL_PREFIX=", sl_highs_pre)))
  run(c("--build", sl_highs_bld, "--parallel", jobs))
  run(c("--install", sl_highs_bld))

  # 2) Engine superbuild, with static libraries for the R DLL.
  # HiGHS installs its CMake package at <prefix>/<LIBDIR>/cmake/highs,
  # and LIBDIR is lib or lib64 depending on the platform, so locate the
  # installed config instead of assuming the directory.
  cfg_hits <- list.files(highs_pre, pattern = "^highs-config\\.cmake$",
                         recursive = TRUE, full.names = TRUE)
  stop_if(length(cfg_hits) != 1L,
          paste("expected exactly one highs-config.cmake under",
                sl_highs_pre, "; found:", length(cfg_hits)))
  # The config sits at <prefix>/<LIBDIR>/cmake/highs; derive LIBDIR from it
  # (it is lib on most platforms, lib64 on some).
  highs_cmakedir <- dirname(cfg_hits[[1]])
  highs_libdir <- dirname(dirname(highs_cmakedir))
  e_args <- c("-S", sl_engine_src, "-B", sl_engine_bld, gen,
              "-DCMAKE_BUILD_TYPE=Release", toolchain,
              "-DBUILD_SHARED_LIBS=OFF",
              "-DTAUARGUS_MAX_THREADS=2",
              paste0("-DHighs_DIR=", sl(highs_cmakedir)),
              paste0("-DCMAKE_INSTALL_PREFIX=", sl_engine_pre))
  run(e_args)
  run(c("--build", sl_engine_bld, "--parallel", jobs))
  run(c("--install", sl_engine_bld))

  # 3) Link static archives in dependency order. Relative paths keep the
  # generated Makevars independent of the staging directory, including
  # when its name contains spaces.
  unlink(file.path(pkg_root, "inst", "libs"), recursive = TRUE)
  engine_libs <- c("tauargus_hitas", "tauargus_csp", "tauargus_rounder", "CRP", "tauargus_core")
  archives <- file.path(".ta", "engine", "lib", paste0("lib", engine_libs, ".a"))
  highs_archive <- file.path(".ta", "highs", basename(highs_libdir),
                             c("libhighs.a", "libhighs_extras.a"))
  stop_if(!all(file.exists(file.path(pkg_root, "src", c(archives, highs_archive)))),
          "expected static engine and HiGHS archives are missing")
  inc <- file.path("..", "tools", "engine", "native", c("core", "csp", "hitas", "rounder"), "src")
  inc <- c(inc, file.path(".ta", "highs", "include", "highs"))
  mv <- c("# Generated by configure (configure.R); do not edit.",
          paste0("PKG_CPPFLAGS = -DTAUARGUS_STATIC ", paste0("-I", inc, collapse = " ")),
          paste0("PKG_LIBS = ", paste(c(archives, highs_archive), collapse = " "),
                 if (is_win) "" else if (is_mac) " -pthread" else " -pthread -ldl"))
  writeLines(mv, file.path(pkg_root, "src", "Makevars"))
  # Echo the generated Makevars: it is the single source of the native
  # build flags, and install link/load failures without it are hard to
  # diagnose.
  writeLines(mv)

  cat("configure: bundled engine built; Makevars written.\n")
})
