# Session Report: fastfetch login greeting (feature + brutal self-review)

| | |
|---|---|
| **Date** | 2026-09-21 15:45 CEST |
| **Scope** | This session only: `fastfetchOnLogin` feature, end to end |
| **Branch / HEAD** | `master` @ `cfe7024` (6 auto-commits today, `08ef4d6..cfe7024`, tree clean) |
| **Gate state at writing** | **All green**: `nix fmt -- --fail-on-change`, `statix check`, `nix flake check --all-systems --no-build`, full `nix flake check` (VM included, exit 0) |
| **Verdict** | Feature shipped, proven, documented. No open breakage. 3 process failures cost ~3 avoidable VM/eval cycles; 1 shipped doc claim was mechanically imprecise (fish path), now verified |

---

## 0) Brutal self-review — direct answers first

**What did you forget?**

1. **FEATURES.md VM-test row was not updated** — it still describes the VM test without the fastfetch subtests. The server feature row and the counts row were updated; the VM row (line ~62) was not. Two of three FEATURES touchpoints done ≠ done.
2. **TODO_LIST.md was not touched** — the follow-ups (pty stall root-cause, fish default-path doc fix, README boundary note) exist only in this report. Per the repo's own convention, bounded follow-ups belong in `TODO_LIST.md`; without HARVEST they die in this timestamped file.
3. **README never states the boundary**: the greeting only exists on hosts running this NixOS module. A user reading the README could assume any server they ssh to greets them. There is no client-side mechanism (documented decision missing entirely).
4. **The fish claim shipped unverified.** Option description, README, AGENTS.md and CHANGELOG all said "fish (babelfish-translated)". I wrote that from reading nixpkgs source and never built the translation — the exact failure mode this repo's `verify-external-claims` discipline exists for. (Verified at 15:50 today, *after* shipping: babelfish builds valid fish. But default fish configs use the `foreign-env` shim, not babelfish — so the shipped wording was mechanically wrong even though the feature works. Details in (d).)
5. **No post-change doc sweep against the checklist item "grep the docs for the old claim"** — I did update the counts everywhere, but did not re-grep FEATURES/AGENTS/README *after* the last edits to catch the VM row miss above.

**What is something stupid that we do anyway?**

- Six places now describe the same guard semantics (option description, code comment, AGENTS gotcha, README bullet, FEATURES row, CHANGELOG entry). `docs-option-inventory` guards option *names*, not prose semantics — this is a slow-drift split brain waiting to happen.
- Kill-switch discipline was applied to the eval check *after* the first green run, and to the VM only *accidentally* red-first. The repo's own rule is "every content assertion was once deliberately broken" — the *order* (red before green) is what makes it cheap, and I did not follow that order deliberately.

**Did you lie to the user?** No. One mechanically imprecise statement was made ("fish (babelfish-translated)") — feature-true, mechanism-imprecise; corrected and disclosed here.

**Ghost systems?** None created. Every line added is wired: option → `environment.loginShellInit` → eval check → VM subtest → docs. Nothing removed.

**Scope creep?** Resisted: no fastfetch-install option, no theming/preset options, no client-side hacks. The "IF it's already installed" contract was honored exactly.

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| 1 | `services.ssh-server.fastfetchOnLogin` option (bool, default `true`) with full semantics doc — `modules/nixos/ssh.nix:167-183` | In commit range `08ef4d6..cfe7024`; eval-verified on/off states |
| 2 | The greeting hook in `environment.loginShellInit` (POSIX sh, guards: `SSH_CONNECTION` + `SSH_TTY` + `command -v fastfetch` + once-per-session `SSH_FASTFETCH_SHOWN` marker) | Rendered hook eval-dumped and `sh -n` syntax-checked; `nixos-fastfetch-login` check green |
| 3 | Mechanism verification **before** design freeze: NixOS `/etc/profile` does NOT source `/etc/profile.d` (first design would have been inert); `environment.loginShellInit` is the consumed hook for bash (`/etc/profile`), zsh (`/etc/zprofile`), fish | nixpkgs source inspection (`shells-environment.nix`, `bash.nix`, `zsh.nix`, `fish.nix`) + generated-`/etc/profile` eval dumps |
| 4 | New eval fixture `nixosFastfetchOffEval` + eval check `nixos-fastfetch-login` (4 assertions: default, wiring, all 4 guards present, opt-out removes hook entirely) + new row in `nixos-disabled-noop` | Green in full `nix flake check`; check counts now 22/system (23 on Linux), `docs-check-count` green |
| 5 | VM runtime proof: greeting fires through a real sshd session into a real login shell (`bash -lc`, sshd-set `SSH_CONNECTION`, injected `SSH_TTY`); silent for non-interactive ssh commands and local non-SSH login shells; `pkgs.fastfetch` installed on server node only | Full `nix flake check` exit 0 (VM green) |
| 6 | Kill-switch proofs, both layers: VM subtest fails with *exactly* "fastfetch did not greet the login" when the guard is sabotaged; eval check trips **all 4 rows** with precise expected/got diffs when the default is flipped | `/tmp/vm-red2.log` transcript; `nix build .#checks.x86_64-linux.nixos-fastfetch-login` failure diff |
| 7 | Docs updated: README (option table row + Server Hardening bullet), FEATURES (new server feature row, counts 21→22 / 22→23), CHANGELOG (Unreleased entry), AGENTS.md (counts + new "NixOS `/etc/profile` never sources `/etc/profile.d`" gotcha incl. the VM proof trick) | `docs-option-inventory` + `docs-check-count` green = tables and counts machine-verified against the modules |
| 8 | fish/babelfish verification (late, but done this session): babelfish translation of the hook **builds** and produces valid, semantically-equivalent fish (`nix-store -r` on the translation drv) | Output inspected: `if [ -z ... ] && ... ; set -gx; fastfetch; end` |
| 9 | All four gates green at close of session; working tree clean (auto-daemon committed everything) | `nix fmt -- --fail-on-change`, `statix check`, `nix flake check --all-systems --no-build`, full `nix flake check` — all exit 0 |

