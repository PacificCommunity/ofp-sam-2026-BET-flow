input_dir <- Sys.getenv("KFLOW_INPUT_DIR", "inputs")
out_dir <- Sys.getenv("KFLOW_OUT_DIR", "outputs")
plot_title <- Sys.getenv("PLOT_TITLE", "BET 2026 depletion smoke check")

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

package_status <- data.frame(
  package = c("mfclshiny", "mfclkit", "mfclrtmb"),
  available = vapply(c("mfclshiny", "mfclkit", "mfclrtmb"), requireNamespace, logical(1), quietly = TRUE),
  stringsAsFactors = FALSE
)
utils::write.csv(package_status, file.path(out_dir, "plot-package-status.csv"), row.names = FALSE)

depletion_files <- list.files(input_dir, pattern = "^depletion-smoke[.]csv$", recursive = TRUE, full.names = TRUE)
if (!length(depletion_files)) {
  stop("No depletion-smoke.csv files were found in upstream inputs.", call. = FALSE)
}

read_one <- function(file) {
  x <- utils::read.csv(file, stringsAsFactors = FALSE)
  x$source_file <- file
  x
}
depletion <- do.call(rbind, lapply(depletion_files, read_one))
depletion$year <- suppressWarnings(as.integer(depletion$year))
depletion$depletion <- suppressWarnings(as.numeric(depletion$depletion))
depletion <- depletion[is.finite(depletion$year) & is.finite(depletion$depletion), , drop = FALSE]
utils::write.csv(depletion, file.path(out_dir, "depletion-smoke-combined.csv"), row.names = FALSE)

mfclshiny_status <- "not_available"
if (isTRUE(package_status$available[package_status$package == "mfclshiny"])) {
  mfclshiny_status <- tryCatch({
    model_roots <- unique(dirname(depletion_files))
    # This builds payloads only when real MFCL raw outputs are present. For the
    # smoke path it records that the mfclshiny batch hook was reached.
    mfclshiny::build_model_payloads(model_roots[[1]], recursive = TRUE, overwrite = FALSE)
    "payload_attempted"
  }, error = function(e) {
    paste("payload_skipped:", conditionMessage(e))
  })
}
writeLines(mfclshiny_status, file.path(out_dir, "mfclshiny-status.txt"))

plot_file <- file.path(out_dir, "model-exploration-overview.svg")
png_file <- file.path(out_dir, "depletion-smoke.png")

if (requireNamespace("ggplot2", quietly = TRUE)) {
  p <- ggplot2::ggplot(
    depletion,
    ggplot2::aes(x = year, y = depletion, colour = model_token, group = interaction(model_token, region))
  ) +
    ggplot2::geom_line(linewidth = 0.7, alpha = 0.8) +
    ggplot2::geom_point(size = 1.8, alpha = 0.9) +
    ggplot2::facet_wrap(ggplot2::vars(region), nrow = 1) +
    ggplot2::scale_y_continuous(labels = function(x) paste0(round(x * 100), "%"), limits = c(0, 1)) +
    ggplot2::labs(
      title = plot_title,
      subtitle = "Smoke-run depletion trace for checking the Kflow dependency path",
      x = NULL,
      y = "Depletion",
      colour = "Model"
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      legend.position = "bottom",
      plot.title.position = "plot"
    )
  ggplot2::ggsave(plot_file, p, width = 10, height = 5, units = "in")
  ggplot2::ggsave(png_file, p, width = 10, height = 5, units = "in", dpi = 160)
} else {
  grDevices::svg(plot_file, width = 10, height = 5)
  old <- graphics::par(mar = c(4, 5, 3, 1))
  on.exit(graphics::par(old), add = TRUE)
  avg <- stats::aggregate(depletion ~ year + model_token, depletion, mean)
  tokens <- unique(avg$model_token)
  graphics::plot(
    range(avg$year),
    c(0, 1),
    type = "n",
    xlab = "",
    ylab = "Depletion",
    main = plot_title
  )
  cols <- grDevices::hcl.colors(length(tokens), "Dark 3")
  for (i in seq_along(tokens)) {
    x <- avg[avg$model_token == tokens[[i]], ]
    graphics::lines(x$year, x$depletion, col = cols[[i]], lwd = 2)
    graphics::points(x$year, x$depletion, col = cols[[i]], pch = 19)
  }
  graphics::legend("bottomleft", legend = tokens, col = cols, lwd = 2, bty = "n")
  grDevices::dev.off()
}

summary <- stats::aggregate(
  depletion ~ model_key + model_token + change_token,
  depletion,
  function(x) round(mean(x, na.rm = TRUE), 3)
)
names(summary)[names(summary) == "depletion"] <- "mean_depletion"
summary$plot_file <- basename(plot_file)
utils::write.csv(summary, file.path(out_dir, "depletion-plot-summary.csv"), row.names = FALSE)
