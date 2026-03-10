# ============================================================
# YouTube Channel Analytics - Data Preprocessing in R
# Dataset: Global YouTube Statistics (1,006 rows x 29 columns)
# Uses ONLY base R - no external packages needed
# ============================================================

# ----------------------------------------------------------
# 1. Load the Dataset
# ----------------------------------------------------------
# Using latin-1 encoding (UTF-8 has known issues with this dataset)
df <- read.csv("GlobalYouTubeStatistics.csv", fileEncoding = "latin1",
               stringsAsFactors = FALSE, na.strings = c("", "nan", "NaN", "NA"))

cat("============================================\n")
cat("  DATA PREPROCESSING - YouTube Analytics\n")
cat("============================================\n\n")
cat("[LOAD] Dataset Loaded\n")
cat("  Rows:", nrow(df), "\n")
cat("  Columns:", ncol(df), "\n\n")

# ----------------------------------------------------------
# 2. Inspect the Dataset Structure
# ----------------------------------------------------------
cat("-- Structure of the Dataset --\n")
str(df)
cat("\n-- First 5 Rows --\n")
print(head(df, 5))
cat("\n-- Summary Statistics --\n")
print(summary(df))
cat("\n")

# ----------------------------------------------------------
# 3. Column Names - Normalize & Clean
# ----------------------------------------------------------
original_names <- colnames(df)
colnames(df) <- tolower(colnames(df))
colnames(df) <- gsub("[^a-z0-9]", "_", colnames(df))
colnames(df) <- gsub("_+", "_", colnames(df))
colnames(df) <- gsub("^_|_$", "", colnames(df))

cat("-- Cleaned Column Names --\n")
name_table <- data.frame(Original = original_names, Cleaned = colnames(df))
print(name_table)
cat("\n")

# ----------------------------------------------------------
# 4. Drop Redundant Columns
# ----------------------------------------------------------
# 'title' is redundant with 'youtuber' and has encoding issues (106 rows)
# 'country' is redundant with 'country_of_origin' and has inconsistencies
drop_cols <- intersect(c("title", "country"), colnames(df))
if (length(drop_cols) > 0) {
  df <- df[, !(colnames(df) %in% drop_cols)]
  cat("[DROP] Removed redundant columns:", paste(drop_cols, collapse = ", "), "\n\n")
}

# ----------------------------------------------------------
# 5. Fix Encoding Corruption in Text Columns
# ----------------------------------------------------------
# Remove corrupted characters (y, i, A, ?, 1/2, etc.)
fix_encoding <- function(x) {
  if (!is.character(x)) return(x)
  x <- iconv(x, from = "latin1", to = "UTF-8", sub = "")
  # Remove non-ASCII characters that may be encoding artifacts
  x <- iconv(x, from = "UTF-8", to = "ASCII", sub = "")
  x <- trimws(gsub("\\s+", " ", x))
  return(x)
}

text_cols <- colnames(df)[sapply(df, is.character)]
for (col in text_cols) {
  df[[col]] <- fix_encoding(df[[col]])
}
cat("[ENCODE] Fixed encoding in text columns:", paste(text_cols, collapse = ", "), "\n\n")

# ----------------------------------------------------------
# 6. Missing Values Analysis
# ----------------------------------------------------------
cat("-- Missing Values Summary --\n")
missing_count   <- sapply(df, function(x) sum(is.na(x)))
missing_pct     <- round(sapply(df, function(x) mean(is.na(x))) * 100, 2)
missing_summary <- data.frame(Column = names(missing_count),
                              Missing = missing_count,
                              Pct = missing_pct)
missing_summary <- missing_summary[order(-missing_summary$Missing), ]
rownames(missing_summary) <- NULL
print(missing_summary)
cat("\n")

# ----------------------------------------------------------
# 7. Handle Missing Values
# ----------------------------------------------------------

# --- 7a. Drop column with >30% missing (subscribers_for_last_30_days ~33.8%) ---
high_miss_cols <- names(missing_pct[missing_pct > 30])
if (length(high_miss_cols) > 0) {
  for (col in high_miss_cols) {
    cat(sprintf("[DROP] '%s' has %.1f%% missing - dropping column\n", col, missing_pct[col]))
    df[[col]] <- NULL
  }
  cat("\n")
}