## b) PARTIALLY DONE

| # | Item | Works now | Remaining | Blocker | Effort |
|---|------|-----------|-----------|---------|--------|
| 1 | Runtime proof of the *interactive* (pty) path | The hook is proven through a real authenticated sshd session with sshd-set `SSH_CONNECTION`; `SSH_TTY` is injected (it is exactly the marker sshd sets for TTY sessions) | A genuinely pty-driven interactive session is never exercised end-to-end | nixos test harness: `ssh -tt` sessions stall (see d-2); not a module defect | M |
| 2 | Multi-shell coverage | bash: runtime-proven. zsh: mechanism-verified from nixpkgs source (`/etc/zprofile`). fish: translation verified today + foreign-env path sources the same POSIX text | No VM node runs zsh/fish as login shell — their runtime path is proof-by-construction, not proof-by-execution | None; a VM node per shell is straightforward but adds runtime | M |
| 3 | Scope documentation | README documents the option, the default-on behavior, the install guard, the opt-out | Missing: "only hosts running this module greet you; nothing client-side exists for unmanaged hosts" + a "what you'll see / how to activate (install fastfetch)" user-facing note | None | S |
| 4 | FEATURES.md completeness | Server feature row + counts row updated | VM-test row (line ~62) does not mention the fastfetch subtests | None | S |
| 5 | Root-cause of the `-tt` stall | Workaround fully documented (code comment + AGENTS gotcha) | Actual root cause of `ssh -tt host 'bash -lc true'` never exiting under the test driver is **unknown** (two runs, two failure modes: lost exit-status, then a ~900s hang with the remote shell still alive) | Needs a dedicated isolation session; possibly an upstream nixos test driver issue | M–L |
| 6 | Guard-semantics single-source-of-truth | Semantics are consistent *today* across 6 locations | Nothing enforces prose consistency; docs guards only cover option names/counts | None | M |

## c) NOT STARTED

