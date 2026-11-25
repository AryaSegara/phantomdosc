# Production Report: checklist to go to production

Made on 25 Nov. Use this list when the Production Report goes to a release. Update the "Status" column as work moves.
Sources: `03-Endpoint-Plan.md`, `02-Knowledge.md`, `01-Decision-Log.md`, and the branches on `origin` (checked 25 Nov).

Status words: **Done** (merged on `phi-dev`), **Open PR**, **Staged** (not committed), **To do**, **Check**, **Decide** (needs a decision first).

---

## 1. Branches and PRs

The base for all PRs is `phi-dev`. None of these PRs is in `ict-dev`, `ict-main` or any `release/*` branch yet (checked 25 Nov).

| # | Branch → PR | What | Status |
|---|---|---|---|
| 1 | `feat/working-area-filters` → #1462 | `/working-areas/{wa}/areas`, `/fields`, `WorkingAreaCatalog` | Done (12 Nov) |
| 2 | `feat/production-report` → #1459 | Summary, Top wells, Chart | Done (12 Nov) |
| 3 | `feat/production-report-working-area` → #1474 | No water, Top 10 without type, Zona 9 lists | Done (16 Nov) |
| 4 | `feat/production-report-input-target` → #1512 | Input Target (4 tables, 15 endpoints), Summary / Chart read it | Done (22 Nov) |
| 5 | `feat/production-report-sot-ops-preview` → #1515 | SOT / OPS preview, template per entity | Done (23 Nov) |
| 6 | `fix/production-report-zone9-chip-filter` → #1524 | Zona 9 chip = PHSS area or PEP field | Done (24 Nov) |
| 7 | `fix/production-report-top-wells-trend-decimals` → #1535 | Top 10 trend 2 decimals, SOT / OPS template like the INPUT sheet | Done (24 Nov) |
| 8 | `fix/production-report-chart-full-dates` → #1540 | Chart full dates, RKAP header check, gain > 0, range ≤ 5 years | Done (25 Nov) |
| 9 | Bruno `docs/production-report-chart-full-dates` | Chart 400 examples (range limit), RKAP header and gain docs | Staged (not committed) |
| 10 | `phantom-fe` | Gas chart `prod_gas` + legend (PHI-3008), SOT / OPS summary filter on, template download with `working_area` | To do (FE) |