# --- 7b. Mode function for categorical imputation ---
get_mode <- function(v) {
  v <- v[!is.na(v)]
  if (length(v) == 0) return(NA)
  uniq <- unique(v)
  uniq[which.max(tabulate(match(v, uniq)))]
}

# --- 7c. Impute CATEGORICAL columns with MODE ---
cat_cols <- c("category", "channel_type", "country_of_origin", "abbreviation")
cat_cols <- intersect(cat_cols, colnames(df))

for (col in cat_cols) {
  na_count <- sum(is.na(df[[col]]))
  if (na_count > 0) {
    mode_val <- get_mode(df[[col]])
    df[[col]][is.na(df[[col]])] <- mode_val
    cat(sprintf("[IMPUTE] '%s': %d NAs filled with mode = '%s'\n", col, na_count, mode_val))
  }
}

# --- 7d. Impute NUMERIC columns with MEDIAN ---
num_cols <- colnames(df)[sapply(df, is.numeric)]
for (col in num_cols) {
  na_count <- sum(is.na(df[[col]]))
  if (na_count > 0) {
    med_val <- median(df[[col]], na.rm = TRUE)
    df[[col]][is.na(df[[col]])] <- med_val
    cat(sprintf("[IMPUTE] '%s': %d NAs filled with median = %.2f\n", col, na_count, med_val))
  }
}

cat("\n[OK] Missing values handled\n\n")

# ----------------------------------------------------------
# 8. Remove Duplicate Rows
# ----------------------------------------------------------
dup_count <- sum(duplicated(df))
cat(sprintf("[DUP] Duplicate rows found: %d\n", dup_count))
if (dup_count > 0) {
  df <- df[!duplicated(df), ]
  cat(sprintf("  Removed %d duplicates. New row count: %d\n", dup_count, nrow(df)))
}

# Handle duplicate channel names
if ("youtuber" %in% colnames(df)) {
  dup_names <- df$youtuber[duplicated(df$youtuber)]
  if (length(dup_names) > 0) {
    cat(sprintf("[DUP] %d duplicate channel names detected\n", length(dup_names)))
    cat("  Duplicate names:", paste(unique(dup_names), collapse = ", "), "\n")
    df <- df[!duplicated(df$youtuber), ]
    cat(sprintf("  Kept first occurrence. New row count: %d\n", nrow(df)))
  }
}
cat("\n")

# ----------------------------------------------------------
# 9. Data Type Conversions
# ----------------------------------------------------------
cat("-- Data Type Conversions --\n")

# Ensure numeric columns are numeric
numeric_target <- c("subscribers", "video_views", "uploads",
                    "video_views_for_the_last_30_days",
                    "lowest_monthly_earnings", "highest_monthly_earnings",
                    "lowest_yearly_earnings", "highest_yearly_earnings",
                    "video_views_rank", "country_rank", "channel_type_rank",
                    "gross_tertiary_education_enrollment___",
                    "population", "unemployment_rate", "urban_population",
                    "latitude", "longitude")
numeric_target <- intersect(numeric_target, colnames(df))

for (col in numeric_target) {
  if (!is.numeric(df[[col]])) {
    df[[col]] <- suppressWarnings(as.numeric(df[[col]]))
    cat(sprintf("  [NUM] Converted '%s' to numeric\n", col))
  }
}

# Convert categorical columns to factors
factor_target <- c("category", "channel_type", "country_of_origin", "abbreviation")
factor_target <- intersect(factor_target, colnames(df))

for (col in factor_target) {
  df[[col]] <- as.factor(df[[col]])
  cat(sprintf("  [FAC] Converted '%s' to factor (%d levels)\n", col, nlevels(df[[col]])))
}

# Convert created_year and created_date to integer
for (col in intersect(c("created_year", "created_date"), colnames(df))) {
  df[[col]] <- suppressWarnings(as.integer(df[[col]]))
  cat(sprintf("  [INT] Converted '%s' to integer\n", col))
}

cat("\n")

# ----------------------------------------------------------
# 10. Feature Engineering
# ----------------------------------------------------------
cat("-- Feature Engineering --\n")

