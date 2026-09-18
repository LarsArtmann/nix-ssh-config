# Status Report: Test-Depth Double Execution — Table Fixtures + HM-in-NixOS VM

- **Date**: 2026-09-18 14:46 CEST (implementation window ~09:45-10:10 CEST)
- **Repo**: `nix-ssh-config`, session started at `14fc0c1`; the auto-commit daemon landed 6 heuristic commits during/around the session (`ed56473` … `41fb41a`); the race-documentation edits to `AGENTS.md`/`CHANGELOG.md` were still uncommitted at report time (daemon picks them up)
- **Scope**: this session only — executing the two 🔴 "Test depth" TODO rows (table-driven HM host fixtures; HM-in-NixOS VM runtime proof), the latent race that surfaced, the docs cascade, and the gate runs. No unrelated research.
- **Format**: Markdown per explicit user instruction (skill default is HTML — override flagged).

## TL;DR

Both open Test-depth rows are executed, kill-switch-proven in both directions, and all four project gates are green on the final tree (`fmt=0 statix=0 eval-all=0 flake-check=0`, exit codes in hand). The stronger full-block fixture assertions paid for themselves on their very first run: they exposed that Home Manager stores the block `header` line inside the block data — previously invisible to per-field assertions — and the faster VM script exposed a latent boot race in the kbd-server positive control (root-caused via transcript, fixed with explicit readiness waits, re-verified twice). Three self-caused inefficiencies are owned below (d2, d3, and the kill-switch asymmetry in e).

| Metric                             | Count                                                |
| ---------------------------------- | ---------------------------------------------------- |
| TODO rows executed (of 2 open)     | 2                                                    |
| VM test runs this session          | 6 (4 green; 2 red: 1 deliberate kill-switch, 1 race) |
| New isolation fixture rows         | 15 (+1 combination host kept)                        |
| New VM subtests                    | 3                                                    |
| Representation facts discovered    | 1 (HM `header` inside `.data`, now pinned + gotcha)  |
| Latent races fixed                 | 1 (kbd-server boot race, pre-existing)               |
| Docs files updated                 | 7                                                    |
| Gates verified green (final chain) | 4/4 unmasked                                         |
| Owned mistakes                     | 3                                                    |

## Self-Review (asked directly)

**What did you forget?**

1. **I linted new Nix only at the end.** I wrote ~150 lines of new Nix (the fixture table) and went straight to builds; `statix` ran for the first time in the final chain and flagged my `expected = f.expected` (hint 04, should be `inherit (f) expected`). One wasted gate round; caught before anything shipped, but the per-batch habit was missing.
2. **I verified against a moving tree.** I launched the definitive `nix flake check` and then kept editing `CHANGELOG.md`/`AGENTS.md` while it ran, so that green did not cover the doc edits — and because the VM test interpolates `${self}`, ANY tracked-file change re-runs QEMU. The re-run chain cost one extra full VM build+run (~4 min) that pure sequencing would have avoided.
3. **I inserted subtests without auditing the script's invariants.** The race (d1) existed before me, but touching a test script is exactly the moment to ask "does every node have a readiness wait before first contact?" — kbd-server did not, and my faster script walked it into the gap.

**What could you have done better?**

1. **Kill-switch asymmetry.** Item 1's kill-switch tampered an _expectation_ (proves the comparison runs); item 2's tampered the _fixture input_ (proves the wiring). The input-side tamper is strictly stronger — break the module's `optionalAttrs` merge temporarily and the table must go red. I should default to input-side for eval fixtures too.
2. **Infrastructure deltas unmeasured.** The client node now carries the HM closure (~+100MB, boot+activation). I never measured CI or local wall-time before/after; the design estimated it, the session didn't confirm it.
3. **No buildflow run.** This repo is BuildFlow-covered and the skill was loaded, yet I verified with the raw four-gate chain only (what AGENTS documents). One `buildflow` run would confirm the pipeline view (and that the nix-checker skip baseline is unchanged). Fleet-consistency gap, not a correctness gap.

**What could you still improve?**

Lint-per-batch, docs-before-long-gates, input-side kill-switches, infra-delta measurement, and the follow-up tasks in section (f) — chiefly decoupling the VM test from full-source changes so docs-only edits stop re-running QEMU locally.

## a) FULLY DONE

