#!/usr/bin/env bash

# Cromwell Containerisation-Agnostic Submission Wrapper
# Christopher Harrison <ch12@sanger.ac.uk>

set -euo pipefail

readonly BINARY="$(readlink -fn "$0")"
readonly PROGNAME="$(basename "${BINARY}")"

stderr() {
  local message="$*"

  [[ -t 2 ]] && message="$(tput setaf 1)${message}$(tput sgr0)"
  >&2 echo "${message}"
}

usage() {
  cat <<-EOF
	Usage: ${PROGNAME} MODE [MODE OPTIONS...] -- COMMAND [COMMAND OPTIONS...]
	
	Note that the -- sentinal must be present, to delimit the MODE and the
	COMMAND (and its options, if any) you are intending to submit.
	
	Common Options (available to all MODEs):
	
	  --name NAME          The name to give a job
	  --group GROUP        The Fairshare group under which to run
	  --queue QUEUE        LSF queue in which to run [default: normal]
	  --cores CORES        The number of cores required [default: 1]
	  --memory MEMORY      The memory required, in MB [default: 1000]
	  --resources RES_REQ  Additional LSF resource requirements (optional)
	  --working DIRECTORY  The working directory [default: current]
	  --stdout FILE        Where to write the job's stdout stream
	  --stderr FILE        Where to write the job's stderr stream
	
	The following MODEs are available:
	EOF

  # Extract documentation from mode functions
  awk '
    BEGIN {
      in_mode = 0
    }

    /^mode_\w+\(\) {/ {
      print ""
      print gensub(/mode_(\w+)\(\) {/, "\\1:", 1)
      in_mode = 1
      next
    }

    in_mode && /^  #@/ {
      print gensub(/^  #@ ?/, "  ", 1)
    }

    in_mode && !/^  #/ {
      in_mode = 0
    }
  ' "${BINARY}"
}

mode_vanilla() {
  #@ Submit your job directly to an execution node on the LSF cluster
  if (( $# < 2 )); then
    stderr "Not enough options provided for submission!"
    usage
    exit 1
  fi

  local _opt
  local name
  local group
  local queue="normal"
  local -i cores=1
  local -i memory=1000
  local resource_request="span[hosts=1]"
  local working="$(pwd)"
  local stdout
  local stderr
  local -i bashify=1
  local -i found_command=0
  local -i empty_command=1
  local -a job_command

  while (( $# )); do
    if ! (( found_command )); then
      case "$1" in
        "--")
          # Found the sentinal
          found_command=1
          (( bashify )) && job_command+=("/usr/bin/env" "bash")
          ;;

        "--no-bashify")
          # Undocumented option that prevents the command being executed
          # as an argument to Bash, which we'd normally want because
          # Cromwell doesn't +x its scripts
          bashify=0
          ;;

        "--name" | "--group" | "--queue" | "--cores" | "--memory" | "--resources" | "--working" | "--stdout" | "--stderr")
          if (( $# < 2 )); then
            stderr "Invalid value provided to $1 option!"
            usage
            exit 1
          fi

          if [[ "$1" == "--resources" ]]; then
            # Append to resource request
            resource_request="${resource_request} $2"
          else
            _opt="${1:2}"          # Strip the -- prefix
            eval "${_opt}=\"$2\""  # Yeah, I went there...
          fi

          shift
          ;;

        *)
          stderr "Unrecognised option \"$1\"!"
          usage
          exit 1
          ;;
      esac
    else
      # Append to the job command
      empty_command=0
      job_command+=("$1")
    fi

    shift
  done

  if (( empty_command )) || [[ -z "${name+x}" ]] || [[ -z "${group+x}" ]] || [[ -z "${stdout+x}" ]] || [[ -z "${stderr+x}" ]]; then
    stderr "Incomplete options provided for submission!"
    usage
    exit 1
  fi

  resource_request="${resource_request} select[mem>${memory}] rusage[mem=${memory}]"

  bsub -J "${name}" \
       -G "${group}" \
       -q "${queue}" \
       -cwd "${working}" \
       -o "${stdout}" -e "${stderr}" \
       -n "${cores}" -M "${memory}" -R "${resource_request}" \
       "${job_command[@]}"
}

mode_singularity() {
  #@ Submit your job inside a Singularity container on the LSF cluster
  #@
  #@ Options:
  #@
  #@   CONTAINER                Singularity container identifier
  #@   --container-working DIR  Working directory within the container (optional)
  #@   --mount MOUNT            Mount point (optional)
  #@   --mounts FILE            File of mount points, one per line (optional)
  #@
  #@ The CONTAINER may be a local image, shub:// or docker:// URI.
  #@ Multiple MOUNTs may be specified, with or without a FILE of mount
  #@ points; the format of which is as those understood by Singularity.
  # n.b., This is just a special-case of the vanilla-LSF mode
  if (( $# < 3 )); then
    stderr "Not enough options provided for Singularity mode!"
    usage
    exit 1
  fi

  local _mount_point
  local -a lsf_args
  local -a singularity_args=(--contain)
  local -a job_command
  local -i found_command=0
  local -i empty_command=1

  # The first argument is always the container identifier
  local container="$1"
  shift

  while (( $# )); do
    if ! (( found_command )); then
      case "$1" in
        "--")
          # Found the sentinal
          found_command=1
          ;;

        "--container-working")
          [[ -z "${2+x}" ]] && break  # Check value exists
          singularity_args+=(--pwd "$2")
          shift
          ;;

        "--mount")
          [[ -z "${2+x}" ]] && break  # Check value exists
          singularity_args+=(--bind "$2")
          shift
          ;;

        "--mounts")
          [[ -z "${2+x}" ]] && break  # Check value exists

          while read -r _mount_point; do
            singularity_args+=(--bind "${_mount_point}")
          done < "$2"

          shift
          ;;

        *)
          # Anything not recognised is passed to LSF
          lsf_args+=("$1")
          ;;
      esac
    else
      # Append to the job command
      empty_command=0
      job_command+=("$1")
    fi

    shift
  done

  if (( empty_command )); then
    stderr "Incomplete options provided for submission!"
    usage
    exit 1
  fi

  mode_vanilla "${lsf_args[@]}" --no-bashify -- \
               singularity exec "${singularity_args[@]}" "${container}" \
                                /usr/bin/env bash "${job_command[@]}"
}

mode_docker() {
  #@ Submit your job inside a Docker container on the LSF cluster
  #@
  #@ Options:
  #@
  #@   CONTAINER                Docker container identifier
  #@   --container-working DIR  Working directory within the container (optional)
  #@   --mount MOUNT            Mount point (optional)
  #@   --mounts FILE            File of mount points, one per line (optional)
  #@
  #@ The CONTAINER may be a local image or one provided by DockerHub, or
  #@ some other recognised repository. Multiple MOUNTs may be specified,
  #@ with or without a FILE of mount points; the format of which is as
  #@ those understood by Docker.
  # n.b., This is just a special-case of the Singularity mode
  if (( $# < 3 )); then
    stderr "Not enough options provided for Docker mode!"
    usage
    exit 1
  fi

  local container="docker://$1"
  local -a args=("${@:2}")
  mode_singularity "${container}" "${args[@]}"
}

main() {
  if (( $# < 3 )); then
    stderr "Not enough options provided!"
    usage
    exit 1
  fi

  local mode="$1"
  if ! grep -Fq "mode_${mode}() {" "${BINARY}"; then
    stderr "No such mode \"${mode}\"!"
    usage
    exit 1
  fi

  local -a args=("${@:2}")
  "mode_${mode}" "${args[@]}"
}

main "$@"