# --- 10a. Combine date columns into single Date ---
if (all(c("created_year", "created_month", "created_date") %in% colnames(df))) {
  month_map <- c(Jan=1, Feb=2, Mar=3, Apr=4, May=5, Jun=6,
                 Jul=7, Aug=8, Sep=9, Oct=10, Nov=11, Dec=12)
  df$created_month_num <- month_map[df$created_month]
  df$created_month_num[is.na(df$created_month_num)] <- 1

  df$channel_created_date <- as.Date(
    paste(df$created_year, df$created_month_num, df$created_date, sep = "-"),
    format = "%Y-%m-%d"
  )
  cat("  [DATE] Created 'channel_created_date' from year/month/date\n")

  # Fix 1970 outlier
  if (any(df$created_year == 1970, na.rm = TRUE)) {
    n1970 <- sum(df$created_year == 1970, na.rm = TRUE)
    df$channel_created_date[df$created_year == 1970] <- NA
    cat(sprintf("  [FIX] Set %d channel(s) with year=1970 to NA (erroneous)\n", n1970))
  }
  df$created_month_num <- NULL
}

# --- 10b. Channel Age (years) ---
if ("channel_created_date" %in% colnames(df)) {
  df$channel_age_years <- round(
    as.numeric(difftime(Sys.Date(), df$channel_created_date, units = "days")) / 365.25, 2
  )
  cat("  [NEW] Created 'channel_age_years'\n")
}

# --- 10c. Average Monthly Subscriber Gain ---
if (all(c("subscribers", "channel_age_years") %in% colnames(df))) {
  df$avg_monthly_sub_gain <- ifelse(
    df$channel_age_years > 0,
    round(df$subscribers / (df$channel_age_years * 12), 0),
    NA
  )
  cat("  [NEW] Created 'avg_monthly_sub_gain'\n")
}

# --- 10d. Earnings midpoint ---
if (all(c("lowest_monthly_earnings", "highest_monthly_earnings") %in% colnames(df))) {
  df$avg_monthly_earnings <- round(
    (df$lowest_monthly_earnings + df$highest_monthly_earnings) / 2, 2
  )
  cat("  [NEW] Created 'avg_monthly_earnings'\n")
}
if (all(c("lowest_yearly_earnings", "highest_yearly_earnings") %in% colnames(df))) {
  df$avg_yearly_earnings <- round(
    (df$lowest_yearly_earnings + df$highest_yearly_earnings) / 2, 2
  )
  cat("  [NEW] Created 'avg_yearly_earnings'\n")
}

cat("\n")

# ----------------------------------------------------------
# 11. Log Transformations (for skewed data)
# ----------------------------------------------------------
cat("-- Log Transformations --\n")
log_cols <- intersect(
  c("subscribers", "video_views", "uploads",
    "video_views_for_the_last_30_days",
    "avg_monthly_earnings", "avg_yearly_earnings"),
  colnames(df)
)

for (col in log_cols) {
  new_col <- paste0("log_", col)
  df[[new_col]] <- log1p(df[[col]])   # log(1+x) to handle zeros
  cat(sprintf("  [LOG] Created '%s'\n", new_col))
}
cat("\n")

# ----------------------------------------------------------
# 12. Outlier Detection (IQR Method)
# ----------------------------------------------------------
cat("-- Outlier Detection (IQR Method) --\n")

detect_outliers <- function(x) {
  x <- x[!is.na(x)]
  Q1 <- quantile(x, 0.25)
  Q3 <- quantile(x, 0.75)
  IQR_val <- Q3 - Q1
  lower <- Q1 - 1.5 * IQR_val
  upper <- Q3 + 1.5 * IQR_val
  list(count = sum(x < lower | x > upper), lower = lower, upper = upper)
}

outlier_cols <- intersect(
  c("subscribers", "video_views", "uploads", "avg_yearly_earnings"),
  colnames(df)
)

for (col in outlier_cols) {
  res <- detect_outliers(df[[col]])
  cat(sprintf("  [OUT] '%s': %d outliers detected\n", col, res$count))
}