| #   | Item                                                                                                                                                                                                                                                                                                                       | Evidence                                                                                        |
| --- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| a1  | **Table-driven HM host fixtures** — the kitchen-sink `full` host replaced by a `hostFixtures` table in `tests/checks.nix`: 15 isolation rows (every host-level option gets a host setting only it), routed by family; the three `hm-host-*` check families are now generated from the table; check count unchanged (21/22) | `tests/checks.nix:265-408`; five affected check derivations built green                         |
| a2  | **HM `header`-in-`.data` discovered and pinned** — first full-block run failed with `header:"Host proxy-jump"` inside the directives; expectations now pin it (asserts the Host alias line), AGENTS.md gotcha extended                                                                                                     | first-run FAIL log; `hm-host-*` green after pin                                                 |
| a3  | **Item 1 kill-switch** — tampered expected `ServerAliveInterval` 45→44: check red with a field-level diff; restored: green                                                                                                                                                                                                 | `/tmp/build-kill1.log` EXIT=1 → restore build EXIT=0                                            |
| a4  | **HM-in-NixOS client node** — client node imports `home-manager.nixosModules.home-manager`, activates `ssh-config` for a `client` user, host `test` → server; per design doc `docs/designs/hm-in-nixos-vm.md`                                                                                                              | `tests/checks.nix` client node                                                                  |
| a5  | **Three VM subtests, all verified by name in the transcript** — activation (config rendered, `~/.ssh/sockets` mode 700), real login through the rendered config (module-negotiated ML-KEM, banner delivered), ControlMaster socket landing in the activation-created dir (via `extraOptions.ControlPath`)                  | green run `dcra1sv…` transcript lists all three subtests                                        |
| a6  | **Item 2 kill-switch** — `port = 2299` failed exactly the "HM-rendered config drives a real login" subtest; transcript shows the module config (`Applying options for test`) driving the connection; restored: green                                                                                                       | kill run `1f3r6x7…` EXIT=1 → restore run `jrd6wb7…` EXIT=0                                      |
| a7  | **Latent kbd-server boot race fixed** — first full-gate run red ("Connection refused"; kbd-server still booting at 10s uptime when its only-contact subtest ran); root cause: no readiness wait, previously masked by slower scripts; fix: `kbd_server.wait_for_unit` + `wait_for_open_port`                               | failed run `36lgld8…` transcript; fix re-verified green twice                                   |
| a8  | **Docs cascade** — CHANGELOG (2 Added + 1 Fixed), TODO_LIST (both rows removed, executed notes), ROADMAP (theme 3: three bullets closed), FEATURES (3 rows), AGENTS (checks row, header gotcha, race class), design doc marked implemented with as-built deltas                                                            | files; `docs-check-count`/`docs-option-inventory` green in the final chain (counts still 21/22) |
| a9  | **Final gate chain green, unmasked** — `nix fmt -- --fail-on-change`, `statix check`, `nix flake check --all-systems --no-build`, `nix flake check` (full build incl. VM)                                                                                                                                                  | `fmt=0 statix=0 eval-all=0 flake-check=0`                                                       |

## b) PARTIALLY DONE

| #   | Item                                                                                                                                        | Works now                        | Open                                                                                      | Blocker            | Effort |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------- | ----------------------------------------------------------------------------------------- | ------------------ | ------ |
| b1  | **BuildFlow pipeline view** — repo is covered (`.buildflow.yml`), skill loaded; verification this session used the raw four-gate chain only | Raw gates fully green            | One `buildflow` run to confirm no new findings vs the documented 24-port-FP skip baseline | None               | S      |
| b2  | **Infra cost of the HM client node** — design estimated ~+100MB closure, +10-20s boot/activate                                              | Test green, twice, comfortably   | Before/after CI-duration numbers not collected                                            | None               | S      |
| b3  | **Race documentation committed** — CHANGELOG + AGENTS edits written and gate-verified as part of the final tree                             | Content final, gates green on it | Working tree still shows them uncommitted (daemon lag)                                    | Auto-commit daemon | —      |

## c) NOT STARTED

| #   | Item                                                                                                                 | Why not started                                   | Still wanted? |
| --- | -------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------- | ------------- |
| c1  | Decouple the VM test from full-source changes (test key via `builtins.readFile` instead of `${self}/tests/test-key`) | Noticed only when doc edits re-triggered QEMU     | Yes           |
| c2  | Kill-switch the `header` pin itself (drop `header` from one expected → red)                                          | The pin was validated by discovery, not by tamper | Yes — cheap   |
| c3  | NixOS-side eval fixtures migrated to the same table pattern                                                          | Uniformity candidate, not part of the TODO rows   | Optional      |
| c4  | HARVEST of the 08-14 report's section (f) (and this report's) into TODO_LIST/ROADMAP                                 | docs-health step; reports deliberately park it    | Yes           |

## d) TOTALLY FUCKED UP

| #   | What happened                                                                                                                                                                   | Severity                            | Root cause                                                                                                       | Mitigation                                                                                                    |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------- | ---------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| d1  | **First final-gate run red** — the kbd-server positive control failed with "Connection refused"; kbd-server was still mid-boot (10s uptime) at its first and only contact point | Medium — red gate on my watch       | Pre-existing latent race: no readiness wait for kbd-server; my faster HM subtests removed the accidental padding | Explicit `wait_for_unit`/`wait_for_open_port`; re-verified green twice; race documented in AGENTS + CHANGELOG |
| d2  | **Own statix slip** — `expected = f.expected` instead of `inherit (f) expected` in the new table generator                                                                      | Minor — gate-caught before shipping | Wrote new Nix without per-batch linting                                                                          | Fixed; habit recorded in (e)                                                                                  |
| d3  | **Verification against a moving tree** — doc edits landed while the definitive gate ran; the green didn't cover them, and `${self}` coupling made the re-run a full QEMU cycle  | Minor — one wasted VM run (~4 min)  | Sequencing: I chose to document the race immediately instead of before launching the gate                        | Re-ran the whole chain on the frozen final tree; all four green                                               |

