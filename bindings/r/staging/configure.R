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

  # Forward slashes everywhere: they survive both the shell and GNU make.
  sl <- function(p) gsub("\\\\", "/", p, fixed = TRUE)

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

  # On Windows, hand CMake the exact compiler and make program that R
  # will use, instead of relying on CMake's own PATH discovery. CMake's
  # "MinGW Makefiles" generator looks for an unqualified "g++" and for
  # "mingw32-make" only. The Rtools45 toolchain that R 4.5+ and the
  # CRAN pretest machines use provides neither on PATH: its compilers
  # carry the x86_64-w64-mingw32 prefix and it ships no mingw32-make
  # at all. Older Rtools (44 and earlier) do put an unqualified g++
  # and a mingw32-make on PATH; resolving the toolchain explicitly
  # works for both layouts.
  win_toolchain_args <- character(0)
  if (is_win) {
    # CC and CXX from R's config may carry flags; the tool name is the
    # first token.
    cc_name  <- basename(sub(" .*", "", cc))
    cxx_name <- basename(sub(" .*", "", cxx))
    if (grepl("[/\\\\]", cc)) {
      # CC was set to a full path (explicit installer environment).
      cc_path <- sl(cc)
      if (!grepl("\\.exe$", cc_path, ignore.case = TRUE))
        cc_path <- paste0(cc_path, ".exe")
      if (!file.exists(cc_path)) cc_path <- ""
    } else {
      cc_path <- Sys.which(cc)
    }
    cc_path <- sl(cc_path)
    rtools_root <- ""
    if (!nzchar(cc_path)) {
      # The compiler is not on PATH: locate it in a Rtools
      # installation. R 4.5+ honours RTOOLS45_HOME (default
      # c:/rtools45); earlier R honours RTOOLS43/44_HOME or c:/Rtools.
      roots <- c(Sys.getenv("RTOOLS45_HOME"), Sys.getenv("RTOOLS44_HOME"),
                 Sys.getenv("RTOOLS43_HOME"), Sys.getenv("RTOOLS40_HOME"),
                 "C:/rtools45", "C:/rtools44", "C:/rtools43", "C:/Rtools")
      roots <- unique(roots[nzchar(roots)])
      # Compiler bin layout per Rtools generation:
      #   Rtools45:        x86_64-w64-mingw32.static.posix/bin (MXE)
      #   Rtools43/44:     mingw-<version>-x86_64/bin (MSYS2)
      #   Rtools40 and
      #   earlier:         mingw_64/bin, mingw64/bin
      for (root in roots) {
        if (!dir.exists(root)) next
        cands <- c(file.path(root, "x86_64-w64-mingw32.static.posix", "bin"),
                   file.path(root, "aarch64-w64-mingw32.static.posix", "bin"),
                   file.path(root, "mingw_64", "bin"),
                   file.path(root, "mingw64", "bin"),
                   file.path(root,
                             list.files(root,
                                        pattern = "^mingw-[0-9][0-9.]*-(x86_64|aarch64)$"),
                             "bin"))
        for (d in cands) {
          if (dir.exists(d) && file.exists(file.path(d, paste0(cc_name, ".exe")))) {
            cc_path <- sl(file.path(d, paste0(cc_name, ".exe")))
            rtools_root <- root
            break
          }
        }
        if (nzchar(rtools_root)) break
      }
      stop_if(!nzchar(cc_path),
              paste("could not locate the MinGW compiler R will use (", cc,
                    "); install Rtools or set RTOOLS45_HOME so that",
                    cc_name, ".exe is findable"))
    }
    cc_bin <- dirname(cc_path)
    # Derive the Rtools root when the compiler sits in a Rtools45
    # (MXE) toolchain directory, so its MSYS2 make is findable even
    # when the Rtools PATH is not set up.
    if (rtools_root == "" &&
        basename(dirname(cc_bin)) %in%
          c("x86_64-w64-mingw32.static.posix", "aarch64-w64-mingw32.static.posix"))
      rtools_root <- dirname(dirname(cc_bin))
    # Prepend the compiler directory so CMake and the generated
    # makefiles find the compiler and its binutils.
    Sys.setenv(PATH = paste(cc_bin, Sys.getenv("PATH"),
                            sep = .Platform$path.sep))
    # The matching C++ compiler sits next to the C compiler.
    cxx_path <- file.path(cc_bin, paste0(cxx_name, ".exe"))
    stop_if(!file.exists(cxx_path),
            paste("expected the C++ compiler (", cxx,
                  ") next to the C compiler in ", cc_bin, "; found none"))
    # CMake's MinGW Makefiles generator searches for "mingw32-make"
    # only. Find a make it can drive: the toolchain bin (Rtools44 and
    # earlier ship mingw32-make there), the Rtools MSYS2 directory
    # (usr/bin), then the PATH.
    make_cands <- c(file.path(cc_bin, "mingw32-make.exe"),
                    file.path(cc_bin, "make.exe"),
                    if (nzchar(rtools_root))
                      file.path(rtools_root, "usr", "bin",
                                c("mingw32-make.exe", "make.exe"))
                    else character(0),
                    Sys.which("mingw32-make"), Sys.which("make"))
    make_path <- ""
    for (p in make_cands)
      if (nzchar(p) && file.exists(p)) { make_path <- sl(p); break }
    stop_if(!nzchar(make_path),
            paste("could not locate a make program for CMake's MinGW",
                  "Makefiles generator; looked in ", cc_bin,
                  if (nzchar(rtools_root))
                    paste(" and", file.path(rtools_root, "usr", "bin")) else "",
                  " and the PATH"))
    win_toolchain_args <- c(paste0("-DCMAKE_C_COMPILER=", cc_path),
                            paste0("-DCMAKE_CXX_COMPILER=", cxx_path),
                            paste0("-DCMAKE_MAKE_PROGRAM=", make_path))
  }

  toolchain <- c(paste0("-DCMAKE_C_FLAGS=", r_config("CFLAGS"), " ", cppflags, " -fexceptions"),
                 paste0("-DCMAKE_CXX_FLAGS=", r_config("CXXFLAGS"), " ", cppflags),
                 paste0("-DCMAKE_EXE_LINKER_FLAGS=", r_config("LDFLAGS")),
                 paste0("-DCMAKE_SHARED_LINKER_FLAGS=", r_config("LDFLAGS")),
                 "-DCMAKE_POSITION_INDEPENDENT_CODE=ON",
                 "-DCMAKE_C_FLAGS_RELEASE=-DNDEBUG",
                 "-DCMAKE_CXX_FLAGS_RELEASE=-DNDEBUG",
                 win_toolchain_args)
  # Match an explicit standard selected by R instead of overriding it with
  # the standalone engine's C++11 default.
  if (grepl("-std=(gnu|c)\\+\\+[0-9]+", cxx)) {
    standard <- sub(".*-std=(gnu|c)\\+\\+([0-9]+).*", "\\2", cxx)
    toolchain <- c(toolchain, paste0("-DCMAKE_CXX_STANDARD=", standard))
  }

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
  # A binary write keeps LF endings on Windows as required by R CMD check.
  writeBin(charToRaw(paste0(paste(mv, collapse = "\n"), "\n")),
           file.path(pkg_root, "src", "Makevars"))
  # Echo the generated Makevars: it is the single source of the native
  # build flags, and install link/load failures without it are hard to
  # diagnose.
  writeLines(mv)

  cat("configure: bundled engine built; Makevars written.\n")
})