# Flag outliers in yearly earnings
if ("avg_yearly_earnings" %in% colnames(df)) {
  Q1 <- quantile(df$avg_yearly_earnings, 0.25, na.rm = TRUE)
  Q3 <- quantile(df$avg_yearly_earnings, 0.75, na.rm = TRUE)
  IQR_val <- Q3 - Q1
  df$earnings_outlier <- (df$avg_yearly_earnings < (Q1 - 1.5 * IQR_val)) |
                         (df$avg_yearly_earnings > (Q3 + 1.5 * IQR_val))
  cat(sprintf("  [FLAG] 'earnings_outlier' column added (%d outliers)\n",
              sum(df$earnings_outlier, na.rm = TRUE)))
}
cat("\n")

# ----------------------------------------------------------
# 13. Handle Zero Values
# ----------------------------------------------------------
cat("-- Zero Value Investigation --\n")
zero_views   <- sum(df$video_views == 0, na.rm = TRUE)
zero_uploads <- sum(df$uploads == 0, na.rm = TRUE)
cat(sprintf("  Channels with 0 video views : %d\n", zero_views))
cat(sprintf("  Channels with 0 uploads     : %d\n", zero_uploads))

if ("avg_monthly_earnings" %in% colnames(df)) {
  zero_earn <- sum(df$avg_monthly_earnings == 0, na.rm = TRUE)
  cat(sprintf("  Channels with $0 earnings   : %d\n", zero_earn))
}

# Flag inactive channels
df$is_inactive <- (df$uploads == 0) | (df$video_views == 0)
cat(sprintf("  [FLAG] Flagged %d channels as inactive\n\n", sum(df$is_inactive, na.rm = TRUE)))

# ----------------------------------------------------------
# 14. Normalization (Min-Max Scaling)
# ----------------------------------------------------------
cat("-- Min-Max Normalization --\n")

min_max_scale <- function(x) {
  rng <- range(x, na.rm = TRUE)
  if (rng[2] == rng[1]) return(rep(0, length(x)))
  (x - rng[1]) / (rng[2] - rng[1])
}

norm_cols <- intersect(
  c("subscribers", "video_views", "uploads",
    "video_views_rank", "country_rank", "channel_type_rank"),
  colnames(df)
)

for (col in norm_cols) {
  new_col <- paste0("norm_", col)
  df[[new_col]] <- round(min_max_scale(df[[col]]), 4)
  cat(sprintf("  [NORM] Created '%s'\n", new_col))
}
cat("\n")

# ----------------------------------------------------------
# 15. Verify Earnings Consistency
# ----------------------------------------------------------
if (all(c("avg_monthly_earnings", "avg_yearly_earnings") %in% colnames(df))) {
  cat("-- Earnings Consistency Check --\n")
  df$earnings_consistent <- abs(df$avg_yearly_earnings - df$avg_monthly_earnings * 12) < 1
  pct <- round(mean(df$earnings_consistent, na.rm = TRUE) * 100, 1)
  cat(sprintf("  Yearly ~ Monthly x 12 : %.1f%% consistent\n\n", pct))
}

# ----------------------------------------------------------
# 16. Final Dataset Overview
# ----------------------------------------------------------
cat("============================================\n")
cat("       FINAL CLEANED DATASET SUMMARY       \n")
cat("============================================\n")
cat("  Rows    :", nrow(df), "\n")
cat("  Columns :", ncol(df), "\n")
cat("  Total NAs:", sum(is.na(df)), "\n\n")

cat("-- Column Names & Types --\n")
col_info <- data.frame(
  Column = colnames(df),
  Type   = sapply(df, function(x) class(x)[1]),
  NAs    = sapply(df, function(x) sum(is.na(x)))
)
rownames(col_info) <- NULL
print(col_info)

cat("\n-- Numeric Summary --\n")
num_data <- df[, sapply(df, is.numeric)]
print(summary(num_data))

# ----------------------------------------------------------
# 17. Export Cleaned Dataset
# ----------------------------------------------------------
output_file <- "GlobalYouTubeStatistics_Cleaned.csv"
write.csv(df, output_file, row.names = FALSE)
cat(sprintf("\n[SAVE] Cleaned dataset saved to: %s\n", output_file))
cat(sprintf("  Final dimensions: %d rows x %d columns\n", nrow(df), ncol(df)))
cat("\n>> Data Preprocessing Complete!\n")
