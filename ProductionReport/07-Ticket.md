# Production Report: tickets (business logic only)

Made on 25 Nov from `03-Endpoint-Plan.md` and the Jira tickets of Sprint 3.
Scope:
- Only the business logic of each endpoint: rules, checks, results.
- Not here: FE, release steps, DDL for prod. See `05-Production-Checklist.md`.

How to use this file:
- One ticket here = one feature, the same for Zona 9 / PHSS / PEP. The Jira keys of the 3 working areas are in the "Jira" column.
- Each ticket has a **Test result** line: the test cases of `06` and the PR that has the curl results.
- Update the "Status" column when work moves.

Status words: **Done** (merged on `phi-dev`), **Staged** (not committed), **To do**, **Decide** (needs a decision first).

Common rules for all tickets:
- Working area in the path: `zone9`, `phss`, `pep`. Dates `dd-MM-yyyy`, inclusive.
- FIGURE = well history (Well Surveillance). SOT / OPS / Prod. GAS / RKAP / WPNB = submitted Input Target data. A draft never counts.
- PHSS = per area, PEP = per field. Zona 9 = both.
- Empty number = `0`, empty list = `[]`. Only `trend` (no comparison data) and chart points (no data that day) are `null`.
- GET / POST only. Update = `POST /{id}/update`.

---

## 1. Ticket list

