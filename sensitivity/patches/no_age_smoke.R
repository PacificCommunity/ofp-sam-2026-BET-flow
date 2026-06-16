source_dir <- Sys.getenv("KFLOW_PATCH_SOURCE_DIR")
input_dir <- Sys.getenv("KFLOW_PATCH_INPUT_DIR")
output_dir <- Sys.getenv("KFLOW_PATCH_OUTPUT_DIR")
out_dir <- Sys.getenv("KFLOW_PATCH_OUT_DIR", "outputs")

if (!dir.exists(input_dir)) {
  stop("Patch input directory does not exist: ", input_dir, call. = FALSE)
}

unlink(output_dir, recursive = TRUE, force = TRUE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
files <- list.files(input_dir, full.names = TRUE, all.files = TRUE, no.. = TRUE)
if (length(files)) {
  ok <- file.copy(files, output_dir, overwrite = TRUE, recursive = TRUE, copy.date = TRUE)
  if (any(!ok)) {
    stop("Failed to copy all input files for NoAgeSmoke.", call. = FALSE)
  }
}

metadata <- data.frame(
  recipe = "NoAgeSmoke",
  source_input = sub(paste0("^", normalizePath(source_dir, winslash = "/", mustWork = FALSE), "/?"), "", normalizePath(input_dir, winslash = "/", mustWork = FALSE)),
  output_input = sub(paste0("^", normalizePath(source_dir, winslash = "/", mustWork = FALSE), "/?"), "", normalizePath(output_dir, winslash = "/", mustWork = FALSE)),
  intended_change = "No-age sensitivity recipe marker. The smoke run keeps source files intact and records where the full no-age input edit should be implemented.",
  full_run_note = "Replace this marker with an explicit age-data edit before using the sensitivity for assessment inference.",
  stringsAsFactors = FALSE
)

utils::write.csv(metadata, file.path(output_dir, "sensitivity-metadata.csv"), row.names = FALSE)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(metadata, file.path(out_dir, "no-age-smoke-patch-summary.csv"), row.names = FALSE)
writeLines(
  c(
    "NoAgeSmoke sensitivity marker",
    "",
    "This smoke recipe is intentionally conservative.",
    "It preserves the MFCL input files so the fast makepar check remains runnable.",
    "Use this script as the place to add the explicit age-data edit for the full no-age sensitivity."
  ),
  file.path(output_dir, "README-NoAgeSmoke.txt")
)
