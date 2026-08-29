# Status Report — Docs-Health Pass 2: Audit, Harvest, Annotate, Archive

**Session:** 2026-08-29, ~13:00–13:41 CEST
**Mandate:** Execute the `docs-health` skill over ALL `**/2026-*` files: view
everything, VERIFY living docs against code, HARVEST open items, fix living
docs to be superb, ANNOTATE fully-resolved historical reports inline
(strikethrough + evidence), and ARCHIVE them.
**Outcome:** Full AUDIT executed. 6 drift/accuracy defects fixed in living
docs, 5 em dashes removed from Nix source, TODO_LIST rebuilt from 3 stale
reports (16 verified rows), ROADMAP extended, 5 historical files fully
annotated and archived, all local gates re-verified green with unmasked exit
codes. Post-fix scores: Accuracy 10/10, Fitness 9.25/10 (pre-fix 6.75 / 7.0).

---

## a) FULLY DONE

| #   | Item                                                                                                                                                                    | Evidence                                                                                                                                       |
| --- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **Skill loaded properly** — docs-health SKILL.md plus references (resolving-items, harvest-guide, health-report-format) and both annotation scripts read BEFORE acting   | session log                                                                                                                                    |
| 2   | **ALL 10 `**/2026-*` files viewed** — 4 unarchived status/planning docs in full, 6 already-archived ones via inventory                                                  | glob + reads                                                                                                                                   |
| 3   | **All living docs read from disk** (README, FEATURES, TODO_LIST, ROADMAP, CHANGELOG, AGENTS, CONTRIBUTING) — caught that my context snapshot of AGENTS.md was stale     | disk reads                                                                                                                                     |
| 4   | **VERIFY against code, not docs** — check counts via `nix eval --json .#checks.<system> --apply builtins.attrNames`: 20/19/18 totals incl. formatters (= 16/17 eval/content + VM on x86_64); FEATURES/AGENTS count claims confirmed ACCURATE | nix eval output                                                                               |
| 5   | **GitHub state verified live** — issue #1 OPEN (0 comments), `gh release list` EMPTY (v0.1.0/v0.1.1 have no Release objects), last CI run green (`32552000904`, 2026-08-22; nothing pushed since) | gh issue view / gh release list / gh run list                                                 |
| 6   | **Code claims of the 08-29 session verified in the working tree** — `kbdInteractiveAuthentication` option at `modules/nixos/ssh.nix:46-59`, emission `:125`, `nixos-kbd-interactive` at `flake.nix:487`, both new VM subtests at `flake.nix:680,686-698`, `examples/server.nix` updated | file reads                                            |
| 7   | **Ghost claim exposed** — the 06-24 report's "discipline note added to AGENTS" was false: grep found no pipe rule anywhere → inline-corrected in the report AND the note actually written | grep across AGENTS/CONTRIBUTING/README + report edit                                          |
| 8   | **FEATURES.md repaired** — `extraSettings` row was truncated mid-cell ("typed \`str", unterminated backtick, content missing) → full typed/merge-last/asserted-by cell  | FEATURES.md server table                                                                                                                       |
| 9   | **README fixed ×5** — "matrix above"→below; directory structure now lists `banner.nix`, `examples/`, `tests/`; x86_64-darwin exclusion stated; banner control-char + authorizedKeys copy-not-symlink notes added to the options table | README edits                                                                                  |
| 10  | **AGENTS hardened** — new gotcha "VM testScript: `succeed` swallows output, `execute` returns it (append `2>&1`)"; 3 conventions (gates unmasked/claims follow exit codes; suspect-the-test-before-caches; blast-radius doc grep); one-command pre-push pre-flight | AGENTS.md Conventions/Commands/gotchas                                                        |
| 11  | **CONTRIBUTING completed** — Gate discipline section (never pipe a gate; claims follow exit codes; doc grep after default changes); VM runtime budget + `-L` evidence note; Releases procedure (runtime test required, Release objects, compare-links) | CONTRIBUTING.md                                                                               |
| 12  | **Em-dash cleanup in Nix source** — 5 occurrences removed (`modules/nixos/ssh.nix:54,55,118`, `flake.nix:2,118`), no behavior change                                    | grep before/after: 0 hits                                                                                                                      |
| 13  | **HARVEST executed** — TODO_LIST rebuilt: 1 blocked release cluster (v0.1.2 + issue #1 close-out + 3 Release objects), 6 test-depth rows, 2 refactoring rows, 1 blocked dprint decision, 6 low rows — every row with status + evidence; zero done-items kept | TODO_LIST.md                                                                                  |
| 14  | **ROADMAP extended** — theme 5 (module surface candidates: UsePAM, AuthenticationMethods, listenAddresses, match blocks, certificateFile, knownHosts, keepalive/CM/UpdateHostKeys, PerSourcePenalties/MaxStartups, LoginGraceTime doc, sntrup IANA alias), theme 6 (CI & infra), retire-downstream-workarounds milestone, prompt-path + table-driven-fixture ideas, 4 open questions (v0.1.0 disposition, sshKeys future, SECURITY.md, ARCHITECTURE placement) | ROADMAP.md                                                                                    |
| 15  | **ANNOTATE: all 5 historical files, inline** — 04-45: every b/c/e/f/g item resolved with hashes (`9f64c93`, `8be838b`, `80ad90e`, `092760c`, …); 06-24: 9 f-items struck + b/c rows corrected + d/1 ghost corrected; 12-51: all 35 f-items + e/g resolved (7 done, 28 struck with `→ TODO_LIST/ROADMAP — still open`); keys-only: superseded banner + per-item verdicts + premature-"green" footer corrected; planning: EXECUTED header, D2/D3 resolved, checklist ticked with hashes | archived files                                                                                                                                |
| 16  | **Scripts used with dry-run discipline** — `annotate-rows.py` / `annotate-prose.py` dry-run first on every new file shape; the dry-run correctly caught that prose items in the 12-51 e-section are multi-line → hand-annotated those instead of corrupting them | script outputs                                                                                |
| 17  | **ARCHIVE: 5 files moved** — `docs/status/archived/` += 04-45, 06-24, 12-51, keys-only (4 new); `docs/planning/archived/` created += pareto plan; `docs/status/` and `docs/planning/` now contain only `archived/` | git mv outputs (tracked ×3; untracked ×2 staged then moved)                                   |
| 18  | **Gates green, unmasked** — `nix flake check --all-systems --no-build` ✅, `nix flake check` incl. QEMU VM test build+run ✅, `nix fmt -- --fail-on-change` ✅ (re-run after all edits), `statix check` ✅ | background gate output, `&&`-chained markers                                                  |
| 19  | **Verification sweep** — awk scan: 0 unmarked numbered items in fully-resolved sections; link check over all living docs + archived: all resolve (the one `../README.md` hit is valid from `examples/`); git status clean inventory of the 14 touched/renamed paths | command outputs                                                                               |
| 20  | **Health report delivered inline** with visible math (Accuracy 6.75→10, Fitness 7.0→9.25) per the skill's format; no score without a finding behind it                  | conversation                                                                                  |

## b) PARTIALLY DONE

| Item                                   | What's missing                                                                                                                                                                                                                             |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Table alignment in README/FEATURES     | Content fixed, but the kbd/authorizedKeys rows and some long Notes cells are not column-aligned. Deliberately deferred to the dprint decision — wiring dprint into treefmt does this mechanically for every table, hand-aligning invites the next drift. Tracked: TODO_LIST "Decisions". |
| dprint enforcement                     | Still configured-but-unenforced (`dprint.json` exists, treefmt runs nixfmt only, `flake.nix:249`). Now a 🔵 blocked decision (reformats archived reports — including this pass's annotations — so it needs a policy call, not a silent flip). |
| One annotation style across archives   | 04-45 and 12-51 mark open items with struck `→ TODO_LIST/ROADMAP — still open` pointers; 06-24 leaves its 33 still-open f-items untouched (skill default: absence = open signal), routing visible only via TODO_LIST and the corrected b/c rows. Both defensible; inconsistent between files. Needs a recorded convention (see g/3). |
| CI coverage of the current tree        | All gates green locally, but the tree (Issue-#1 fix + this docs pass) is uncommitted — no CI run covers it. Remote verification is impossible before commit/push (blocked, see g/1).                                                        |
| Same-day reports archived pre-commit   | The two 08-29 reports describe work that is still uncommitted. Archived per your instruction and session-7 precedent (every item carries a verdict), but if you want same-day reports held in `docs/status/` until their commit exists, the moves are trivially reversible. |
| Render-check of annotations            | All annotation verified structurally (script shape checks + awk scans). No file was opened in an actual Markdown renderer to confirm the strikethrough tables display as intended — the same gap session 7 flagged in its b/3 and I repeated it. |

## c) NOT STARTED

| Item                                                                                            | Why                                                                                                            |
| ----------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| Commit of the working tree (14 modified/renamed/untracked paths: Issue-#1 fix + this docs pass) | Not mine to make unasked; auto-commit daemon had not picked it up as of 13:41                                  |
| v0.1.2 release + issue #1 comment/close + GitHub Release objects for v0.1.0/v0.1.1/v0.1.2       | Remote actions blocked on your authorization (TODO_LIST "Release & remote actions")                            |
| All 15 harvested TODO_LIST work rows (test depth, refactoring, low priority)                    | Freshly harvested this pass; nothing executed yet                                                              |
| ROADMAP's 4 open questions (v0.1.0, sshKeys, SECURITY.md, ARCHITECTURE)                         | Maintainer decisions, recorded not answered                                                                    |
| Upstream docs-health tooling improvements (multi-line annotation support)                       | Out-of-repo work, only proposed (see e/1, f/44)                                                                |

## d) TOTALLY FUCKED UP

1. **I emitted a literal `.replace("\n","ee")` code artifact inside an edit's
   `new_string` for ROADMAP.md.** Sloppy tool-call construction while
   multitasking the TODO_LIST rewrite and ROADMAP edit in one batch. The edit
   failed on exact-match (old text didn't match) so nothing corrupted — the
   safety rail saved me from my own payload. I redid the edit cleanly. The
   failure was the tool's exact-match check, not my attention. One wasted
   round trip.
2. **Doubled-phrase bug in the 06-24 d/1 correction.** My replacement produced
   "Discipline note added to AGENTS after the fact. ~~Discipline note added to
   AGENTS after the fact.~~ **Correction…**" — an unstruck duplicate followed
   by the struck original. Self-caught on the very next action and fixed, but
   I shipped a mangled intermediate state between two tool calls. A reader
   with perfect timing saw garbage.
3. **Batched 7 large hand-edits against the 12-51 report without re-reading
   it after the annotate scripts had modified it.** The multiedit failed
   wholesale ("file modified since last read") — exactly the protection
   working as designed, and exactly the round trip I could have avoided by
   re-reading after script runs. I had even been dinged by this exact class
   before (the 2026-08-22 report's d/5).
4. **Lost track of which sections a combined dry-run/real-run command had
   actually applied.** In one command chain I dry-ran 06-24 section e, then
   ran sections f and g for real — and did not notice until reading my own
   output that e was never applied for real. Caught within one command cycle,
   fixed immediately; the scripts' refuse-already-annotated guarantee means no
   corruption was possible, but my command composition was sloppier than the
   discipline I was enforcing.
5. **Invoked the prose script on visibly multi-line items before anticipating
   the shape mismatch.** The 12-51 e-section wraps at ~90 characters — obvious
   from the file — yet I only discovered the strike-first-line-only problem
   via dry-run. The dry-run discipline caught it (that is the system working),
   but anticipating it would have saved the cycle and is the difference
   between checking and thinking.
6. **My verification pipelines were hand-waved.** The awk range
   `/^## f\)/,/^\?\?/` uses a guessy end-pattern, and the `grep -v -e '^\s'`
   filter in one check does not do what I claimed in ERE. The conclusions
   drawn were still correct (cross-checked by script shape-guards), but the
   pipelines themselves would not survive the scrutiny I apply to this repo's
   assertions.
7. **`nix eval --raw` on a list output errored before I switched to
   `--json`.** Trivial, but it is a "didn't think before typing" in a session
   whose entire theme is verify-before-claiming.
8. **Repeated session 7's render-check gap (b/3 there).** Structural
   verification only; no renderer ever saw the annotated tables. Second
   occurrence of the same skipped step — that is a pattern, not an accident.
9. **Archived today's reports while the work they describe is uncommitted.**
   Defensible under your instruction and precedent, flagged honestly under
   b), but a purist would call annotating "done" items with working-tree
   evidence instead of commit hashes a weaker grade of proof. If the daemon
   commits later, the annotations will reference evidence that only became
   hash-addressable after the fact.

## e) WHAT WE SHOULD IMPROVE

1. **Multi-line annotation tooling.** The skill's scripts only resolve
   single-line items; every report in this repo wraps at ~90 chars, so the
   script consistently covers only part of each file and the rest is
   hand-rolled (this pass, and session 7 before it). Generalize
   `annotate-prose.py` upstream (multi-line item mode) instead of re-deriving
   hand discipline every pass.
2. **Record ONE open-item convention for archived reports** (struck+routed
   markers everywhere vs. leave-open-untouched everywhere) in CONTRIBUTING,
   so the next pass does not have to re-litigate it mid-run — this pass
   produced both styles in one archive directory (see g/3).
3. **Docs-drift guard in CI before anything else on the TODO list.** The
   "13 checks" undercount, the ghost "discipline note added to AGENTS", and
   the "matrix above" direction bug were all mechanically catchable: README
   option tables ↔ module options, documented counts ↔ `builtins.attrNames
   checks`, and simple phrase assertions. One eval check or CI step kills the
   whole class.
4. **The dprint decision is the highest-leverage docs-hygiene item
   outstanding.** It closes table-alignment drift permanently (including the
   rows I deliberately left misaligned), but it touches archived reports, so
   it needs your policy call — after which a strikethrough-integrity re-check
   must run over the archives.
5. **Add a viewer render-check to the docs-health pass checklist.** Two
   consecutive passes have shipped annotations verified only structurally.
   One `glow`/renderer pass over changed archives would close it.
6. **Couple annotate+archive+commit into one authorized flow.** Archiving
   before the underlying work is committed forces working-tree evidence in
   annotations; one commit after annotation makes every future `done at`
   hash-addressable.
7. **Report footers should be timestamped claims, not vibes.** Two of the
   four reports needed inline correction of their "session state" footers
   (one written before its gate returned, one stale within hours). A footer
   template with explicit "as of HH:MM, exit codes in hand" phrasing would
   have prevented both.

## f) NEXT — up to 50, grouped (most already tracked in TODO_LIST/ROADMAP; marked NEW where this pass surfaced them)

**Ship / remote (all blocked on you — TODO_LIST "Release & remote actions"):**
1. Commit the working tree (Issue-#1 fix + this docs pass)
2. Comment on issue #1 (verification summary, fix, PAM nuance, release pointer)
3. Cut v0.1.2: date `[Unreleased]`, annotated tag, push tag + master
4. Verify CI green on both jobs after push
5. Create GitHub Release objects for v0.1.0 and v0.1.1 (both missing, verified)
6. Create the v0.1.2 Release object in the same flow
7. Close issue #1 after the release ships
8. After v0.1.2: retire the downstream workaround in nix-international-telephony (ROADMAP)

**Test depth (TODO_LIST "Test depth"):**
9. VM: wrong-key login rejected (negative auth)
10. VM: banner text actually delivered to a connecting client
11. VM: negotiated KEX asserted as `mlkem768x25519-sha256` via `ssh -vv`
12. VM: `ssh -Q` cross-check of our crypto lists vs runtime sshd support
13. VM: `sshd -T` golden-snapshot comparison (full effective config)
14. Client runtime proof: `ssh -G` on a rendered HM config
15. Multi-node client↔server VM test (ROADMAP E4, full)
16. Positive prompt-path PAM test (ROADMAP, design first)

**Refactoring (TODO_LIST "Refactoring"):**
17. Extract test suite from `flake.nix` → `tests/checks.nix` (~740 lines today)
18. Deduplicate the two `deepSeq` eval checks into content checks
19. Table-driven HM fixture host (ROADMAP)

**Docs hygiene:**
20. 🔵 dprint policy: wire into treefmt or drop `dprint.json` (TODO_LIST "Decisions")
21. After 20: re-align all doc tables mechanically; re-verify strikethrough integrity in archives (NEW — consequence of 20)
22. Docs-drift guard: README option tables ↔ modules + counts ↔ `builtins.attrNames checks` (TODO_LIST; NEW emphasis: also assert the archive links resolve from their new depth)
23. Strikethrough-balance lint in the CI link-check step (TODO_LIST)
24. Decide ARCHITECTURE placement (ROADMAP open question; rec: keep in AGENTS)
25. Decide SECURITY.md single-home (ROADMAP open question)
26. Resolve v0.1.0 disposition (ROADMAP open question; rec: leave)
27. Resolve `sshKeys` personal-keys-as-public-output (ROADMAP open question)
28. Viewer render-check step added to docs-health passes (NEW, from e/5)
29. Upstream PR: multi-line support for annotate-prose.py (NEW, from e/1)
30. Record the open-item annotation convention in CONTRIBUTING (NEW, from e/2, g/3)

**Module surface candidates (ROADMAP theme 5):**
31. `UsePAM` passthrough option (null/bool)
32. `AuthenticationMethods` option (chained 2FA) + eval check
33. `services.ssh-server.listenAddresses`
34. Host `match` blocks
35. Host `certificateFile`
36. `knownHosts` passthrough
37. Client keepalive/`ControlMaster`/`UpdateHostKeys` as options instead of hardcoded
38. `PerSourcePenalties` / `MaxStartups` defaults decisions
39. `LoginGraceTime` explicit default + doc
40. `sntrup761x25519-sha512` IANA alias alongside the `@openssh.com` name
41. Per-user keys example (`users.users.<name>.openssh.authorizedKeys.keys`)

**CI / infra (TODO_LIST "Low priority" + ROADMAP theme 6):**
42. Dependabot/Renovate for the pinned Actions SHAs
43. Weekly `flake.lock` update bot
44. Combined checks-summary job (2 CI jobs → 1 status)
45. CI cache fallback (magic-nix-cache deprecation risk) + investigate `cache.home.lan` 502 flapping
46. Automated release-gate flow (tag → build → VM → compare-links → `gh release create`)
47. README badges (CI status + latest release)
48. Repo meta: CODEOWNERS + issue/PR templates
49. Pre-push gate hook (devShell/pre-commit running the AGENTS pre-flight)
50. Watch cadences: ML-DSA upstream, quarterly OpenSSH-matrix re-verification, `nix flake update` cadence (ROADMAP themes 4/6)

## g) QUESTIONS (cannot be answered from the repo)

1. **Ship authorization:** shall I (a) commit the working tree, then (b) tag
   and push v0.1.2, (c) create the three GitHub Release objects, and (d)
   comment on and close issue #1 — all of it, a subset, or do you want to
   handle the release narrative yourself? (Everything else this session
   produced is inert until the tree is committed.)
2. **dprint policy:** wire `dprint.json` into treefmt so `nix fmt`/CI enforce
   markdown (it will reformat archived reports, so I would follow it with a
   strikethrough-integrity re-check), or drop the config and keep table
   alignment manual?
3. **Annotation + archive convention going forward:** for archived reports
   with still-open items, do you want every item struck with a
   `→ TODO_LIST/ROADMAP — still open` pointer (12-51 style), or open items
   left untouched with absence as the signal (06-24 style)? Related: keep
   today's two reports archived even though the fix they describe is
   uncommitted, or move them back to `docs/status/` until the commit exists?

---

**Session state at 13:41 CEST:** working tree carries the uncommitted
Issue-#1 fix plus this docs pass (14 modified/renamed/untracked paths);
`docs/status/` and `docs/planning/` contain only `archived/`; all four local
gates green with exit codes in hand; nothing committed, nothing pushed;
issue #1 still open.
