# Tau-Argus Engine: Agent Rules

## Branching

`master` is the only long-lived branch. Never commit directly to
`master`: work on a short-lived feature branch (`<type>/<short-topic>`),
open a PR, merge it, delete the branch. Exception: submodule commits
(core, csp, hitas, crp, rounder) are pushed directly as part of the
engine change set; the parent's PR is the review unit, and the gitlink
pin needs the submodule commit already on the remote.

## Commits

Conventional Commits: lowercase type, optional scope, imperative
subject. No `Co-authored-by` trailer. Never stage build artifacts
(`build/`, `*.so`, `*.dylib`).

## Solver

Pure HiGHS (`<highs/interfaces/highs_c_api.h>`). No CPLEX, XPRESS or
legacy SCIP. The HiGHS version is pinned in `engine/HiGHS-VERSION`.

## More rules

Build commands, verification, the release procedure and the
documentation style live in the tauargus-orchestration repo: `AGENTS.md`
and the `release` skill.
