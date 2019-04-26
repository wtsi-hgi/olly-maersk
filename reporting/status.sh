#!/usr/bin/env bash

# Cromwell Executions Status Report
# Christopher Harrison <ch12@sanger.ac.uk>

set -euo pipefail

readonly BINARY="$(readlink -fn "$0")"
readonly PROG_NAME="$(basename "${BINARY}")"

readonly TAB=$'\t'

declare EXECUTION_ROOT="${EXECUTION_ROOT-$(pwd)/cromwell-executions}"

usage() {
  cat <<-EOF
	Usage: ${PROG_NAME} WORKFLOW_NAME [RUN_ID_PREFIX...]
	
	Overview report on the status of Cromwell workflow executions, given by
	the WORKFLOW_NAME. The RUN_ID_PREFIX can be omitted to show every run
	for the given workflow, or specified one-or-more times for particular
	runs; it needn't be complete (i.e., it will only report on runs whose
	IDs match the given prefix).
	EOF
}

lfs_job_status() {
  # Return the status of an LSF job as a tab-delimited string of LSF
  # status, submit time, start time, finish time and execution host. A
  # dash is used for any fields where such information is not available,
  # including jobs which are not found. (Note that jobs that have ended
  # and dropped out of the LSF log rotation won't be found -- presuming
  # they existed at all -- their actual status may be available using
  # bhist, but this is costly and also subject to LSF's log rotation.)

  # n.b., This only works correctly for scalar jobs, but that's all
  # we're dealing with so it's totally fine.
  local job_id="$1"
  local not_found="-${TAB}-${TAB}-${TAB}-${TAB}-"

  local headers="stat submit_time start_time finish_time exec_host delimiter='${TAB}'"
  local status="$(bjobs -noheader -o "${headers}" "${job_id}" 2>/dev/null)"

  echo "${status:-${not_found}}"
}

# NOTES
# stdout.background contains the LSF job ID, if it's been submitted
# rc contains the exit code, if it's ended gracefully
# stdout or stdout.lsf contains CPU time in seconds

main() {
  if ! (( $# )); then
    usage
    exit 1
  fi

  local workflow_name="$1"

  shift
  local -a run_id_prefices=("${@-}")

  # TODO
  # Do something useful here...
}

main "$@"