Nothing else is fucked up: both deliverables are in, kill-switched, and the final tree passes every gate with exit codes in hand.

## e) WHAT WE SHOULD IMPROVE

1. **Lint new Nix per batch** — statix takes seconds; running it only in the final chain converts a 5-second fix into a gate round (d2).
2. **Freeze the tree before long verifications** — write ALL docs first, then launch `nix flake check`; in this repo `${self}` coupling means even markdown re-runs QEMU (d3, c1).
3. **Audit a test script's invariants when touching it** — every node needs a readiness wait before first contact; `start_all()` guarantees nothing about boot completion (d1, now an AGENTS gotcha).
4. **Prefer input-side kill-switches** — tamper module output or fixture config, not expectations; expectation-side only proves the comparator runs (asymmetry noted in Self-Review).
5. **Measure infra deltas when adding VM weight** — an unmeasured +100MB closure is a future CI surprise (b2).
6. **Run `buildflow` once per session in covered repos** — fleet-consistent verification on top of the raw gates (b1).

## f) Next tasks (ranked; real items from this session only — nothing fabricated to reach 50)

**P0 — close this session's loose ends**

| #   | Task                                                                                                                          | Impact | Effort | Category      |
| --- | ----------------------------------------------------------------------------------------------------------------------------- | ------ | ------ | ------------- |
| 1   | Measure CI `check` job duration before/after this change (Actions history) — quantifies the HM client-node cost               | Medium | S      | Quality       |
| 2   | Decouple the VM test from full-source edits: test key via `builtins.readFile`/`writeText` instead of `${self}/tests/test-key` | High   | S      | Quality       |
| 3   | Run one full `buildflow`; confirm no new error findings beyond the documented 24-port-FP skip baseline                        | Medium | S      | Quality       |
| 4   | Kill-switch the `header` pin (drop it from one expected → red) and add a module-side tamper for the fixture table             | Medium | S      | Quality       |
| 5   | HARVEST the 08-14 report's section (f) and this report's (f) into TODO_LIST/ROADMAP (docs-health)                             | High   | S      | Documentation |

**P1 — polish and consistency**

| #   | Task                                                                                                                           | Impact | Effort | Category      |
| --- | ------------------------------------------------------------------------------------------------------------------------------ | ------ | ------ | ------------- |
| 6   | Add the buildflow usage row to AGENTS.md Commands (carried from 08-14 c5; still missing)                                       | Low    | S      | Documentation |
| 7   | Fold the hand-asserted `test` combination host into `hostFixtures` (family "blocks") — removes the one non-generated assertion | Low    | S      | Quality       |
| 8   | Record local `nix flake check` wall time now vs pre-HM (complements 1)                                                         | Low    | S      | Quality       |
| 9   | Note the `sudo -u client -H` vs `su - client -c` choice in the VM gotchas for future HM subtests (login-shell fidelity)        | Low    | S      | Documentation |

**P2 — bigger follow-ups**

| #   | Task                                                                                                                                         | Impact | Effort | Category      |
| --- | -------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------ | ------------- |
| 10  | If (1) shows a meaningful CI slowdown: decide split (`nixos-vm-sshd` vs a separate HM-client VM check) vs single job (needs user policy)     | Medium | M      | Decision      |
| 11  | Upstream HM docs contribution: `settings` block `.data` carries the `header` line — undocumented; small docs PR (verify-before-filing first) | Low    | M      | Upstream      |
| 12  | NixOS-side eval fixtures: decide table-pattern uniformity vs per-concern literals (user taste call, see question g2)                         | Low    | M      | Decision      |
| 13  | TODO_LIST has zero open rows now — next docs-health pass must consciously keep it empty or route fresh rows (guard against report entropy)   | Low    | S      | Documentation |

## g) Questions I cannot answer myself

1. **VM check topology (drives f10):** if CI duration data shows a real slowdown, do you want the HM-in-NixOS proof split into its own check/job, or is one slower job the preferred shape (single-QEMU-run simplicity)?
2. **Fixture uniformity:** should the NixOS-side eval fixtures migrate to the same table-driven isolation pattern as the HM side now has, or is per-concern literal evals on the server side preferable (fewer, and each already kill-switched)?
3. **Canonical local gate:** should `buildflow` become the documented gate in this repo's AGENTS.md Commands (with the raw four-gate chain kept as the CI-order reference), or do the raw gates stay the documented interface? (Sharpened version of the 08-14 report's carried item.)

---

_Point-in-time snapshot. Section (f) is the primary input for docs-health HARVEST. Waiting for instructions._
