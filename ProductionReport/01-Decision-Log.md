# Production Report: decision log and knowledge

This file records:
- each decision (with date and source),
- each change to the Production Report docs,
- each fact we found in the code or the database.

**All links:** see `02-Knowledge.md` §10.

Write a new entry at the bottom of each section. Do not change old entries. If a decision changes, write a new entry that names the old one.

**Words used in this file:**
- **Working area:** `zone9`, `phss` or `pep` (the 3 tabs of the page). Zona 9 = PHSS + PEP.
- **Area (structure):** a row of `areas`, under a field. PHSS tabs and chips are areas (Badak, Lempake, Mutiara, Nilam, Pamaguan, Semberah).
- **Field:** a row of `fields`. PEP tabs and chips are fields (Sangasanga, Sangatta, Tanjung). PHSS fields are Northern and Southern.
- **Chip:** the filter buttons on a card or list (one area or field).
- **FIGURE:** the daily well data from Well Surveillance (`well_history_phss`, `well_history_pep`). The PRD and the Figma call it "Figure".
- **SOT / OPS:** oil from sales (SOT) and oil from another source (OPS). Entered by hand in Input Target.
- **Prod. GAS:** gas entered in Input Target next to SOT / OPS. Gas is not split into SOT and OPS.
- **RKAP / WPNB:** yearly targets (WPNB = WP&B), one value per month. Entered in Input Target.
- **Input Target:** the "Input Target" window (RKAP & WPNB tab, SOT & OPS tab).
- **Selected period:** the **comparison** period ("vs."). The JSON key is `selected_period` because the Figma label says "Selected Period". It is NOT the range the user picked.
- **Trend:** % change of the picked range against the selected period.
- **Production Operations:** the department. Not the same as "Product Owner" (the person who answers the PRD questions).

---

