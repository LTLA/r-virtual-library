#  File src/library/utils/R/windows/install.packages.R
#  Part of the R package, https://www.R-project.org
#
#  Copyright (C) 1995-2021 The R Core Team
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  A copy of the GNU General Public License is available at
#  https://www.R-project.org/Licenses/

## Unexported helper
unpackPkgZip <- function(pkg, pkgname, lib, libs_only = FALSE,
                         lock = FALSE, quiet = FALSE, reuse_lockdir = FALSE)
{
    .zip.unpack <- function(zipname, dest)
    {
        if(file.exists(zipname)) {
            if((unzip <- getOption("unzip")) != "internal") {
                system(paste(shQuote(unzip), "-oq", zipname, "-d", dest),
                       show.output.on.console = FALSE, invisible = TRUE)
            } else unzip(zipname, exdir = dest)
        } else stop(gettextf("zip file %s not found",
                             sQuote(zipname)), domain = NA)
    }

    ## Create a temporary directory and unpack the zip to it
    ## then get the real package name, copying the
    ## dir over to the appropriate install dir.
    lib <- normalizePath(lib, mustWork = TRUE)
    tmpDir <- tempfile(, lib)
    if (!dir.create(tmpDir))
        stop(gettextf("unable to create temporary directory %s",
                      sQuote(normalizePath(tmpDir, mustWork = FALSE))),
             domain = NA, call. = FALSE)
    cDir <- getwd()
    ## need to ensure we are not in tmpDir when unlinking is attempted
    on.exit(setwd(cDir))
    on.exit(unlink(tmpDir, recursive=TRUE), add = TRUE)
    res <- .zip.unpack(pkg, tmpDir)
    setwd(tmpDir)
    res <- tools::checkMD5sums(pkgname, file.path(tmpDir, pkgname))
    if(!quiet && !is.na(res) && res) {
        cat(gettextf("package %s successfully unpacked and MD5 sums checked\n",
                     sQuote(pkgname)))
        flush.console()
    }

    ## See src/library/tools/R/admin.R for comment about ExperimentalWindowsRuntime

    ## This experimental feature is intended as temporary. If a similar
    ## feature was intended for regular use, it should be propagated deeper
    ## into the package installation logic. Currently the user may be
    ## offered to install a newer version of a package, but later that
    ## installation may be refused when that version is an incompatible
    ## build.
    desc <- read.dcf(file.path(pkgname, "DESCRIPTION"),
                     c("Package", "Type", 
                       "NeedsCompilation", "ExperimentalWindowsRuntime"))
    if ((desc[1L, "NeedsCompilation"] %in% "yes") &&
        !(desc[1L, "ExperimentalWindowsRuntime"] %in% "ucrt"))
        
        stop(gettextf("package %s not installed because it is not built for UCRT", sQuote(pkgname)), domain = NA)

    if(desc[1L, "Type"] %in% "Translation") {
        fp <- file.path(pkgname, "share", "locale")
        if(file.exists(fp)) {
            langs <- dir(fp)
            for(lang in langs) {
                path0 <- file.path(fp, lang, "LC_MESSAGES")
                mos <- dir(path0, full.names = TRUE)
                path <- file.path(R.home("share"), "locale", lang,
                                  "LC_MESSAGES")
                if(!file.exists(path))
                    if(!dir.create(path, FALSE, TRUE))
                        warning(gettextf("failed to create %s", sQuote(path)),
                                domain = NA)
                res <- file.copy(mos, path, overwrite = TRUE)
                if(any(!res))
                    warning(gettextf("failed to create %s",
                                     paste(sQuote(mos[!res]), collapse=",")),
                            domain = NA)
            }
        }
        fp <- file.path(pkgname, "library")
        if(file.exists(fp)) {
            spkgs <- dir(fp)
            for(spkg in spkgs) {
                langs <- dir(file.path(fp, spkg, "po"))
                for(lang in langs) {
                    path0 <- file.path(fp, spkg, "po", lang, "LC_MESSAGES")
                    mos <- dir(path0, full.names = TRUE)
                    path <- file.path(R.home(), "library", spkg, "po",
                                      lang, "LC_MESSAGES")
                    if(!file.exists(path))
                        if(!dir.create(path, FALSE, TRUE))
                            warning(gettextf("failed to create %s",
                                             sQuote(path)), domain = NA)
                    res <- file.copy(mos, path, overwrite = TRUE)
                    if(any(!res))
                        warning(gettextf("failed to create %s",
                                         paste(sQuote(mos[!res]), collapse=",")),
                                domain = NA)
                }
            }
        }
    } else {
        instPath <- file.path(lib, pkgname)
        if(identical(lock, "pkglock") || isTRUE(lock)) {
            ## This is code adapted from tools:::.install_packages
	    lockdir <- if(identical(lock, "pkglock"))
                file.path(lib, paste0("00LOCK-", pkgname))
            else file.path(lib, "00LOCK")
            if (!reuse_lockdir) {
  	        if (file.exists(lockdir)) {
                    stop(gettextf("ERROR: failed to lock directory %s for modifying\nTry removing %s",
                                  sQuote(lib), sQuote(lockdir)), domain = NA)
	        }
	        dir.create(lockdir, recursive = TRUE)
            }
	    if (!dir.exists(lockdir))
                stop(gettextf("ERROR: failed to create lock directory %s",
                              sQuote(lockdir)), domain = NA)
            ## Back up a previous version
            if (file.exists(instPath)) {
                file.copy(instPath, lockdir, recursive = TRUE)
        	on.exit({
        	    if (restorePrevious) {
        	    	try(unlink(instPath, recursive = TRUE))
        	    	savedcopy <- file.path(lockdir, pkgname)
        	    	file.copy(savedcopy, lib, recursive = TRUE)
        	    	warning(gettextf("restored %s", sQuote(pkgname)),
                                domain = NA, call. = FALSE, immediate. = TRUE)
        	    }
        	}, add=TRUE)
        	restorePrevious <- FALSE
            }
            on.exit({
                ldel <- if (reuse_lockdir) 
                            file.path(lockdir, pkgname)
                        else lockdir
                unlink(ldel, recursive = TRUE)
            }, add=TRUE)
        }

        if(libs_only) {
            if (!file_test("-d", file.path(instPath, "libs")))
                warning(gettextf("there is no 'libs' directory in package %s",
                                 sQuote(pkgname)),
                        domain = NA, call. = FALSE, immediate. = TRUE)
            ## copy over the subdirs of 'libs', removing if already there
            for(sub in c("i386", "x64"))
                if (file_test("-d", file.path(tmpDir, pkgname, "libs", sub))) {
                    unlink(file.path(instPath, "libs", sub), recursive = TRUE)

                    ret <- file.copy(file.path(tmpDir, pkgname, "libs", sub),
                                     file.path(instPath, "libs"),
                                     recursive = TRUE)
                    if(any(!ret)) {
                        warning(gettextf("unable to move temporary installation %s to %s",
                                         sQuote(normalizePath(file.path(tmpDir, pkgname, "libs", sub), mustWork = FALSE)),
                                         sQuote(normalizePath(file.path(instPath, "libs"), mustWork = FALSE))),
                                domain = NA, call. = FALSE, immediate. = TRUE)
                        restorePrevious <- TRUE # Might not be used
                    }
                }
            ## update 'Archs': copied from tools:::.install.packages
            fi <- file.info(Sys.glob(file.path(instPath, "libs", "*")))
            dirs <- row.names(fi[fi$isdir %in% TRUE])
            if (length(dirs)) {
                descfile <- file.path(instPath, "DESCRIPTION")
                olddesc <- readLines(descfile)
                olddesc <- grep("^Archs:", olddesc,
                                invert = TRUE, value = TRUE, useBytes = TRUE)
                newdesc <- c(olddesc,
                             paste("Archs:",
                                   paste(basename(dirs), collapse=", "))
                             )
                writeLines(newdesc, descfile, useBytes = TRUE)
                saveRDS(tools:::.split_description(tools:::.read_description(descfile)),
                        file.path(instPath, "Meta", "package.rds"))
            }
        } else {
            ## If the package is already installed, remove it.  If it
            ## isn't there, the unlink call will still return success.
            ret <- unlink(instPath, recursive=TRUE, force=TRUE)
            if (ret == 0) {
                ## Move the new package to the install lib
                ## file.rename automatically retries few times if necessary
		## due to anti-virus interference
                tmpInstPath <- file.path(tmpDir, pkgname)
                ret <- file.rename(tmpInstPath, instPath)
                if(!ret) {
                    if (dir.exists(tmpInstPath) && !dir.exists(instPath)) {
                        warning(gettextf("unable to move temporary installation %s to %s, copying instead",
                                         sQuote(normalizePath(tmpInstPath, mustWork = FALSE)),
                                         sQuote(normalizePath(instPath, mustWork = FALSE))),
                                domain = NA, call. = FALSE, immediate. = TRUE)
                        ret <- file.copy(tmpInstPath, dirname(instPath),
                                         recursive = TRUE, copy.date = TRUE)
                        if(any(!ret)) {
                            warning(gettextf("unable to copy temporary installation %s to %s",
                                             sQuote(normalizePath(tmpInstPath, mustWork = FALSE)),
                                             sQuote(normalizePath(instPath, mustWork = FALSE))),
                                    domain = NA, call. = FALSE, immediate. = TRUE)
                            restorePrevious <- TRUE # Might not be used
                        }
                        unlink(tmpInstPath, recursive = TRUE)
                    } else {
                        warning(gettextf("unable to move temporary installation %s to %s",
                                         sQuote(normalizePath(tmpInstPath, mustWork = FALSE)),
                                         sQuote(normalizePath(instPath, mustWork = FALSE))),
                                domain = NA, call. = FALSE, immediate. = TRUE)
                        restorePrevious <- TRUE # Might not be used
                    }
                }
            } else {
                warning(gettextf("cannot remove prior installation of package %s",
                                 sQuote(pkgname)),
                        domain = NA, call. = FALSE, immediate. = TRUE)
                restorePrevious <- TRUE # Might not be used
            }
        }
    }
}