| ID | Title | Endpoint (`03` #) | Jira (Zona 9 / PHSS / PEP) | PRs | Status |
|---|---|---|---|---|---|
| PROD-T01 | Filter time range and tab lists | #4, #5, date rules of #1–#3 | PHI-2498 / PHI-2499 / PHI-2500 | #1462, #1474, #1540 | Done |
| PROD-T02 | Production Summary cards | #1 | PHI-2501 / PHI-2502 / PHI-2503 | #1459, #1474, #1512, #1524 | Done |
| PROD-T03 | Production chart | #3 | PHI-2504 / PHI-2505 / PHI-2506 | #1459, #1512, #1524, #1540 | Done |
| PROD-T04 | Top 10 oil | #2 (`product=oil`) | PHI-2507 / PHI-2508 / PHI-2509 | #1459, #1474, #1524, #1535, #1540 | Done |
| PROD-T05 | Top 10 gas | #2 (`product=gas`) | PHI-2511 / PHI-2512 / PHI-2513 | same as PROD-T04 | Done |
| PROD-T06 | Input Target: RKAP / WPNB manual input | #6–#10 | PHI-2804 / PHI-2806 / PHI-2808 | #1512 | Done |
| PROD-T07 | Input Target: RKAP / WPNB bulk upload | #11–#13 | PHI-2805 / PHI-2807 / PHI-2809 | #1512, #1540 | Done |
| PROD-T08 | Input Target: SOT / OPS manual input | #14–#17 | PHI-2804 / PHI-2806 / PHI-2808 | #1512 | Done |
| PROD-T09 | Input Target: SOT / OPS bulk upload | #18–#20 | PHI-2805 / PHI-2807 / PHI-2809 | #1512, #1515, #1535 | Done |
| PROD-T10 | RKAP / WPNB: edit only the newest version? | #7, #8, #10 | – | – | Decide (G1) |
| PROD-T11 | Input Target edit by position (SM / GM view only) | #6–#20 | – | – | Decide (G2) |
| PROD-T12 | SOT / OPS upload: empty cell keeps the old value? | #20 | – | – | Decide (G3) |

FE ticket linked to this work: PHI-3008 (gas chart `prod_gas` and legend).

---

## 2. Tickets

### PROD-T01: Filter time range and tab lists
`GET /working-areas/{working_area}/areas`, `GET /working-areas/{working_area}/fields`, and the date rules of `/production-report/{working_area}/summary | top-wells | chart`.
- Presets 1D, 1W, 1M (default), 1Y, 5Y and a custom range are FE. The backend takes `start_date` and `end_date`.
- Date checks: both required, `dd-MM-yyyy`, start ≤ end, dates in 1900–2100, range ≤ 5 years. Else 400 code `01`.
- The comparison period is computed by the backend (`selected_period`, `02` §5.1).
- Tab lists:
  - Only active areas / fields. An area counts only when its field is active and in the working area. One entry per name (trim, case-insensitive). Sorted by name.
  - Every item has `working_area`.
  - `phss/areas` = PHSS tabs; `pep/fields` = PEP tabs.
  - `zone9/fields` = Zona 9 chips (PHSS areas, then PEP fields); `zone9/areas` = PHSS areas, then PEP areas.
- Wrong working area = 400.

Acceptance:
- Given PHSS areas with duplicate names and orphan rows, when `GET /working-areas/phss/areas`, then each name shows once and orphans are not listed.
- Given a range of 5 years and 1 day, when any report call, then 400 "The date range can be at most 5 years".

Code: `WorkingAreasEndpoint`, `WorkingAreasService`, `WorkingAreaCatalog`, `ProductionReportRequest.TryParse`.
Test result: `06` T1–T12, T39–T43. Curl in PR #1462, #1474, #1540.

### PROD-T02: Production Summary cards
`GET /production-report/{working_area}/summary?start_date=&end_date=&type=SOT|OPS|FIGURE&area=&field=`
- 2 cards: oil (BBLS) and gas (MMSCF). No water.
- `value` = total of the daily values in the range (not cumulative since the well started).
- `trend` = % vs the comparison period, 2 decimals; `null` when the comparison value is 0 (FE "N/A").
- `selected_period` = the comparison dates.
- `breakdown`:
  - `zone9`: PHSS and PEP.
  - `phss`: every PHSS area; `pep`: every PEP field (0 when no data).
  - `[]` when `area` / `field` is sent.
  - `percentage` = part / total, whole number. Wells without a valid area / field are in the total only.
- `type`:
  - FIGURE = well history.
  - SOT = SOT oil + Prod. GAS; OPS = OPS oil + Prod. GAS. Submitted Input Target only.
- On `zone9`, `area` / `field` = a Zona 9 chip: a PHSS area name → PHSS filter, a PEP field name → PEP filter.
- `chart_data` (daily up to 92 days, else monthly) is kept, but the new design has no sparkline.

Acceptance:
- Given PHSS 100 and PEP 50 BBLS of oil in the range and 120 in the comparison period, when `zone9` FIGURE, then oil = 150, trend = 25.00, breakdown PHSS 67%, PEP 33%.
- Given no data in the comparison period, then `trend` = `null`.
- Given a submitted SOT input and a draft, when `type=SOT`, then only the submitted input counts.

Code: `ProductionReportService.GetSummaryAsync`, `InputSummaryAsync`, `BreakdownAsync`, `ProductionPeriod`, `ProductionMath`.
Test result: `06` T13–T25, T38. Curl in PR #1459 (15 scenarios on the dev DB, 11 Nov), #1474, #1512, #1524. Bruno: "Get Production Report Summary".

### PROD-T03: Production chart
`GET /production-report/{working_area}/chart?start_date=&end_date=&product=oil|gas&area=&field=`
- `unit` = BOPD (oil) / MMSCFD (gas).
- Every series has one point per day from start to end, the same dates in the same order. A day without data = `value: null`. Daily for every range.
- `production_figure` = sum of the well rates of the day.
- Oil: `production_sot`, `production_ops` = submitted SOT / OPS oil; `prod_gas` all `null`.
- Gas: `prod_gas` = submitted Prod. GAS; `production_sot` / `production_ops` all `null`.
- `target_rkap`, `target_wpnb` = the newest submitted line per year + type + working area; the monthly rate on every day of that month.
- Area / field filter and Zona 9 chips as PROD-T02. A PHSS field filter or a PEP area filter has no Input Target data (`null`).

Acceptance:
- Given 1M (32 days) with history on 26 days, then every series has 32 points and the 6 days without history are `null` in `production_figure`.
- Given RKAP 2099 PHSS version 1 (submitted) and version 2 (submitted), then `target_rkap` uses version 2.
- Given `product=gas`, then `production_sot` and `production_ops` are all `null`.

Code: `ProductionReportService.GetChartAsync`, `DailyPoints`, `SotOpsDaysAsync`, `TargetMonthsAsync`.
Test result: `06` T33–T38, T7. Curl in PR #1512 (2099 data), #1540 (32 points, 5Y = 1,827 points). Bruno: "Get Production Report Chart".

### PROD-T04: Top 10 oil
`GET /production-report/{working_area}/top-wells?start_date=&end_date=&product=oil&area=&field=`
- Always FIGURE. No `type` (a sent one is ignored).
- Candidate: the well has a row in the range and produced oil in the range or in the comparison period.
- `production_gain`:
  - value = average BOPD in the range − average BOPD in the comparison period;
  - only gains > 0;
  - highest first;
  - trend = % change of the two averages.
- `highest_production`: total BBLS in the range, highest first.
- `lowest_contribution`: total BBLS in the range, lowest first, 0 included.
- Max 10 per list. Ties by well name A–Z. `trend` 2 decimals, `null` when the comparison is 0.
- `selected_period` = the comparison dates.
- Chips: PHSS `area=`, PEP `field=`, Zona 9 chip name on `zone9`.

Acceptance:
- Given BDK-01 with 20 BBLS in 7 days and 8 BBLS in the 7 days before, then gain = 1.71 BOPD, trend = 150.
- Given DROP-01 with 6 → 0, then it is first in `lowest_contribution` (trend −100) and not in `production_gain`.
- Given a gas-only well, then it is not in any oil list.

Code: `ProductionReportService.GetTopWellsAsync`.
Test result: `06` T26–T32. Curl in PR #1459, #1535 (2 decimals), #1540 (gain > 0). Bruno: "Get Production Report Top Wells".

### PROD-T05: Top 10 gas
Same endpoint and rules as PROD-T04 with `product=gas`. Units: gain MMSCFD, highest / lowest MMSCF. PEP gas is not converted (MMSCF like PHSS).

Acceptance:
- Given a well with oil but no gas in both periods, then it is not in any gas list.

Test result: `06` T27, T29 (PEP gas 17–23 Nov). Same PRs as PROD-T04.

### PROD-T06: Input Target, RKAP / WPNB manual input
`GET /production-report/input-target/entities/{phss|pep}`, `GET /rkap-wpnb`, `GET /rkap-wpnb/{id}`, `POST /rkap-wpnb`, `POST /rkap-wpnb/{id}/update`
- Access: view = Production Operations in the active departments (a Senior Manager views); write = own department Production Operations. Else 403.
- Grid rows (`entities`): active PHSS areas / PEP fields from the catalog. There is no WF filter in the code; the WF rows are left out because they are inactive in the master data (D29).
- Body: `target_year` (2000–2100), `type` (RKAP / WPNB), `working_area` (phss / pep), `status` (draft / submitted), `rows[{ name, oil[12], gas[12] }]`.
- Rows:
  - at least 1, at most 200;
  - each name must be a row of that working area, only once;
  - 12 numbers ≥ 0 for oil and gas; an empty value = 0.
- A **submitted** line must have every area / field. A draft may have some.
- Create always adds a new line, also for an existing year + type + working area (internal version + 1). The report reads the newest submitted one.
- Update changes the line in place (same body):
  - submitted → draft = 400;
  - moving onto an existing year + type + working area = 409;
  - every line can be edited (G1 / PROD-T10).
- `source` = `manual`. List filters: `working_area`, `target_year`, `type`, `status`, paging (max 1000).

Acceptance:
- Given RKAP 2099 PHSS exists, when the user creates RKAP 2099 PHSS again, then a new line is added and the list shows it first.
- Given a submit with 5 of 6 PHSS areas, then 400 "rows must include every PHSS area: missing …".
- Given a user of SDA 2, when `GET /rkap-wpnb`, then 403.

Code: `ProductionInputTargetService` (create / update / list / detail), `InputTargetRules`, `InputTargetAccess`.
Test result: `06` T44–T53, T78–T81. Curl in PR #1512 (#16–#21: 2099 data, user Production Operations member). Bruno: "Production Report Input Target / Create, Update, Get RKAP WPNB…".

### PROD-T07: Input Target, RKAP / WPNB bulk upload
`GET /rkap-wpnb/template`, `POST /rkap-wpnb/upload/preview`, `POST /rkap-wpnb/upload`
- File: multipart `file`, `.xlsx`, ≤ 5 MB. Read in memory; only `file_name` is stored.
- Template: sheet "Target":
  - B1 Target Year, B2 Type, B3 Entity (PHSS / PEP), row 4 a note;
  - A5 "Field", "Oil…" over B..M, "Gas…" over N..Y, row 6 Jan..Dec, data from row 7;
  - empty (the user fills year, type, entity and names).
- Preview: reads B1..B3 → `{ target_year, type, working_area }`; 400 "Unable to read …" names what is missing. Nothing is saved.
- Upload:
  - checks the header (Oil / Gas blocks and months), else 400 file error;
  - checks every row (name of the working area, once, numbers ≥ 0) and that every area / field is there;
  - any error = 400 with `errors[{ row, message }]` and nothing saved;
  - success = a new **submitted** line, `source` `bulk_upload`.

Acceptance:
- Given a template without the Gas block, then 400 "Row 5 must have Gas over N..Y with Jan..Dec under it …" and no line is added.
- Given a filled template, then a new submitted line with the file name.

Code: `ProductionTargetExcel`, `ProductionInputTargetService` (upload / preview).
Test result: `06` T54–T61. Curl in PR #1512, #1540.

### PROD-T08: Input Target, SOT / OPS manual input
`GET /sot-ops`, `GET /sot-ops/{id}`, `POST /sot-ops`, `POST /sot-ops/{id}/update`
- Access as PROD-T06.
- Body: `working_area`, `status` (draft / submitted), `start_date`, `end_date` (≤ 366 days), `rows[{ date, name, sot_oil, ops_oil, prod_gas }]`.
- Each date inside the range; each name a row of the working area; name + date only once; numbers ≥ 0.
- The stored range follows the rows (first and last date).
- Submit: a (name, date) already held by another submitted input is **replaced**. That input's range shrinks; with no days left it is soft-deleted. `replaced_rows` = how many values were replaced.
- A draft replaces nothing and is not counted.
- Update replaces the input's own rows (not counted in `replaced_rows`); submitted → draft = 400.
- List filters: `working_area`, `status`, `start_date` / `end_date` (overlap), paging.

Acceptance:
- Given a submitted input A for 01..03-01-2099, when input B is submitted for 02-01-2099, then A keeps 01 and 03 and `replaced_rows` = 1.
- Given a draft on the same day, then nothing is replaced until it is submitted.

Code: `ProductionInputTargetService.SotOps` (`SaveSotOpsRowsAsync`, `ShrinkInputsAsync`).
Test result: `06` T62–T69. Curl in PR #1512 (2099 data).

### PROD-T09: Input Target, SOT / OPS bulk upload
`GET /sot-ops/template?working_area=`, `POST /sot-ops/upload/preview`, `POST /sot-ops/upload`
- Template = the client INPUT sheet layout:
  - one sheet per working area: `phss` / `pep` = that sheet, none = both, `zone9` = 400;
  - A4 "Date", row 4 = name over 3 columns, row 5 = PROD SOT | PROD OPS | PROD GAS, dates from row 6.
  - The parser also takes the name in every cell (no merge), upper case, "TANGGAL", and the short labels SOT / OPS / GAS. The old template layout is refused.
- File rules as PROD-T07. Fill only one sheet per upload. At most 366 dates.
- Preview: `{ working_area, start_date, end_date, days }`, values not checked, nothing saved. 400 "Unable to read dates", or the upload's file errors.
- Upload: every cell checked (date format, date once, numbers ≥ 0, name of the working area); any error = 400 with `errors[]`, nothing saved. Success = one **submitted** input, `source` `bulk_upload`; clashing days replaced as PROD-T08.
- An empty cell = 0 (G3 / PROD-T12).

Acceptance:
- Given a filled PEP sheet for 24..26-12-2025, when preview, then `days` = 3 and nothing is saved.
- Given both sheets filled, then 400 "Fill only one sheet (PHSS or PEP) per upload".

Code: `ProductionSotOpsExcel`, `ProductionInputTargetService.SotOps` (upload / preview).
Test result: `06` T70–T77. Curl in PR #1515 (11 calls), #1535.

### PROD-T10: RKAP / WPNB, edit only the newest version? (Decide)
- Today: every line can be edited; the response has no `version` / `is_latest` (D23).
- Product Owner (19 Nov): only the newest version can be edited (D19).
- If "newest only" is confirmed:
  - add `version` and `is_latest` to #7 / #8;
  - return 400 on #10 for an older version.
- Update `06` T48.

### PROD-T11: Input Target edit by position (Decide)
- Today: edit = own department Production Operations (any position). A Senior Manager who picks Production Operations can edit; a GM is not widened (G2).
- Proposal:
  - edit only for non-SM / non-GM users of Production Operations (`R3PositionHelper.IsSeniorManager` / the SM-GM picker list);
  - a GM views like an SM.
- Update `06` T79–T81.

### PROD-T12: SOT / OPS upload, empty cell (Decide)
- Today: empty = 0. On submit, the 0 replaces the submitted value of that name + date (G3).
- Option: an empty cell = "no row" (the old value stays). Then a fully empty date row is skipped.
- Update `06` T77.
