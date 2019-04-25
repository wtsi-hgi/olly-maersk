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