| # | Item | Why not started | Still wanted? |
|---|------|-----------------|---------------|
| 1 | HARVEST this report's (f) into `TODO_LIST.md` / `ROADMAP.md` | Report was the deliverable; awaiting your instructions | Yes — without it, (f) is entombed here |
| 2 | Release cut: date the CHANGELOG, tag `v0.1.5` | Your call — more work may go into Unreleased first | Yes, needed before consumers can pin the feature |
| 3 | Consumer bumps: `nix-international-telephony` (on v0.1.3), `pbx-artmann`, `SystemNix` (on v0.1.4) | Depends on the tag | Yes — feature reaches your machines only via these |
| 4 | Install fastfetch on the actual target hosts (evo-x2, pbx?) | Outside this repo; also depends on which hosts you want it on | Presumably the whole point — needs your host list |
| 5 | fish default-path doc fix: "babelfish-translated" → "foreign-env shim (babelfish when `programs.fish.useBabelfish`)" in option description + README/AGENTS/CHANGELOG wording | Discovered during verification at 15:50, after shipping | Yes — small honesty fix (S) |
| 6 | README boundary + "how to see it" note (b-3) | Forgotten, found in self-review | Yes |
| 7 | FEATURES VM row fastfetch mention (b-4) | Forgotten, found in self-review | Yes |
| 8 | zsh/fish VM runtime nodes (b-2) | Cost/benefit unproven | Probably — ask after seeing effort |
| 9 | tmux edge-case handling/test (marker lives in tmux server env captured at server start; a pre-existing tmux server can miss the marker → possible double-fire in new panes) | Edge of an edge; cosmetic consequence | Document first, test only if real |
| 10 | Login latency measurement (fastfetch adds runtime to every interactive login) | Unmeasured; fastfetch is typically <100 ms | Nice-to-have |
| 11 | statix as a CI step (currently manual-only per AGENTS) | Pre-existing decision, not this session's scope | Yes — cheap |
| 12 | `aarch64-darwin` CI runner (CI runs x86_64-linux + aarch64-linux only; darwin checks never run in CI) | Pre-existing gap, noticed this session | Your call (macOS runner cost) |
| 13 | POSIX `sh -n` syntax gate as a check (hook script content is currently syntax-checked only by my one-off command) | Not load-bearing yet | Cheap, worth it |
| 14 | Upstream report of the test-driver stall (needs root-cause first + `verify-before-filing` gate) | Blocked on b-5 | Only if root-caused |

## d) TOTALLY FUCKED UP

Nothing is broken in HEAD — every gate is green and the feature is proven. What follows are the session's genuine failures, because "all green" reports are useless.

| # | What | Severity | Root cause | Mitigation |
|---|------|----------|-----------|------------|
| 1 | **First design was inert-by-instinct**: wrote the hook as `environment.etc."profile.d/…sh"` — NixOS `/etc/profile` never sources that directory. Would have shipped a silent no-op | High (near-miss, not shipped) | Debian reflex instead of mechanism-first verification | Caught because I dumped the generated `/etc/profile` before writing tests; the VM positive subtest would also have caught it. Lesson now recorded in AGENTS.md gotcha. Fix: mechanism-verify every generated-file/script mechanism *before* designing around it — add to AGENTS Conventions |
| 2 | **Burned ~2 full VM runs on the `-tt` stall by theorizing instead of isolating**: first failure → I suspected PerSourcePenalties/PAM/bash mechanics; run 2 revealed the hang exists with the feature *sabotaged out* (pure harness stall, ~900 s wasted per occurrence) | Medium (time: ~2 VM runs ≈ 10–15 min; no code damage) | Violated the repo's own recorded lesson "when a gate behaves impossibly, suspect the test first" — I had it in context and still debugged the module first | The sabotage-first isolation is now the documented trick (AGENTS gotcha). Rule going forward: new harness failure → run the sabotage/isolation probe *before* any module-side hypothesis |
| 3 | **Shipped a mechanically imprecise claim**: "fish (babelfish-translated)" in 4 docs; default fish actually uses the foreign-env shim (babelfish only with `programs.fish.useBabelfish = true`). Feature works either way (both verified today) | Low (docs precision, zero functional impact) | Wrote docs from source *reading* without a build proof — the exact thing the `verify-external-claims` skill exists for | Verified today at 15:50. Remaining work: fix the wording (c-5) |
| 4 | **Sloppy evidence handling, two wasted cycles**: first red-run grep filter was so tight it hid the failure reason → full rerun; then I globbed the store for the drv, matched a stale one, and re-read run 1's log as if it were run 2's | Low (time only) | Ad-hoc log plumbing instead of "save full log keyed by drv hash from the build output itself" | Practice: `DRV=$(grep -ao '/nix/store/[a-z0-9]*-vm-test-run.*\.drv' build.log)` then `nix log "$DRV" > per-drv.log` |
| 5 | **First VM assertion asserted the wrong property** (`status == 0` on a `-tt` invocation) — coupled the greeting property to pty teardown mechanics | Low (caught by own test before ship) | Assertion designed around transport, not property | Property-focused assertions: assert the observable (`"OS:" in output`), not the transport's exit code |

## e) WHAT WE SHOULD IMPROVE

