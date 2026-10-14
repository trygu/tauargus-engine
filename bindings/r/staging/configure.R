# Build the native libraries bundled with the tauargusengine source package.
#
# Invoked by `configure` (Unix) and `configure.win` (Windows) during
# R CMD INSTALL, from the package root. It builds, from the package's own
# sources only (no external checkout):
#
#   1. HiGHS, static and minimal            -> src/.ta/highs
#   2. the five tauargus-engine libraries    -> src/.ta/engine
#
# with install rpaths relative to the package (@loader_path / $ORIGIN), so
# nothing in the installed package points at the build machine. The engine
# shared libraries are staged into inst/libs (installed as the package
# `libs/` directory, next to the compiled R DLL), and src/Makevars is
# generated with the platform compile/link flags.
#
# Requires: cmake >= 3.16 and a C++11 compiler on PATH. On Windows the
# Rtools toolchain that R itself uses (R CMD INSTALL sets up the PATH).

local({
  stop_if <- function(cond, msg) if (cond) stop("\nconfigure: ", msg, call. = FALSE)

  # All paths absolute: configure runs from the package root, but the
  # generated Makevars is consumed by make from src/.
  pkg_root   <- normalizePath(".", winslash = "/")
  build      <- file.path(pkg_root, "src", ".ta")
  highs_src  <- file.path(pkg_root, "inst", "highs")
  engine_src <- file.path(pkg_root, "inst", "engine")
  highs_bld  <- file.path(build, "highs-build")
  engine_bld <- file.path(build, "engine-build")
  highs_pre  <- file.path(build, "highs")
  engine_pre <- file.path(build, "engine")
  eng_lib    <- file.path(engine_pre, "lib")
  eng_bin    <- file.path(engine_pre, "bin")

  stop_if(!dir.exists(highs_src), "inst/highs (bundled HiGHS sources) is missing")
  stop_if(!dir.exists(engine_src), "inst/engine (bundled engine sources) is missing")
  if (is.null(Sys.which("cmake")))
    stop("cmake not found on PATH; install CMake >= 3.16 first")

  is_win <- .Platform$OS.type == "windows"
  is_mac <- identical(Sys.info()[["sysname"]], "Darwin")
  jobs   <- as.character(max(2L, parallel::detectCores()))

  # On Windows the CMake "MinGW Makefiles" generator requires the Rtools
  # g++ on PATH, and R CMD INSTALL does not always put the compiler
  # directory there for configure scripts. Add it explicitly.
  if (is_win && is.null(Sys.which("g++"))) {
    for (rt in c(Sys.getenv("RTOOLS44_HOME"), Sys.getenv("RTOOLS43_HOME"),
                 "C:/Rtools44", "C:/Rtools")) {
      bin <- file.path(rt, "mingw64", "bin")
      if (nzchar(rt) && dir.exists(bin)) {
        Sys.setenv(PATH = paste(bin, Sys.getenv("PATH"),
                                sep = .Platform$path.sep))
        break
      }
    }
    if (is.null(Sys.which("g++")))
      stop("g++ (Rtools MinGW toolchain) not found on PATH")
  }

  # R CMD INSTALL exports CC/CFLAGS/CXX/CXXFLAGS/... from its own build for
  # the configure script. The nested CMake builds must not inherit the flag
  # variables: a distro-built R bakes in flags such as
  # -Werror=format-security and -D_FORTIFY_SOURCE=3, which break the legacy
  # engine sources. The compiler choices (CC/CXX) are kept.
  for (v in c("CFLAGS", "CXXFLAGS", "FFLAGS", "FLIBS", "LDFLAGS", "CPPFLAGS"))
    Sys.unsetenv(v)

  # Forward slashes everywhere: they survive both the shell and GNU make.
  sl <- function(p) gsub("\\\\", "/", p, fixed = TRUE)
  sl_highs_src  <- sl(highs_src)
  sl_engine_src <- sl(engine_src)
  sl_highs_bld  <- sl(highs_bld)
  sl_engine_bld <- sl(engine_bld)
  sl_highs_pre  <- sl(highs_pre)
  sl_engine_pre <- sl(engine_pre)
  sl_eng_lib    <- sl(eng_lib)
  sl_eng_bin    <- sl(eng_bin)

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

  # 1) HiGHS: static, no tests/examples/exe/extras/zlib. (HiGHS >= 1.15
  # defaults to a shared library on Unix; force static so the package
  # runtime libs are exactly the four engine libraries.)
  run(c("-S", sl_highs_src, "-B", sl_highs_bld, gen,
        "-DCMAKE_BUILD_TYPE=Release",
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

  # 2) Engine superbuild, installed with a package-relative rpath.
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
  engine_rpath <- if (is_mac) "@loader_path" else if (is_win) NULL else "$ORIGIN"
  e_args <- c("-S", sl_engine_src, "-B", sl_engine_bld, gen,
              "-DCMAKE_BUILD_TYPE=Release",
              paste0("-DHighs_DIR=", sl(highs_cmakedir)),
              paste0("-DCMAKE_INSTALL_PREFIX=", sl_engine_pre))
  if (!is.null(engine_rpath))
    e_args <- c(e_args, paste0("-DCMAKE_INSTALL_RPATH=", engine_rpath))
  run(e_args)
  run(c("--build", sl_engine_bld, "--parallel", jobs))
  run(c("--install", sl_engine_bld))

  # 2b) Relocate the engine sources into the build tree. The Makevars
  # include paths must point at the build tree, because the bundled
  # sources are dropped from the package before R compiles src/ (inst/
  # would otherwise be installed as package data).
  engine_in_tree <- file.path(build, "engine-src")
  stop_if(!file.rename(file.path(pkg_root, "inst", "engine"), engine_in_tree),
          "could not move inst/engine into the build tree")
  sl_engine_in_tree <- sl(engine_in_tree)

  # 3) Stage the engine runtime libs into inst/libs -> installed <pkg>/libs.
  libs_dir <- file.path(pkg_root, "inst", "libs")
  unlink(libs_dir, recursive = TRUE)
  dir.create(libs_dir, recursive = TRUE, showWarnings = FALSE)

  engine_libs <- c("tauargus_csp", "tauargus_hitas", "tauargus_rounder", "CRP")
  if (is_win) {
    # CMake names MinGW DLLs with the lib prefix (libCRP.dll, ...).
    dlls <- list.files(eng_bin, pattern = paste0("^lib(?:",
        paste(engine_libs, collapse = "|"), ")\\.dll$"))
    stop_if(length(dlls) != length(engine_libs),
            paste("expected the four engine DLLs in", eng_bin, "; found:", dlls))
    file.copy(file.path(eng_bin, dlls), libs_dir, overwrite = TRUE)
  } else {
    ext <- if (is_mac) "\\.dylib$" else "\\.so$"
    shared <- list.files(eng_lib,
                         pattern = paste0("^lib(?:", paste(engine_libs,
                                                           collapse = "|"), ")", ext))
    stop_if(length(shared) != length(engine_libs),
            paste("expected the four engine shared libs in", eng_lib,
                  "; found:", shared))
    file.copy(file.path(eng_lib, shared), libs_dir, overwrite = TRUE)
    shared_paths <- file.path(eng_lib, shared)
  }

  # 4) Generate src/Makevars. Paths are build-time only; the runtime lookup
  # is relative to the installed package (rpath below / DLL dir on Windows).
  inc <- c(vapply(c("core", "csp", "hitas", "rounder"),
                  function(m) file.path(sl_engine_in_tree, "native", m, "src"),
                  character(1)),
           file.path(sl_highs_pre, "include", "highs"))

  mv <- c("# Generated by configure (configure.R); do not edit.",
          "# Build-time flags only: the installed package resolves its own",
          "# libraries relative to the installation, not to these paths.",
          "")
  if (is_win) {
    # MinGW g++: import libs by exact file name, static libs by -l.
    imp <- character(0)
    for (name in engine_libs) {
      hit <- list.files(eng_lib,
                        pattern = paste0("^(?:lib", name, "\\.dll\\.a|", name, "\\.lib)$"))
      stop_if(length(hit) != 1L,
              paste("expected one import lib for", name, "in", eng_lib,
                    "; found:", hit))
      imp <- c(imp, paste0("-l:", hit))
    }
    mv <- c(mv,
      paste0("PKG_CPPFLAGS = ",
             paste(vapply(inc, function(d) paste0("-I", d), character(1)),
                   collapse = " ")),
      paste0("PKG_LIBS = -libpath:", sl_eng_lib, " -libpath:",
             sl(highs_libdir),
             paste(imp, collapse = " "),
             " -ltauargus_core -lhighs"))
  } else {
    # Link the engine dylibs by explicit path: the reference recorded in the
    # R DLL is their install_name (@rpath/...), so the only rpath the
    # installed package needs is the package-relative one below. No
    # build-machine path survives in the binary.
    # Quoted in the Makevars recipe: make collapses $$ to $, and without
    # the quotes the shell would expand $ORIGIN to an empty variable
    # before the linker ever sees it.
    install_rpath <- if (is_mac) "@loader_path" else "$$ORIGIN"
    mv <- c(mv,
      paste0("PKG_CPPFLAGS = ",
             paste(vapply(inc, function(d) paste0("-I", d), character(1)),
                   collapse = " ")),
      paste0("PKG_LIBS = ",
             paste(vapply(shared_paths, sl, character(1)), collapse = " "),
             " -L", sl_eng_lib, " -ltauargus_core",
             " -L", sl(highs_libdir), " -lhighs",
             " -Wl,-rpath,'", install_rpath, "'",
             if (is_mac) "" else " -pthread"))
  }
  writeLines(mv, file.path(pkg_root, "src", "Makevars"))
  # Echo the generated Makevars: it is the single source of the native
  # build flags, and install link/load failures without it are hard to
  # diagnose.
  writeLines(mv)

  # The bundled HiGHS sources have served their purpose (the engine and
  # the headers live in the build tree now); drop them from the package
  # being installed so inst/ is not installed as package data.
  unlink(file.path(pkg_root, "inst", "highs"), recursive = TRUE)

  cat("configure: bundled engine built; Makevars written.\n")
})
