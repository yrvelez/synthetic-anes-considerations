library(readr)
library(dplyr)

input_files <- strsplit(Sys.getenv("INPUT_FILES", ""), ",", fixed = TRUE)[[1]]
input_files <- trimws(input_files)
input_files <- input_files[nzchar(input_files)]
output_file <- Sys.getenv("OUTPUT_FILE", "")

if (length(input_files) == 0) {
  stop("INPUT_FILES is empty.")
}

missing_files <- input_files[!file.exists(input_files)]
if (length(missing_files) > 0) {
  stop("Missing input files: ", paste(missing_files, collapse = ", "))
}

if (!nzchar(output_file)) {
  stop("OUTPUT_FILE is empty.")
}

merged <- bind_rows(lapply(input_files, function(path) {
  read_csv(path, show_col_types = FALSE)
}))

sort_keys <- intersect(c("respID", "prompt_type", "draw", "group", "consideration_rank", "consideration_id"), names(merged))
if (length(sort_keys) > 0) {
  merged <- merged %>% arrange(across(all_of(sort_keys)))
}

write_csv(merged, output_file)
cat("Wrote merged file to ", output_file, "\n", sep = "")