1. **Mechanism-first rule (new convention)** — for anything that depends on generated files/shell init chains, eval-and-read the *generated artifact* before designing. Impact: would have saved the profile.d redesign entirely. Fix: add one line to AGENTS Conventions; it's already half-practiced.
2. **Sabotage-first harness isolation** — when a new VM subtest fails unexpectedly, the *first* act is the kill-switch/sabotage probe (feature out → does it still fail?), not module-side hypotheses. Impact: converts d-2's 15-minute mystery into a 1-run answer.
3. **Red-before-green as the default order** — deliberately run each new assertion in its broken state *before* the green run, instead of after. Impact: same proof, zero extra runs (the red run replaces nothing — it *is* the first run).
4. **Single source of truth for the guard semantics** — six prose copies drift. Fix: pick the option description as canonical; README/FEATURES/AGENTS get one-line summaries + "see option docs", and add a light check if prose drift keeps hurting.
5. **Verify-then-write docs for mechanism claims** — "babelfish-translated" shipped because reading source felt like knowing. Fix: any doc sentence that names a mechanism gets a build/eval proof in the same session (d-3's fix).
6. **Evidence plumbing** — save `nix log $DRV` per drv hash immediately; never grep-filter the primary failure transcript (d-4's fix).
7. **User-facing feature docs** — the README tells admins how to configure the option, but not what a *user* will see or that unmanaged hosts never greet. Fix: short "Login greeting" subsection in README (S).
8. **Report → TODO_LIST loop** — this report's (f) must be harvested or it is a journal entry, not a plan (docs-health HARVEST).

## f) Up to 50 things to get done next

Ranked by impact; effort S (<30 min) / M (30 min–2 h) / L (>2 h). HARVEST target: TODO_LIST (bounded) / ROADMAP (ideas, marked ◇).

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | HARVEST this report: move bounded items into `TODO_LIST.md`, ◇ items into `ROADMAP.md` | High | S | Cleanup |
| 2 | Fix fish wording everywhere ("foreign-env shim by default; babelfish when `useBabelfish`") in option description, README, AGENTS, CHANGELOG | High | S | Documentation |
| 3 | Add fish regression check: eval with `programs.fish.enable = true` (+ one with `useBabelfish = true`) asserting the etc entries exist and the translation drv builds | High | S | Quality |
| 4 | README: add "Login greeting" subsection — what users see, install-fastfetch-to-activate, module-boundary note, opt-out | High | S | Documentation |
| 5 | Update FEATURES.md VM row to mention the fastfetch subtests | Medium | S | Documentation |
| 6 | Root-cause the `-tt`/pty stall in the nixos test driver (minimal repro: `ssh -tt host 'bash -lc true'`) | High | M–L | Quality |
| 7 | If 6 yields an upstream bug: file it (after `verify-before-filing` gate) with the minimal repro | Medium | M | Quality |
| 8 | Decide + document the interactive-pty proof stance: pexpect-style proof vs. accepted-harness-limitation note in tests | Medium | S | Quality |
| 9 | Cut release: date CHANGELOG, tag `v0.1.5`, verify `go get`-equivalent consumer pins resolve (nix flake update on consumers) | High | S | Release |
| 10 | Bump `nix-international-telephony` to the new tag + eval-verify its two VM tests | High | M | Feature |
| 11 | Bump `SystemNix` (floating → new tag) + re-verify evo-x2 and darwin-home evals | High | M | Feature |
| 12 | Decide which hosts get fastfetch installed (evo-x2? pbx? pbx-prod?) and install it — the greeting is invisible until then | High | S | Feature |
| 13 | Live-verify the greeting on one real host after 12 (ssh in, see fastfetch) | High | S | Feature |
| 14 | Update AGENTS.md "Known consumers" table pins after 10/11 | Medium | S | Documentation |
| 15 | Add `sh -n` syntax gate for the hook script as a real check (catches future script edits) | Medium | S | Quality |
| 16 | Guard-semantics canonicalization: option description = source of truth; trim the other five copies to one-liners | Medium | S | Cleanup |
| 17 | Add `loginShellInit` merge-composition check (our hook + a consumer module's own `loginShellInit` both run) | Medium | S | Quality |
| 18 | zsh runtime proof: VM node with zsh login shell asserting the greeting fires via `/etc/zprofile` | Medium | M | Quality |
| 19 | fish runtime proof: VM node with fish login shell (default foreign-env path) | Medium | M | Quality |
| 20 | Document su -/sudo -i/tmux marker semantics in one place (env-wipe → no double-fire; pre-existing tmux server → possible double-fire, cosmetic) | Medium | S | Documentation |
| 21 | Measure login latency added by the hook (VM timing) and note it in README if negligible | Low | S | Quality |
| 22 | ◇ fastfetch presentation options (preset/args/minimal theme) — only if you ever care how it looks | Low | M | Feature |
| 23 | ◇ Non-goal decision: client-side greeting for unmanaged hosts — evaluate RemoteCommand/LocalCommand hacks and almost certainly reject them in ROADMAP | Low | S | Documentation |
| 24 | statix as a CI step (fold into the `check` job) | Medium | S | Quality |
| 25 | Decide on an `aarch64-darwin` CI runner (darwin checks currently never run in CI) — cost/benefit call | Medium | S | Quality |
| 26 | Consumer-compat canary: confirm the weekly CI run stays green with the new default-on option against telephony's pinned configs | High | S | Quality |
| 27 | Post-release: re-run the full local gate sequence on a cold store once (trust-but-verify hermeticity of the new fastfetch closure) | Medium | M | Quality |
| 28 | Sweep `examples/server.nix`: add a one-line comment showing the opt-out (`fastfetchOnLogin = false;`) | Low | S | Documentation |
| 29 | Sweep README Security Rationale: one line on why a login greeting leaks nothing (authenticated shell can read the same info anyway) | Low | S | Documentation |
| 30 | tests/README.md: confirm the golden-regeneration runbook still matches current flow (read it; fix if stale) | Low | S | Documentation |
| 31 | AGENTS.md Critical gotchas: append the "-tt stalls the harness; sabotage-first isolation" lesson as its own bullet if 6 doesn't retire it | Medium | S | Documentation |
| 32 | Add VM subtest: marker prevents double-fire (nested `bash -lc` inside a session with the marker exported) | Low | S | Quality |
| 33 | Annotate + archive this report once its items are harvested (docs-health ANNOTATE) | Low | S | Cleanup |
| 34 | nixpkgs flake.lock update + full gate (routine cadence; the fastfetch closure pins ride along) | Medium | S | Cleanup |
| 35 | ◇ Watch upstream OpenSSH for ML-DSA signatures (existing ROADMAP item, unchanged — re-check date) | Low | S | Feature |
| 36 | ◇ Option namespace v2.0 (`ssh-config.*` hyphen → dots) — existing deferred item, unchanged | Low | L | Feature |
| 37 | BuildFlow nix-checker skip: re-check upstream for per-rule suppression (existing AGENTS note) | Low | S | Cleanup |
| 38 | HM `hmBlock` helper fragility: watch HM `settings` representation changes (existing gotcha; no action until HM moves) | Low | S | Quality |
| 39 | `cache.home.lan` substituter 502s: maintainer-machine-local fix (nothing to do in-repo; listed so it stops appearing in logs unexplained) | Low | S | Cleanup |
| 40 | Delete this session's scratch logs (`/tmp/vm-*.log`, `/tmp/flake-*.log`, `/tmp/fish-build.log`) | Low | S | Cleanup |
| 41 | ◇ Idea: `checks` naming audit — `nixos-fastfetch-login` vs `nixos-*` families; keep names load-bearing and documented in one list | Low | S | Cleanup |
| 42 | ◇ Idea: fold the VM's growing subtest list into named Python helpers if subtest count keeps growing (readability, not behavior) | Low | M | Quality |
| 43 | Confirm pre-push hook content still matches AGENTS' documented gate order (it does per flake.nix shellHook; verify once after any flake.nix change) | Low | S | Quality |
| 44 | Re-read `CONTRIBUTING.md` against the new option (it's in `docOptionFiles`; any prose mention must resolve — currently no mention, decide if it needs one) | Low | S | Documentation |
| 45 | ◇ Idea: make the VM test's per-subtest wait discipline data-driven (wait_for_unit per node table) — the 2026-09-18 boot-race class of bug, generalized | Low | M | Quality |

(45 items; ◇ = ROADMAP fuel, not TODO_LIST.)

## g) Three questions I cannot answer myself

1. **Release timing**: tag `v0.1.5` with this feature now, or batch more work into Unreleased first? This gates every consumer bump (#10/#11) and when your machines actually get the greeting.
2. **Host list**: which machines should actually have fastfetch installed (evo-x2? pbx? pbx-prod? something else)? The feature is a no-op on any host without the binary — I cannot know your fleet's inventory or wishes.
3. **Stall investigation budget**: is root-causing the nixos test driver `-tt`/pty stall (possibly an upstream bug worth filing) worth a dedicated session to you, or do you accept the documented workaround and the injected-`SSH_TTY` proof as permanent?

---

*Format note: written as Markdown per your explicit instruction — the status-report skill's canonical format is a styled HTML dashboard; your `.md` + path instruction overrode it (one-off, not propagated into the skill).*

*Next step per the status-report skill: section (f) is HARVEST input for TODO_LIST.md/ROADMAP.md (docs-health) — say the word and I'll run it.*

**WAITING FOR INSTRUCTIONS.**
