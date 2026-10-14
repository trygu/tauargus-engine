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

  run <- function(args) {
    cat(paste0("configure: cmake ", paste(args, collapse = " "), "\n"))
    ok <- system2("cmake", args, stdout = 2, stderr = 2)
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
  engine_rpath <- if (is_mac) "@loader_path" else if (is_win) NULL else "$ORIGIN"
  e_args <- c("-S", sl_engine_src, "-B", sl_engine_bld, gen,
              "-DCMAKE_BUILD_TYPE=Release",
              paste0("-DHighs_DIR=", file.path(sl_highs_pre, "lib", "cmake", "Highs")),
              paste0("-DCMAKE_INSTALL_PREFIX=", sl_engine_pre))
  if (!is.null(engine_rpath))
    e_args <- c(e_args, paste0("-DCMAKE_INSTALL_RPATH=", engine_rpath))
  run(e_args)
  run(c("--build", sl_engine_bld, "--parallel", jobs))
  run(c("--install", sl_engine_bld))

  # 3) Stage the engine runtime libs into inst/libs -> installed <pkg>/libs.
  libs_dir <- file.path(pkg_root, "inst", "libs")
  unlink(libs_dir, recursive = TRUE)
  dir.create(libs_dir, recursive = TRUE, showWarnings = FALSE)

  engine_libs <- c("tauargus_csp", "tauargus_hitas", "tauargus_rounder", "CRP")
  if (is_win) {
    dlls <- list.files(eng_bin, pattern = paste0("^(?:" ,
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
                  function(m) file.path(sl_engine_src, "native", m, "src"),
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
             sl(file.path(highs_pre, "lib")),
             paste(imp, collapse = " "),
             " -ltauargus_core -lhighs"))
  } else {
    # Link the engine dylibs by explicit path: the reference recorded in the
    # R DLL is their install_name (@rpath/...), so the only rpath the
    # installed package needs is the package-relative one below. No
    # build-machine path survives in the binary.
    install_rpath <- if (is_mac) "@loader_path" else "$$ORIGIN"
    mv <- c(mv,
      paste0("PKG_CPPFLAGS = ",
             paste(vapply(inc, function(d) paste0("-I", d), character(1)),
                   collapse = " ")),
      paste0("PKG_LIBS = ",
             paste(vapply(shared_paths, sl, character(1)), collapse = " "),
             " -L", sl_eng_lib, " -ltauargus_core",
             " -L", sl(file.path(highs_pre, "lib")), " -lhighs",
             " -Wl,-rpath,", install_rpath,
             if (is_mac) "" else " -pthread"))
  }
  writeLines(mv, file.path(pkg_root, "src", "Makevars"))

  cat("configure: bundled engine built; Makevars written.\n")
})
