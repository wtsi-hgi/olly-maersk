#!/usr/bin/env bash

# Kill LSF-Zombified Cromwell Workflow Tasks
# Christopher Harrison <ch12@sanger.ac.uk>
# Adapted from https://gist.github.com/delocalizer/6b4d97158044e1331f3c4393c9e05586

# Copyright (c) 2019 Genomics Research Limited
# Distributed under the GPLv3, or later

set -euo pipefail

declare PROVIDER="${PROVIDER-ContainerisedLSF}"

get_running_workflows() {
  # Return a list of running workflow IDs
  local api_base="$1"

  curl -s "${api_base}/query?status=Running" \
  | jq -r ".results[].id"
}

get_workflow_tasks() {
  # Return a workflow's presumably-running task list, with their job ID
  # and call root directory (tab-delimited)
  local api_base="$1"
  local workflow_id="$2"

  curl -s "${api_base}/${workflow_id}/metadata?expandSubWorkflows=true" \
  | jq -r "
    .calls[][]
    | select(.backend == \"${PROVIDER}\" and .returnCode == null and .jobId \!= null)
    | (.jobId + \"\t\" + .callRoot)"
}

is_running() {
  # Is an LSF job currently running
  local job_id="$1"
  bjobs "${job_id}" | grep -Eq "PEND|RUN"
}

get_exit_code() {
  # Attempt to get the exit code of an LSF job (or 1, if not found)
  local job_id="$1"

  bjobs -l "${job_id}" \
  | grep -Po '(<?=Exited with exit code )\d+' \
  || echo "1"
}

main() {
  local api_base="$1"
  local workflow_id
  local job_id
  local job_dir
  local job_rc

  while read -r workflow_id; do
    while read -r job_id job_dir; do
      >&2 echo -n "Checking status of job ${job_id}, submitted as part of workflow ${workflow_id}... "

      # FIXME There's a potential race condition here (e.g., when the
      # job has completed, but the rc file has yet to be written)
      job_rc="${job_dir}/execution/rc"
      if ! is_running "${job_id}" && ! [[ -e "${job_rc}" ]]; then
        # Forcibly coerce Cromwell into recognising a zombie job
        >&2 echo "Zombified"
        get_exit_code "${job_id}" > "${job_rc}"

      else
        # Job is not a zombie
        >&2 echo "OK"
      fi
    done < <(get_workflow_tasks "${api_base}" "${workflow_id}")
  done < <(get_running_workflows "${api_base}")
}

main "$@"
