# Revised R companion for the published portfolio snapshot, October 2026.
# Run: Rscript quantium_reanalysis.R /path/to/QVI_transaction_data.csv /path/to/output
# Requires data.table. This is a descriptive reconstruction, not a causal test.
# The published snapshot was independently computed in Python; this R companion
# was reviewed but not executed in the portfolio editing environment.
library(data.table)
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("Supply the source CSV path and an output directory")
dir.create(args[2], recursive = TRUE, showWarnings = FALSE)
d <- unique(fread(args[1]))
required <- c("DATE", "STORE_NBR", "LYLTY_CARD_NBR", "TXN_ID", "PROD_NBR", "PROD_NAME", "PROD_QTY", "TOT_SALES")
stopifnot(identical(names(d), required), !anyNA(d))
# Two 200-unit purchases belong to this single outlier customer.
d <- d[LYLTY_CARD_NBR != 226000]
d[, month := format(as.Date(DATE, origin = "1899-12-30"), "%Y-%m")]
m <- d[, .(sales = sum(TOT_SALES), customers = uniqueN(LYLTY_CARD_NBR),
           transactions = uniqueN(TXN_ID), units = sum(PROD_QTY)), by = .(STORE_NBR, month)]
setorder(m, STORE_NBR, month)
trials <- c(77L, 86L, 88L)
eligible <- m[, .N, by = STORE_NBR][N == 12L, STORE_NBR]
candidates <- setdiff(eligible, trials)
pre <- m[month < "2019-02" & STORE_NBR %in% eligible]
results <- list(); rankings <- list()
for (trial in trials) {
  scores <- data.table(control = candidates)
  for (metric in c("sales", "customers")) {
    wide <- dcast(pre, month ~ STORE_NBR, value.var = metric)
    t <- wide[[as.character(trial)]]
    values <- as.matrix(wide[, as.character(candidates), with = FALSE])
    distances <- abs(sweep(values, 1L, t, "-"))
    low <- apply(distances, 1L, min); span <- apply(distances, 1L, max) - low
    magnitude <- 1 - sweep(sweep(distances, 1L, low, "-"), 1L, ifelse(span == 0, 1, span), "/")
    correlations <- apply(values, 2L, function(x) if (sd(x) == 0 || sd(t) == 0) 0 else cor(x, t))
    scores[, (paste0(metric, "_correlation")) := correlations]
    scores[, (paste0(metric, "_magnitude")) := colMeans(magnitude)]
  }
  scores[, score := rowMeans(.SD), .SDcols = setdiff(names(scores), "control")]
  setorder(scores, -score, control)
  control <- scores$control[1L]
  rankings[[as.character(trial)]] <- copy(scores)[, `:=`(trial = trial, rank = seq_len(.N))]
  result <- data.table(trial = trial, control = control, score = scores$score[1L])
  for (metric in c("sales", "customers")) {
    t <- m[STORE_NBR == trial, .(month, actual = get(metric))]
    c <- m[STORE_NBR == control, .(month, comparator = get(metric))]
    pair <- merge(t, c, by = "month")
    scale <- pair[month < "2019-02", sum(actual) / sum(comparator)]
    observed <- pair[month >= "2019-02" & month <= "2019-04", sum(actual)]
    expected <- pair[month >= "2019-02" & month <= "2019-04", sum(comparator)] * scale
    result[, (paste0(metric, c("_scale", "_actual", "_expected", "_gap", "_gap_pct"))) :=
             list(scale, observed, expected, observed - expected, 100 * (observed / expected - 1))]
  }
  results[[as.character(trial)]] <- result
}
fwrite(m, file.path(args[2], "monthly-store-metrics.csv"))
fwrite(rbindlist(results), file.path(args[2], "trial-results.csv"))
fwrite(rbindlist(rankings), file.path(args[2], "control-rankings.csv"))
print(rbindlist(results))
# customers_actual sums monthly uniques: a customer may appear in multiple months.
# Do not interpret these gaps as statistically significant or annualize to $200K.
