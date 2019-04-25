#!/usr/bin/env bash

# Cromwell Executions Status Report
# Christopher Harrison <ch12@sanger.ac.uk>

set -euo pipefail

readonly BINARY="$(readlink -fn "$0")"
readonly PROG_NAME="$(basename "${BINARY}")"

declare EXECUTION_ROOT="${EXECUTION_ROOT-$(pwd)/cromwell-executions}"

usage() {
  cat <<-EOF
	Usage: ${PROG_NAME} [WORKFLOW_ID_PREFIX...]
	
	Overview report on the status of Cromwell executions, given by the
	optional WORKFLOW_ID_PREFIX. Note that this can be omitted, to show the
	status of all workflow executions; needn't be complete, to only report
	on workflows whose IDs match the given prefix; and may be specified
	multiple times.
	EOF
}

lfs_job_status() {
  # Return the status of an LSF job (or NOTFOUND if not found)
  # n.b., NOTFOUND jobs may be because they've ended and dropped out of
  # the LSF log rotation (either that or they never existed in the first
  # place); their actual status may therefore be available using bhist,
  # but this is costly and also subject to LSF's log rotation.
  # n.b., This only works correctly for scalar jobs, but that's all
  # we're dealing with so it's totally fine.
  local job_id="$1"
  local status="$(bjobs -noheader -o "stat" "${job_id}" 2>/dev/null)"

  echo "${status:-NOTFOUND}"
}

main() {
  local -a workflow_id_prefices=()

  while (( $# )); do
    case "$1" in
      "-h" | "--help")
        usage
        exit
        ;;

      *)
        workflow_id_prefices+=("$1")
        ;;
    esac

    shift
  done

  # TODO
  # Do something useful here...
}

main "$@"
