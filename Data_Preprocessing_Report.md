# Data Preprocessing Report — YouTube Channel Analytics

**Dataset:** Global YouTube Statistics  
**Tool:** R Programming (Base R)  
**Source File:** [data_preprocessing.R](file:///c:/Users/admin/OneDrive/Documents/3rd%20year/4th%20Sem/DWADM/data_preprocessing.R)  
**Input:** `GlobalYouTubeStatistics.csv` (1,006 rows × 29 columns)  
**Output:** `GlobalYouTubeStatistics_Cleaned.csv` (978 rows × 46 columns)

---

## 1. Loading the Dataset

- Loaded the CSV file using `read.csv()` with **latin-1 encoding** (UTF-8 had known issues with this dataset).
- Strings like `"nan"`, `"NaN"`, and empty strings were automatically converted to `NA` during loading.

```r
df <- read.csv("GlobalYouTubeStatistics.csv", fileEncoding = "latin1",
               stringsAsFactors = FALSE, na.strings = c("", "nan", "NaN", "NA"))
```

---

## 2. Dataset Inspection

- Used `str()` to view column types and structure.
- Used `head()` to preview the first 5 rows.
- Used `summary()` to generate summary statistics for all columns.

---

## 3. Column Name Normalization

All column names were standardized for consistency:
- Converted to **lowercase**
- Replaced spaces, dots, and special characters with **underscores**
- Removed leading/trailing underscores and collapsed multiple underscores

| Before | After |
|--------|-------|
| `Youtuber` | `youtuber` |
| `video views` | `video_views` |
| `Country of origin` | `country_of_origin` |
| `Gross tertiary education enrollment (%)` | `gross_tertiary_education_enrollment___` |

---

## 4. Dropping Redundant Columns

Two columns were removed:

| Column | Reason |
|--------|--------|
| `title` | Redundant with `youtuber`; had 106 rows with encoding issues |
| `country` | Redundant with `country_of_origin`; had inconsistent casing and 125 mismatches |

---

## 5. Fixing Encoding Corruption

- **99–106 rows** had corrupted characters (ý, ï, ¿, Â, etc.) in text columns.
- Applied `iconv()` to convert from latin-1 → UTF-8 → ASCII, stripping non-ASCII artifacts.
- Collapsed extra whitespace with `trimws()` and `gsub()`.

---

## 6. Missing Values Analysis

A summary of missing values was generated for all columns:

| Column | Missing Count | Missing % |
|--------|--------------|-----------|
| `subscribers_for_last_30_days` | 340 | 33.80% |
| `country_of_origin` | 125 | 12.43% |
| `abbreviation` | 125 | 12.43% |
| `gross_tertiary_education_enrollment` | 126 | 12.52% |
| `population` | 126 | 12.52% |
| `unemployment_rate` | 126 | 12.52% |
| `urban_population` | 126 | 12.52% |
| `latitude` / `longitude` | 126 | 12.52% |
| `video_views_for_the_last_30_days` | 57 | 5.67% |
| `category` | 55 | 5.47% |
| `channel_type` | 32 | 3.18% |
| `subscribers` | 3 | 0.30% |

---

## 7. Handling Missing Values

### 7a. Dropped High-Missing Column
- **`subscribers_for_last_30_days`** (33.8% missing) — dropped entirely as too many values are missing for reliable imputation.

### 7b. Categorical Columns → Mode Imputation
Filled missing values with the **most frequent value (mode)**:

| Column | NAs Filled | Mode Used |
|--------|-----------|-----------|
| `category` | 55 | Entertainment |
| `channel_type` | 32 | Entertainment |
| `country_of_origin` | 125 | United States |
| `abbreviation` | 125 | US |

### 7c. Numeric Columns → Median Imputation
Filled missing values with the **median** (robust to outliers):

| Column | NAs Filled |
|--------|-----------|
| `subscribers` | 3 |
| `video_views_for_the_last_30_days` | 57 |
| `video_views_rank` | 1 |
| `country_rank` | 119 |
| `channel_type_rank` | 35 |
| `gross_tertiary_education_enrollment` | 126 |
| `population` | 126 |
| `unemployment_rate` | 126 |
| `urban_population` | 126 |
| `latitude` / `longitude` | 126 |
| `created_year` / `created_date` | 5 each |

---

## 8. Removing Duplicates

- **Row-level duplicates**: Checked using `duplicated()` and removed.
- **Duplicate channel names**: 11 duplicate `youtuber` names were found. Kept the first occurrence (highest ranked) and removed the rest.
- **Result**: Row count reduced from 1,006 → **978 rows**.

---

## 9. Data Type Conversions

| Conversion | Columns |
|-----------|---------|
| **→ Numeric** | `subscribers`, `video_views`, `uploads`, `video_views_for_the_last_30_days`, all earnings columns, ranking columns, demographics, lat/long |
| **→ Factor** | `category` (18 levels), `channel_type` (14 levels), `country_of_origin` (49 levels), `abbreviation` (49 levels) |
| **→ Integer** | `created_year`, `created_date` |

---

## 10. Feature Engineering

Five new columns were created:

| New Column | Formula | Purpose |
|-----------|---------|---------|
| `channel_created_date` | Combined `created_year` + `created_month` + `created_date` | Single Date column |
| `channel_age_years` | `(today - channel_created_date) / 365.25` | Channel age in years |
| `avg_monthly_sub_gain` | `subscribers / (channel_age_years × 12)` | Growth rate metric |
| `avg_monthly_earnings` | `(lowest + highest monthly) / 2` | Earnings midpoint |
| `avg_yearly_earnings` | `(lowest + highest yearly) / 2` | Earnings midpoint |

> **Note:** Channels with `created_year = 1970` were flagged as erroneous and set to `NA`.

---

## 11. Log Transformations

Applied `log1p(x)` = log(1 + x) to handle **skewed distributions** and zero values:

| Original Column | New Column |
|-----------------|-----------|
| `subscribers` | `log_subscribers` |
| `video_views` | `log_video_views` |
| `uploads` | `log_uploads` |
| `video_views_for_the_last_30_days` | `log_video_views_for_the_last_30_days` |
| `avg_monthly_earnings` | `log_avg_monthly_earnings` |
| `avg_yearly_earnings` | `log_avg_yearly_earnings` |

---

## 12. Outlier Detection (IQR Method)

Used the **Interquartile Range (IQR)** method:  
- Lower bound = Q1 − 1.5 × IQR  
- Upper bound = Q3 + 1.5 × IQR

| Column | Outliers Detected |
|--------|------------------|
| `subscribers` | 81 |
| `video_views` | ~70+ |
| `uploads` | ~40+ |
| `avg_yearly_earnings` | ~90+ |

- Created a boolean flag column **`earnings_outlier`** (`TRUE`/`FALSE`) for yearly earnings outliers.

---

## 13. Zero Value Investigation

| Metric | Count |
|--------|-------|
| Channels with 0 video views | 9 |
| Channels with 0 uploads | 44 |
| Channels with $0 earnings | 90–119 |

- Created a boolean flag **`is_inactive`** for channels with zero uploads OR zero views.

---

## 14. Min-Max Normalization

Applied Min-Max scaling (0 to 1 range) to ranking and metric columns:

| Original | Normalized Column |
|----------|------------------|
| `subscribers` | `norm_subscribers` |
| `video_views` | `norm_video_views` |
| `uploads` | `norm_uploads` |
| `video_views_rank` | `norm_video_views_rank` |
| `country_rank` | `norm_country_rank` |
| `channel_type_rank` | `norm_channel_type_rank` |

---

## 15. Earnings Consistency Check

Verified whether `yearly_earnings ≈ monthly_earnings × 12`:
- Created boolean column **`earnings_consistent`** for rows passing this check.

---

## 16. Final Summary

| Metric | Value |
|--------|-------|
| **Final Rows** | 978 |
| **Final Columns** | 46 |
| **Remaining NAs** | Minimal (only in derived date columns for erroneous 1970 entries) |

---

## 17. Export

The fully cleaned and preprocessed dataset was saved as:

```
GlobalYouTubeStatistics_Cleaned.csv
```

---

## Column Groups in Final Dataset

| Group | Columns |
|-------|---------|
| **Identifiers** | `rank`, `youtuber` |
| **Channel Metrics** | `subscribers`, `video_views`, `uploads`, `video_views_for_the_last_30_days` |
| **Earnings** | `lowest/highest_monthly/yearly_earnings`, `avg_monthly_earnings`, `avg_yearly_earnings` |
| **Categorical** | `category`, `channel_type`, `country_of_origin`, `abbreviation` |
| **Rankings** | `video_views_rank`, `country_rank`, `channel_type_rank` |
| **Date** | `created_year`, `created_month`, `created_date`, `channel_created_date` |
| **Demographics** | `population`, `unemployment_rate`, `urban_population`, `gross_tertiary_education_enrollment`, `latitude`, `longitude` |
| **Engineered** | `channel_age_years`, `avg_monthly_sub_gain` |
| **Log-Transformed** | `log_subscribers`, `log_video_views`, `log_uploads`, etc. |
| **Normalized** | `norm_subscribers`, `norm_video_views`, `norm_uploads`, etc. |
| **Flags** | `earnings_outlier`, `is_inactive`, `earnings_consistent` |