## 1. Decisions
| ID | Date | Decision | Source | Replaces |
|---|---|---|---|---|
| D1 | 10 Nov | The user's scope = the Production Report tickets only (PHI-2498–2509, PHI-2511–2513). Production Gain Report and Production Accounting belong to other people. | User | – |
| D2 | 10 Nov | No data = `0` for a number and `[]` for a list. No `null` in the response. | FE | – |
| D3 | 10 Nov | FIGURE = Well Surveillance daily history (`well_history_phss` + `well_history_pep`). SOT / OPS stay empty until a source exists. | User; PRD 11 Nov ("Figure = data Well Surveillance") | – |
| D4 | 10 Nov | Top 10 Lowest Contribution: unit BBLS (oil) / MMSCF (gas). A well with 0 production is not skipped. | User + Figma | – |
| D5 | 10 Nov | PHSS tabs = areas, PEP tabs = fields. Two optional query params on every report call: `area` (PHSS) and `field` (PEP). | Team (design is correct) | – |
| D6 | 10 Nov | One route per feature with the working area in the path: `/production-report/{working_area}/...`. Not one endpoint per working area. | FE review of Bruno PR #199 | – |
| D7 | 10 Nov | Tab lists are general endpoints, split in two: `GET /working-areas/{wa}/areas` and `GET /working-areas/{wa}/fields`. Active rows only, one entry per name (trim, case-insensitive). | User | – |
| D8 | 11 Nov | A well with no valid area / field counts in the card total but not in a tab. No "Others" box. | User | – |
| D9 | 11 Nov | Keep `0` for a trend without comparison data. No `has_comparison` flag. | User | – |
| D10 | 12 Nov | Comparison period = PRD formula: compare start = start − (T + 1), compare end = compare start + T, T = end − start in days. Same length, ends the day before the picked range, no day counted twice. | PRD 12 Nov (Summary approved) | Calendar shift for whole months / years (10 Nov) |
| D11 | 12 Nov | `trend` is a number (not an object). The comparison dates are in one `selected_period: { start_date, end_date }` object. Top 10 message = "Get top 10 well succeed". | FE contract (Notion) | – |
| D12 | 12 Nov | `trend: null` when the comparison value is 0 or has no data. FE shows "N/A". Other values stay `0` / `[]`. | FE (option 3 of the review) | D2 (for trend only), D9 |
| D13 | 12 Nov | The key stays `selected_period` (= the comparison period, as the Figma labels it). The rename to `comparison_period` is rejected. Do not propose it again. | FE + User (review #1459, round 3) | – |
| D14 | 12 Nov | PEP `gas_out` is MMSCF like PHSS. No /1000. | Review #1459 (data check) | – |
| D15 | 12 Nov | Top 10 candidate = the well reported in the picked range **and** produced the product in the range or in the comparison period. | Review #1459 | – |
| D16 | 16 Nov | Water is removed. The Summary has 2 cards: oil and gas. | FE (new design) | – |
| D17 | 16 Nov | Top 10 has no SOT / OPS / FIGURE choice: it always reads FIGURE. A sent `type` is ignored. | FE (design) | – |
| D18 | 16 Nov | `GET /working-areas/zone9/fields` = the Zona 9 chips = PHSS areas + PEP fields. Every item has `working_area` (phss / pep). `/zone9/areas` = PHSS areas + PEP areas. | FE + User | – |
| D19 | 19 Nov | Product Owner answers on Input Target: a Draft never counts; RKAP / WPNB entered again for the same year + type + working area = a new line (version); Edit = change that line; RKAP / WPNB bulk upload = submitted at once, template = the Manual Input grid; SOT / OPS on a clashing date = replaced (no version); units BOPD / MMSCFD; SOT / OPS have their own bulk upload template; SOT / OPS / RKAP / WPNB go into Summary and Chart **this sprint**; Summary = total in the range; PEP chip = field. | Product Owner | PRD "SOT / OPS out of scope" |
| D20 | 19 Nov | Input Target access = "PO only, SM view": the Production Operations department reads and writes, a Senior Manager reads. No delete, no history (not in the design). | Product Owner | – |
| D21 | 19 Nov | Input Target rows: PHSS = one row per area, PEP = one row per field (RKAP / WPNB and SOT / OPS). | PRD + Product Owner | – |
| D22 | 20 Nov | New endpoints use GET and POST only. Edit = `POST /{id}/update`. | User | – |
| D23 | 22 Nov | RKAP / WPNB: `version` is internal. The response has no `version` / `is_latest`. Every line can be edited. Moving a line onto a year + type + working area that already exists = 409. | User | D19 "only the newest version can be edited" (see G2) |
| D24 | 22 Nov | SOT / OPS have Draft and Submitted (Figma). A draft replaces nothing. A submit replaces the clashing days (same name + date) of other submitted inputs. | Figma + User | – |
| D25 | 22 Nov | The backend makes the Excel templates (download endpoints). FE does not keep static files. | User | – |
| D26 | 22 Nov | `source` (`manual` / `bulk_upload`) stays in the Input Target responses. The backend fills it from the endpoint that was called. | User | – |
| D27 | 22 Nov | Summary SOT / OPS tab = SOT oil (or OPS oil) + Prod. GAS. Chart: `production_sot` / `production_ops` = oil, `prod_gas` = gas, `target_rkap` / `target_wpnb` = the newest submitted line per year + type + working area, the monthly rate repeated on each day of the month. | Product Owner (D19) + User | – |
| D28 | 22 Nov | A **submitted** RKAP / WPNB line must have every area (PHSS) / field (PEP). A draft may have some rows only. | Review #1512, option A | – |
| D29 | 23 Nov | The dummy Water Flood rows (WF Field / WF Area, PHSS and PEP) are set `is_active = 0` on the dev DB. No WF filter in the code. | User | WF name filter in code (20 Nov) |
| D30 | 23 Nov | Input Target does not use MinIO. The file is read in memory. Only `file_name` is stored on a successful upload. | User | – |
| D31 | 24 Nov | Top 10 `trend` has 2 decimals (like the Summary), not a whole number. | QA report | D11 (Top 10 rounding) |
| D32 | 24 Nov | SOT / OPS template = the client "INPUT" sheet layout: row 4 = area / field name (3 merged cells), row 5 = PROD SOT / PROD OPS / PROD GAS, data from row 6. Old template files are refused. | Product Owner ("per field", sheet INPUT of the client report) | 22 Nov template layout |
| D33 | 24 Nov | Every chart series carries every date from start_date to end_date, in the same order. A day without data = `value: null`. | FE | Chart sends only days with data |
| D34 | 25 Nov | The chart stays **daily** for every range. No month / year buckets. | User | PRD granularity (< 30 days daily, ≥ 30 days monthly, ≥ 1 year yearly) and D19 "1Y per month" |
| D35 | 25 Nov | Date range at most 5 years, dates between 01-01-1900 and 31-12-2100 (summary, top wells, chart). | Review #1540 + BE lead | – |
| D36 | 25 Nov | Top 10 `production_gain` lists only gains > 0. | PRD ("gain only positive") | D15 (part: gain list) |
| D37 | 25 Nov | RKAP / WPNB upload checks the header: B5 = "Oil…", N5 = "Gas…", row 6 = Jan..Dec under both. Otherwise 400. | QA report | – |

---

## 2. Changes to the docs
| Date | File | Change |
|---|---|---|
| 25 Nov | All files | New. Made from the merged code on `phi-dev` (`407f2c26`), the Bruno collection (`main`), the PRD, the FE contract and our notes from 10–25 Nov. Same layout as `mnhafid/phantomdocs/WorkOrder`. |

---

## 3. Knowledge from the code and the database
Checked 25 Nov on `phi-dev` and the dev database (read-only), plus notes from 10–25 Nov.

**Data**
- FIGURE PHSS = `well_history_phss` (from INTERSYS, monthly load; the PRD says about 1 month late). FIGURE PEP = `well_history_pep` (from INAMETA, daily).
- Oil = `oil`, gas = `gas_out`. One history row = one day's rate of one well (zone), so the sum of one day = the field rate (BOPD / MMSCFD).
- A row counts when `deleted_at` is null and the well is not deleted. The well gives `area_id` and `field_id`.
- PEP gas: INAMETA GAS is about 0.008 per well-day at about 16 BOPD (GOR about 500 scf/bbl), and the Excel import header says "Gas Out (Mmscfd)". So it is MMSCF, not MSCF (D14).
- There is no table for RKAP / WPNB production targets. `rkaps` is the project RKAP, not a production target. So Input Target made new tables (D19).

**Master data (areas / fields)**
- `areas` on dev: 52 active rows. 24 valid (under an active field of PHSS or PEP). 28 orphans (seed 04-12-2023, `field_id` points to no field, 0 wells, but 4 `plants` still point to them). Do not delete them in this feature.
- Badak, Lempake, Nilam have 8 rows each and Semberah 9 (most are the orphans). Mutiara has 2 rows (Northern and Southern). `fields` has no duplicates.
- So the catalog (`WorkingAreaCatalog`) keeps areas under the active fields of the working area, then groups by name (trim + case-insensitive). Mutiara = one tab with both ids.
- Semberah is a PHSS area and also a PEP field. Tanjung and Sangatta are PEP area names and also PEP field names.
- ICT dev DB (24 Nov): `areas` had only 11 rows (same ids as Ocean dev). PHSS had only Badak / Mutiara / Semberah. Lempake, Nilam and Pamaguan were added by DML (user, 24 Nov). Prod is not checked yet.

**Dev data (why dev numbers look wrong)**
- Wells with production but no valid area / field: 88 PHSS, 35 PEP (11 Nov); 118 in total on 25 Nov. All are QA / seed test wells (TCL…, HL…, QS…, QTC…, SEED-…, TEST-…). They count in the totals but not in a tab, so the breakdown is far below 100% on dev.
- Big seeds on 04-10-2026 (2,604 rows) and 09-10-2026 (5,125 rows) make the 1M trend about −94% on dev.
- Some test wells have gas about 400 MMSCFD per well. Data clean-up, not code.
- Dev has many days without data (1Y: PHSS 225 days, PEP 296 days) and no data for the year before, so YoY trends are often N/A.
- Input Target test data on dev: year 2099 (RKAP / WPNB lines and SOT / OPS inputs from 01-01-2099). Kept on purpose for QA.

**Speed (18 Nov)**
- Dev `process_time` 8–20 s. Local API to the same DB: 0.1–3.6 s one by one, ≤ 7 s with 4 calls at once. The raw SQL is about 0.5 s (PHSS 65k rows, 11.7k in a 1M range). So it is the environment, not the query. Risk on prod if the history is much bigger: a 5Y range reads 10 years (range + comparison).

**Other modules that touch the same data**
- Production Accounting (other team): `production_accounting_entries` (daily per node: plant / well / final destination, mode `sot` / `ops`, bulk import only), `production_accounting_network_edges`, `production_accounting_final_destinations`. Its plant level is the other way round (PHSS plant = field, PEP plant = area). Not used by the Production Report.
- Production Gain Report (other team, 23 Nov): `ProductionGainReportService.InputTarget.cs` reads the Input Target tables. **A change to the Input Target tables or rules must be checked with the Gain Report.**
