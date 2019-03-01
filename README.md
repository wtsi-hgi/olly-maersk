# Olly Maersk

**Containerisation-agnostic LSF provider for Cromwell**

This provides the configuration and shims required to run jobs under
[Cromwell](https://cromwell.readthedocs.io/en/stable/), using LSF as an
executor, with the option of running jobs containerised in Singularity
or Docker containers. It "massages" Cromwell's assumptions about Docker,
such that prebaked Dockerised workflows should work without change.

## LSF Runtime Attributes

The following runtime attributes influence how a job is submitted to
LSF; they must all be specified, either explicitly or through their
default value:

| Attribute    | Default  | Usage                                           |
| :----------- | :------- | :---------------------------------------------- |
| `lsf_group`  |          | The Fairshare group under which to run the task |
| `lsf_queue`  | `normal` | The LSF queue in which to run the task          |
| `lsf_cores`  | 1        | The number of CPU cores required                |
| `lsf_memory` | 1000     | The amount of memory (in MB) required           |

These can be specified within a workflow task itself, or injected as
`default_runtime_attributes`.

## Non-Containerised Workflows

Tasks that do not define containers for their operation will be
submitted to run directly on an execution node of the LSF cluster.

## Singularity Workflows

*EXPERIMENTAL*

Tasks that define a `singularity` runtime value, specifically of the
fully qualified Singularity image identifier in which the task should
run, will be submitted to LSF as jobs, with the appropriate directories
bind mounted. The output of the task will be written within the
container, but the mounting will ensure it is preserved on the host.

## Docker Workflows

*EXPERIMENTAL*

Tasks that define a `docker` runtime value, specifically of the
container image in which the task should run, will be submitted to LSF
as jobs, with the appropriate directories bind mounted. The output of
the task will be written within the container, but the mounting will
ensure it is preserved on the host.

## To Do...

- [ ] Better management around Cromwell's assumptions about Docker
      submissions.
- [ ] User-defined mount points for containers.
- [ ] Better (i.e., "less hacky") support for Singularity submissions.
