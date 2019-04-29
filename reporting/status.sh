#!/usr/bin/env bash

# Cromwell Executions Status Report
# Christopher Harrison <ch12@sanger.ac.uk>

set -euo pipefail

readonly BINARY="$(readlink -fn "$0")"
readonly PROG_NAME="$(basename "${BINARY}")"

readonly TAB=$'\t'
readonly NA="-"

declare EXECUTION_ROOT="${EXECUTION_ROOT-$(pwd)/cromwell-executions}"

stderr() {
  local message="$*"

  [[ -t 2 ]] && message="$(tput setaf 1)${message}$(tput sgr0)"
  >&2 echo "${message}"
}

usage() {
  cat <<-EOF
	Usage: ${PROG_NAME} WORKFLOW_NAME [ latest | all | RUN_ID_PREFIX... ]
	
	Overview report on the status of Cromwell workflow executions, given by
	the WORKFLOW_NAME. The remaining arguments allow you to specify the
	particular runs; by default, the latest is shown (although you can be
	explicit about this by using "latest"); alternatively, to show
	everything, use "all"; finally, for arbitrary subsets, you can provide
	one-or-more run ID prefixes (i.e., the script will match runs whose IDs
	match the given prefixes).
	EOF
}

get_children() {
  # Return the list of top-level directories in a given directory,
  # sorted by modification date (either ascending or descending),
  # matching the glob(s) provided (of which, there must be at least one)
  local directory="$1"
  local order="n$([[ "$2" == "desc" ]] && echo "r")"
  local -a globs

  shift 2
  while (( $# )); do
    globs+=("-name" "$1")
    shift
    (( $# > 0 )) && globs+=("-o")
  done

  find "${directory}" \
       -mindepth 1 -maxdepth 1 -type d \
       \( "${globs[@]}" \) \
       -exec stat -c "%Y${TAB}%n" {} \; \
  | sort -t"${TAB}" -k1"${order}",1 \
  | cut -f2 \
  | xargs -n1 basename
}

prepend() {
  # Prepend stdout with additional columns
  local columns="$(IFS="${TAB}"; echo "$*")"
  awk -v C="${columns}" 'BEGIN { FS = OFS = "\t" } { print C, $0 }'
}

lfs_job_status() {
  # Return the status of an LSF job as a tab-delimited string of LSF
  # status, submit time, start time and finish time. A dash is used for
  # any fields where such information is not available, including jobs
  # which are not found. (Note that jobs that have ended and dropped out
  # of the LSF log rotation won't be found -- presuming they existed at
  # all -- their actual status may be available using bhist, but this is
  # costly and also subject to LSF's log rotation.)

  # NOTES
  # * This only works correctly for scalar jobs, but that's all we're
  #   dealing with so it's totally fine.
  # * We don't get CPU time this way because we extract it from our job
  #   log, which is not subject to LSF's log rotation.
  local job_id="$1"
  local not_found="-${TAB}-${TAB}-${TAB}-"

  local headers="stat submit_time start_time finish_time delimiter='${TAB}'"
  local status="$(bjobs -noheader -o "${headers}" "${job_id}" 2>/dev/null)"

  echo "${status:-${not_found}}"
}

report_job() {
  # TODO
  local exec_dir="$1"
  echo "${exec_dir}"

  # NOTES
  # stdout.background contains the LSF job ID, if it's been submitted
  # rc contains the exit code, if it's ended gracefully
  # stdout or stdout.lsf contains CPU time in seconds
}

report_shard() {
  # Report on the specified shard
  # n.b., Scalar jobs still come through here, with a shard ID of "-"
  local base_dir="$1"
  local shard="$2"

  local shard_dir="${base_dir}"
  [[ "${shard}" != "${NA}" ]] && shard_dir="${shard_dir}/shard-${shard}"

  local -i attempts=$(( $(get_children "${shard_dir}" asc "attempt-*" | wc -l) + 1 ))
  local attempt_dir="$( (( attempts > 1 )) && echo "attempt-${attempts}/")"

  local exec_dir="${shard_dir}/${attempt_dir}execution"
  report_job "${exec_dir}" | prepend "${shard}" "${attempts}"
}

report() {
  # Interrogate the Cromwell executions directory structure to glean the
  # status of a given workflow's run
  local workflow_name="$1"
  local run_id="$2"
  local base_dir="${EXECUTION_ROOT}/${workflow_name}/${run_id}"

  local task_name
  local shard_id
  while read -r task_name; do
    while read -r shard_id; do
      report_shard "${base_dir}/${task_name}" "${shard_id}"
    done < <(
      get_children "${base_dir}/${task_name}" asc "shard-*" \
      | grep -Po '(?<=shard-)\d+' \
      || echo "${NA}"
    ) \
    | prepend "${task_name#call-}"
  done < <(get_children "${base_dir}" asc "call-*") \
  | prepend "${workflow_name}" "${run_id}"
}

main() {
  if ! (( $# )); then
    usage
    exit 1
  fi

  local workflow_name="$1"
  local workflow_dir="${EXECUTION_ROOT}/${workflow_name}"
  if ! [[ -d "${workflow_dir}" ]]; then
    stderr "No such workflow!"
    usage
    exit 1
  fi

  local latest_id="$(get_children "${workflow_dir}" desc "*" | head -1)"

  local -a run_id_globs

  shift
  while (( $# )); do
    case "$1" in
      "latest") run_id_globs+=("${latest_id}");;
      "all")    run_id_globs+=("*");;
      *)        run_id_globs+=("${1}*");;
    esac
    shift
  done

  # Echo headers to stderr if we're not piping the output
  if [[ -t 1 ]] && [[ -t 2 ]]; then
    (cat | paste -sd "${TAB}" -) >&2 <<-EOF
		Workflow
		Run
		Task
		Shard
		Attempts
		Job ID
		Status
		Exit Code
		Submission Time
		Start Time
		Finish Time
		CPU Time
		EOF
  fi

  local run_id
  while read -r run_id; do
    # Generate report for each matching run ID
    report "${workflow_name}" "${run_id}"
  done < <(get_children "${workflow_dir}" desc "${run_id_globs[@]-${latest_id-*}}") \
  | tee >((( $(wc -l) == 0 )) && { stderr "No runs found!"; exit 1; })
}

main "$@"
