# LSF with Singularity Configuration for Cromwell

This provides the configuration and shims required to run jobs under
[Cromwell](https://cromwell.readthedocs.io/en/stable/), using LSF as an
executor, with the option of running jobs containerised in Singularity
or Docker containers. It "massages" Cromwell's assumptions about Docker,
such that prebaked Dockerised workflows should work without change.

**TODO**

- [X] Containerisation-agnostic wrapper script
- [ ] Cromwell configuration