## called as
# .install.winbinary(pkgs = pkgs, lib = lib, contriburl = contriburl,
#                    method = method, available = available,
#                    destdir = destdir,
#                    dependencies = dependencies,
#                    libs_only = libs_only, ...)

.install.winbinary <-
    function(pkgs, lib, repos = getOption("repos"),
             contriburl = contrib.url(repos),
             method, available = NULL, destdir = NULL,
             dependencies = FALSE, libs_only = FALSE,
             lock = getOption("install.lock", TRUE), quiet = FALSE, ...)
{
    if(!length(pkgs)) return(invisible())
    pkgnames <- basename(pkgs)
    pkgnames <- sub("\\.zip$", "", pkgnames)
    pkgnames <- sub("_[0-9.-]+$", "", pkgnames)

    if(is.null(contriburl)) {
        for(i in seq_along(pkgs)) {
            if(is.na(pkgs[i])) next
            unpackPkgZip(pkgs[i], pkgnames[i], lib, libs_only, lock, quiet)
        }
        return(invisible())
    }
    tmpd <- destdir
    nonlocalcran <- length(grep("^file:", contriburl)) < length(contriburl)
    if(is.null(destdir) && nonlocalcran) {
        tmpd <- file.path(tempdir(), "downloaded_packages")
        if (!file.exists(tmpd) && !dir.create(tmpd))
            stop(gettextf("unable to create temporary directory %s",
                          sQuote(normalizePath(tmpd, mustWork = FALSE))),
                 domain = NA)
    }

    if(is.null(available))
        available <- available.packages(contriburl = contriburl,
                                        method = method, ...)
    pkgs <- getDependencies(pkgs, dependencies, available, lib, binary = TRUE)

    foundpkgs <- download.packages(pkgs, destdir = tmpd, available = available,
                                   contriburl = contriburl, method = method,
                                   type = "win.binary", quiet = quiet, ...)

    if(length(foundpkgs)) {
        update <- unique(cbind(pkgs, lib))
        colnames(update) <- c("Package", "LibPath")
        for(lib in unique(update[,"LibPath"])) {
            oklib <- lib == update[,"LibPath"]
            for(p in update[oklib, "Package"])
            {
                okp <- p == foundpkgs[, 1L]
                if(any(okp))
                    unpackPkgZip(foundpkgs[okp, 2L], foundpkgs[okp, 1L],
                                 lib, libs_only, lock)
            }
        }
        if(!quiet && !is.null(tmpd) && is.null(destdir))
            ## tends to be a long path on Windows
            cat("\n", gettextf("The downloaded binary packages are in\n\t%s",
                               normalizePath(tmpd, mustWork = FALSE)),
                "\n", sep = "")
    } else if(!is.null(tmpd) && is.null(destdir)) unlink(tmpd, recursive = TRUE)

    invisible()
}

menuInstallPkgs <- function(type = getOption("pkgType"))
{
    install.packages(lib=.libPaths()[1L], dependencies=NA, type=type)
}

menuInstallLocal <- function()
{
    files <- choose.files('',filters=Filters[c('zip','tarball', 'All'),])
    zips <- endsWith(files, ".zip")
    tarballs <- endsWith(files, ".tar.gz")
    bad <- !(zips | tarballs)
    if (any(bad))
        stop("Only '*.zip' and '*.tar.gz' files can be installed.")
    if (any(zips)) install.packages(files[zips],
        .libPaths()[1L], repos = NULL, type = "binary")
    if (any(tarballs)) install.packages(files[tarballs],
        .libPaths()[1L], repos = NULL, type = "source")
}

### Deprecated in 2.13.0, defunct in 2.14.0
zip.unpack <- function(zipname, dest) .Defunct("unzip")