**Rules for every PR** (team rules)
- Commit message: `type(production-report): …`; add the Jira key when there is one.
- Curl test results in the PR description (token hidden), and the DoD comment on each Jira ticket.
- Run the build and the tests before the PR. The Production Report / Input Target / Working Area tests (5 test files, `02` §10) passed on 25 Nov (249 tests, #1540). If `dotnet test` hangs on restore, use `--no-restore`.
- A new endpoint needs its service registered in `AppServiceSetup.cs` and `EndpointServiceInstaller`.
- Update the Bruno collection in the same work.

---

## 2. Database (migration)

Prod does not run EF migrations. Each script is written by hand in the Google Doc "PHI DML DDL Execute Docs" (idempotent T-SQL, `IF NOT EXISTS`, no `__EFMigrationsHistory` insert).

| # | Change | Where | Status |
|---|---|---|---|
| 1 | `production_targets`, `production_target_values`, `production_sot_ops_inputs`, `production_sot_ops_values` (dev check 22 Nov: 4 tables, 15 indexes incl. 2 filtered unique, 8 FKs) | migration `20261122085619_AddProductionReportInputTarget` (#1512) | Done on dev (22 Nov). ICT dev / prod: To do |
| 2 | DDL for the Google Doc | `dotnet ef migrations script 20261121090000_AddSimpleScheduleColumns 20261122085619_AddProductionReportInputTarget` (no DB needed; ours is the only migration between them), then split per table | Check: a tab "27 November 2026 → Production Report" exists in the doc; check if it is this DDL |

**Notes for the run**
- The filtered unique indexes (`[status] = N'submitted'`, `[deleted_at] IS NULL`) need `SET QUOTED_IDENTIFIER ON`.
- Check on the target first that the referenced tables exist: `users` (FKs `created_by` / `updated_by` / `deleted_by`).
- Summary, Top wells, Chart and Working Area need **no** DB change.

---

## 3. Seeds (data)
- None. No permission, config or template rows.

---

## 4. Master data and access

| # | Item | Status |
|---|---|---|
| 1 | PHSS areas on the target DB: Badak, Lempake, Mutiara, Nilam, Pamaguan, Semberah, under active fields Northern / Southern | ICT dev: Done (Lempake, Nilam, Pamaguan added 24 Nov). Prod: Check |
| 2 | PEP fields on the target DB: Sangasanga, Sangatta, Tanjung | ICT dev: Done (same ids). Prod: Check |
| 3 | No WF rows active (dev only, D29) | Dev: Done. ICT / prod: none (not made there) |
| 4 | Users of the Production Operations department can open Input Target; others get 403 | Check after deploy |
| 5 | Position rule for Input Target edit (G2) | Decide |

---

## 5. Data clean-up and test data
- Dev: Input Target test data of year 2099 (RKAP / WPNB lines, SOT / OPS from 01-01-2099). Kept for QA. Optional clean-up: delete `production_targets` where `target_year = 2099` and `production_sot_ops_inputs` where `start_date >= '2099-01-01'` (values go by cascade).
- Dev: test wells without area / field, WF dummy wells, big seeds of 04-10 and 09-10-2026 (G11). Owners of the test data.
- No old data to migrate.

---

## 6. Release steps (each release)

1. Ask the BE lead which release branch to use for Sprint 3. Other people already made one: `release/sprint3-yosia` (Gain Report).
2. Make a branch from that release (`git switch --no-track -c feat/release-sprint3-sync-production-report origin/<release>`).
3. Cherry-pick the merge commits in merge order (`git cherry-pick -m 1 -x <merge>`):
   - `88945f92` (#1462)
   - `291926eb` (#1459)
   - `a5347618` (#1474)
   - `5dc9102a` (#1512)
   - `534ca8ce` (#1515)
   - `ed01726a` (#1524)
   - `e94f9cb7` (#1535)
   - `8c1fe207` (#1540)
4. Expect a conflict in `AppServiceSetup.cs` / `EndpointServiceInstaller` if the release has a different Production Accounting state: keep the Input Target lines and the release lines.
5. Build and run the Production Report tests on the branch.
6. Add the DDL of §2 to the Google Doc tab of that release.
7. PR to the release branch, with the curl results.

**Dependency (found 25 Nov):** `release/sprint3-yosia` already has `ProductionGainReportService.InputTarget.cs`, which uses `ProductionInputTarget` (`InputTargetRules`), `WorkingAreaCatalog`, `db.ProductionTargets`, `db.ProductionTargetValues` and `db.ProductionSotOpsValues`. These come from **#1462 and #1512**, and they are not on that branch. So that branch needs our PRs (and the migration) first, or it cannot build. Tell the Gain Report owner and the BE lead.

---

## 7. Decisions needed before go-live
| # | Decision | Ref |
|---|---|---|
| 1 | Edit every RKAP / WPNB version, or only the newest | G1 |
| 2 | Input Target edit by position (SM / GM view only) | G2 |
| 3 | Empty upload cell = 0 or "keep old value" (SOT / OPS) | G3 |
| 4 | Chart daily vs monthly / yearly | G6 |
| 5 | Client mapping findings (column AB, SOT ≠ OPS on 2 days, BRS) | G5 |

---

## 8. Follow-ups accepted for later
- Summary for one area / field (G8), a user-chosen comparison period (G7), chart "comparison data" (G9).
- One source of SOT / OPS with Production Accounting (G10).
- Speed check on ICT dev / prod (G13).
