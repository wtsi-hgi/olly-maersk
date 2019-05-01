#!/usr/bin/env Rscript

# Cromwell Executions Status Summariser
# Christopher Harrison <ch12@sanger.ac.uk>

if (!all(c("readr", "tidyr", "dplyr") %in% rownames(installed.packages()))) {
  # Bailout if packages aren't installed
  cat("tidyverse packages not found!\n", file = stderr())
  quit(status = 1)
}

# FIXME? Is there a better way to suppress R's verbosity
suppressMessages(require(readr))
suppressMessages(require(tidyr))
suppressMessages(require(dplyr))

columns <- c("workflow", "run_id", "task", "shards",
             "attempts", "job_id", "status", "exit_code",
             "submit_ts", "start_ts", "end_ts", "wall_time",
             "cpu_time")

stdin <- file("stdin", open = "r")
on.exit(close(stdin))

summarised <- read_tsv(
  readLines(stdin),
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
  complete_pc = 100 * complete / max(coalesce(expected, n())),
  cpu_mean = mean(case_when(exit_code == 0 ~ cpu_time), na.rm = TRUE),
  cpu_sd = sd(case_when(exit_code == 0 ~ cpu_time), na.rm = TRUE),

  pending = sum(case_when(status == "PEND" ~ 1), na.rm = TRUE),
  running = sum(case_when(status == "RUN" ~ 1), na.rm = TRUE),
  failed = sum(case_when(status == "EXIT" | exit_code != 0 ~ 1), na.rm = TRUE),
  other = sum(case_when(is.na(exit_code) & ! status %in% c("DONE", "EXIT", "RUN", "PEND") ~ 1), na.rm = TRUE)
) %>%
mutate(
  # Nicer formatting for completed shards and CPU time
  complete = sprintf("%d (%.1f%%)", complete, complete_pc),
  cpu_time = if_else(is.na(cpu_mean),
               NA_character_,
               sprintf("%.1f%s min", cpu_mean / 60,
                                     if_else(is.na(cpu_sd), "", sprintf(" +/- %.1f", cpu_sd / 60))))
) %>%
select(
  workflow, run_id, task, complete, cpu_time, pending, running, failed, other)


if (isatty(stdout()) & isatty(stderr())) {
  # Write headers to stderr if we're outputting to a terminal
  output_headers <- c("Workflow", "Run ID", "Task", "Complete",
                      "CPU Time", "Pending", "Running", "Failed",
                      "Other")

  cat(c(output_headers, "\n"), sep = "\t", file = stderr())
}

# Final output
cat(format_tsv(summarised, na = "-", col_names = FALSE, quote_escape = FALSE))
