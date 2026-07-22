# Pagu product-lead handoff (edge-doc)

Role-continuity doc for a FRESH session inheriting the pagu product-lead role
after context rot. This session is anchored in `/srv/share/projects/pagu-box`
(cwd + memory key), but the ACTIVE WORK TREE is the consolidated **pagu** repo
at **`/srv/share/projects/pagu`** — do your work there. Full detailed history:
`~/.claude/projects/-srv-share-projects-pagu/memory/pagu-product-lead.md` (read
it). This is the compact edge.

_Written 2026-07-22. (A duplicate copy exists at pagu/docs/handoff.md; THIS
pagu-box path is the canonical one the fresh session should read.)_

## Your role & governance

You are **pagu product lead / advisor under OWNER-LED governance**. The
operator (Philip) directs the roadmap; you advise (own *correctness*) and
execute slices **on the operator's explicit request** — do NOT self-start
roadmap work. A "manager" monitors status/blockers/handoffs only and does not
direct pagu roadmap without an explicit operator request. The **web-relay** is
a separate adjacent lane, currently **PAUSED** — not pagu's concern.

## Where we are

pagu pivoted to **box (PEP) + gate (PA)**; the integrated harness is archived
(ADR-0004/0005). The thesis is **built**:

- Slices 1–9: box, gate (escalation loop closed), category profiles, verified
  gate-owned conversion recipe, harness inference.
- Slice 10: homelab flake-input migration LANDED (`98508f9` on homelab
  origin/main). **`github:phibkro/pagu` is now PUBLIC.**
- Slice 11 spike (`991429d`): seccomp user-notif denial capture **proven**
  (lead-verified). SoT: `box/docs/notes/seccomp-user-notif-spike.md`.
- Slice 12 (`d694282`, pushed): opt-in `--observe-denials`, deny-list-driven
  from compiled `fs.deny` (SSoT), versioned profile-bound denial events,
  off-by-default. Lead-verified.

## Current edge (do THIS)

**Slice 13 (fresh boxed+gated launch) just landed — the engineer reports
`done`. GATE IT, then report.** Slice 13 = fresh (not resume-only) boxed+gated
agent launch + race-safe session discovery (diff the pre/post session set) so
relaunch-on-widen still resumes the discovered id with context. It is the pagu
unblock for **fleet-deployment** (Herdr-launch-through-box, retiring the
auto-approver's detect-and-deny weakness). Brief: `SLICE-13-BRIEF.md` in the
pagu repo root.

Evidence already in the tree: `src/gate/resume.ts` has `freshCommand()`,
gate-session evidence is v2 with `initial:"fresh"|"resume"`, `relaunch.ts` has
discovery. VERIFY the committed content — do NOT trust this summary or the
engineer's; gate on the artifact.

## Next action

1. Poll the engineer: `herdr pane get wA:p2` (it is a HERDR PANE, not a
   subagent; NO auto-notify — poll on demand). Read its Slice 13 report.
2. Gate the committed Slice 13: `cd /srv/share/projects/pagu`; check the commit
   sha + trailer (`GPT 5.6 Sol via Codex`) + `docs/decisions` untouched;
   `deno task ci`; `nix build .#pagu .#pagu-box`; then run the **lead-verify**
   yourself (fresh codex boxed+gated → a NEW id discovered by diff → drive a
   widen → confirm relaunch resumes that id with context preserved). The
   engineer CANNOT run real seccomp/box journeys (it's nested) — that's YOUR
   job, outside a box. The engineer hands you the exact lead-verify command.
3. `git push origin main`, then **hand the operator the exact Herdr
   default-launch wiring** to complete fleet-deployment (the Herdr/homelab
   layer is operator-owned; Herdr is upstream Rust → a launch-wrapper config,
   not source).

## Operator constraints (in force)

- **No PRs; merge locally into main; the gate = verified intended behavior,
  NOT a review step.**
- **Commit email MUST be `71797726+phibkro@users.noreply.github.com`** — the
  gmail address trips GitHub GH007 push protection.
- Engineer commit trailer MUST be `Co-Authored-By: GPT 5.6 Sol via Codex`
  (once mis-attributed to a Claude model — check before push).
- `docs/decisions/` = lead's pen; `src/` = engineer's. Commit by pathspec on
  the shared tree, never a bare `git commit` (sweeps the engineer's WIP).
- Briefs go as `SLICE-N-BRIEF.md` FILES in the pagu repo root (long pane-run
  text gets swallowed by the codex TUI on startup).

## Gotchas

- **Homelab is NOT rebuilt** — Slice 10 pushed but not deployed. Do NOT depend
  on the new flake input; build fresh pagu binaries
  (`nix build .#pagu .#pagu-box --no-link --print-out-paths`) and use those
  store paths, never the system `agent-dispatch`/`pagu-box`.
- The engineer runs gate-owned inside its OWN worker box → real seccomp/box/
  auth journeys fail nested → it unit-tests + hands you the lead-verify
  command; you run the real journey outside a box. Same seam every slice.
- **`validate` profile is PARKED** on pagu local branch `slice-validate`
  (web-relay paused). Known gap: outside-`$PWD` writes succeed ephemerally (box
  creates writable intermediate bind dirs) — no host persistence, but not the
  strict `nonzero` the relay wanted.
- Piped exit codes lie (`cmd | head` returns head's status) — verify box exit
  codes UNPIPED.
- Fleet conversions HELD: convert a live session only on an explicit
  per-session operator go-signal; `idle`/`done` ≠ safe to recycle (a session
  can be `done` with a directive queued).
- VERIFY ARTIFACTS ON DISK, not summaries — this very handoff was first written
  to the wrong repo path and "reported done"; the artifact check caught it.

## Refs

- pagu main = `d694282` + the Slice 13 commit (verify). Parked: pagu branch
  `slice-validate`. This session's cwd = `/srv/share/projects/pagu-box`
  (archived local repo); do work in `/srv/share/projects/pagu`.
