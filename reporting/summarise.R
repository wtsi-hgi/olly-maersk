#!/usr/bin/env Rscript

# Cromwell Executions Status Summariser
# Christopher Harrison <ch12@sanger.ac.uk>

# FIXME R throws up all over stderr; suppress this output

require(readr)
require(tidyr)
require(dplyr)

columns <- c("workflow", "run_id", "task", "shards",
             "attempts", "job_id", "status", "exit_code",
             "submit_ts", "start_ts", "end_ts", "wall_time",
             "cpu_time")

summarised <- read_tsv(
  readLines(file("stdin", open = "r")),
  col_names = columns) %>%
separate(
  shards, c("shards", "expected"), sep = "/") %>%
type_convert(
  cols(shards    = col_integer(),
       expected  = col_integer(),
       attempts  = col_integer(),
       job_id    = col_character(),
       exit_code = col_integer()),
  na = "-") %>%
group_by(
  workflow, run_id, task) %>%
summarise(
  complete = sum(case_when(exit_code == 0 ~ 1), na.rm = TRUE),
  complete_pc = 100 * sum(case_when(exit_code == 0 ~ 1), na.rm = TRUE) / max(coalesce(expected, 1L)),
  cpu_mean = mean(case_when(exit_code == 0 ~ cpu_time), na.rm = TRUE),
  cpu_sd = sd(case_when(exit_code == 0 ~ cpu_time), na.rm = TRUE),

  pending = sum(case_when(status == "PEND" ~ 1), na.rm = TRUE),
  running = sum(case_when(status == "RUN" ~ 1), na.rm = TRUE),
  failed = sum(case_when(status == "EXIT" | exit_code != 0 ~ 1), na.rm = TRUE),
  other = sum(case_when(is.na(exit_code) & ! status %in% c("DONE", "EXIT", "RUN", "PEND") ~ 1), na.rm = TRUE)
)

# TODO Pretty-print headers to stderr
# TODO? Number formatting
cat(format_tsv(summarised, na = "-", col_names = FALSE, quote_escape = FALSE))
