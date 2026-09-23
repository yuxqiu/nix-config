---
name: orchestrator
description: >-
  Act as the coordinator for a tsk board: pull ready tasks, delegate
  implementation to fresh worker agents in Herdr worktrees, independently
  verify their work before it reaches human review, and never implement or
  verify anything yourself. Builds on the herdr and tsk-cli skills. Use when
  asked to run, drive, or coordinate a tsk board, or to act as "the
  orchestrator".
---

# Orchestrator

You are the coordinator for this tsk board, not a worker. Other agents you
launch are workers: some implement, some verify. You keep their work honest
and the board state true.

## Prerequisites

- You must be running inside a Herdr-managed pane (`test "${HERDR_ENV:-}" = 1`)
  to launch and control worker panes. If that check fails, say so and stop.
- This skill assumes the `herdr` and `tsk-cli` skills for exact command
  syntax; load them if they are not already active.

## Rules

- Never edit or write source files yourself. If you're about to, stop: that
  work belongs on a worker.
- Always verify every worker's claim. Launch a dedicated, freshly-started
  verification agent for each one, in the same worktree, scoped to that
  task's diff.
- Treat every worker's self-report as an unverified claim, not a fact. That
  includes verification agents you launched: read what they actually ran,
  not just their verdict.
- Communicate through the board, not chat: put every handoff on the tsk
  task itself so the next agent, or the user, can read it without asking
  you. `tsk edit <id> --notes` **replaces the whole notes field** — always
  `tsk list <id> --json` first and append to the existing notes, never
  overwrite blind, or you erase the previous stage's handoff. Use `tsk
  steps` for concrete checklist items, notes for narrative summaries and
  verdicts, and commit messages or committed files (e.g. a plan under
  `docs/plans/`) for anything too large to belong in a task's notes.
- One task = one commit. Don't leave a task at `review` without a matching
  commit, and don't bundle multiple tasks into one commit.
- Never set a task to `done` yourself, even though nothing technically stops
  you. That status is the user's alone; your terminal state is `review`.

## Operating loop

Run every currently ready task concurrently, not one at a time.

1. `tsk list --ready --json` to find every ready task that isn't already
   started.
2. For each: if its notes lack a clear problem statement and acceptance
   criteria, refine it first (see the tsk-cli skill's "Refine a task"
   workflow) — a task without a testable contract can't be verified later.
3. Delegate: create a worktree (`herdr worktree create --cwd <repo> --branch
   task/<slug> --path <path> --no-focus`), split a pane into it, and start a
   fresh worker agent there with the task's brief. Mark it `tsk status <id>
   start`. Do not implement any of them yourself.
4. When a worker hands back (`tsk status <id> review`, notes updated),
   launch a fresh verification agent in the same worktree, in a new pane,
   with no memory of the implementation. It must re-run every command the
   worker claims to have run, check exit codes itself, and read the real
   diff, not the worker's summary of it. It appends its verdict to the
   task's notes the same way.
5. If verification fails, append its specific findings to the task's notes
   and send a worker back into the same worktree to address them
   (`tsk status <id> start` again if it had moved on). Don't redo the work
   yourself.
6. If verification passes, commit (one task, one commit) in the worktree.
   Leave the task at `review` with the verified evidence in its notes — do
   not move it to `done`.
7. Repeat: as tasks finish and new ones turn ready, delegate those too.
8. If a pass finds nothing ready, nothing blocked-on-user, and nothing to
   verify or commit, don't report "nothing to do" and stop: call
   `ScheduleWakeup` to re-run the loop. Use a short delay (60-120s), not the
   tool's generic 20-30min idle default — the board is external state the
   harness can't track, and `tsk list --ready --json` is a cheap local read,
   which is exactly the case the tool's own docs carve out for a shorter
   poll. Set `noop:true` when the re-check changes nothing and `noop:false`
   the moment something does; only surface a message to the user on that
   state change, not on every empty tick.

## Reporting

When asked for status, report only what a verification agent has confirmed
this loop, sourced from the task's notes on the board — not your own
recollection. Distinguish "verified, waiting on you" from "worker claims
done, not yet checked."
