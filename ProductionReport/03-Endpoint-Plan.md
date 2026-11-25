# Production Report: endpoint list (built and changed)

Status: **built**. Every endpoint below is merged on `phi-dev` (checked 25 Nov, `407f2c26`). Made from the code, the Bruno collection and the decisions (`01-Decision-Log.md`).

Rules for all endpoints:
- Carter Services pattern: Endpoint in `WebApi/Services/<Module>`, Service in `Logics/Services/<Module>`, registered in `AppServiceSetup.cs`.
- `GET` to read, `POST` to create and update (`POST /{id}/update`). No `PUT` / `PATCH` / `DELETE` (D22).
- Filter: `R3ComponentFilter` (login + department context). Report and Working Area routes are `.AllowCrossAreaAccess()` (`02` §9).
- Dates in query and body: `dd-MM-yyyy`.
- Wrapper `{ data, process_time, status, code, message }`. Codes: `00` OK, `01` bad request (400) / conflict (409), `03` forbidden (403), `04` not found (404), `99` server error (500).
- Base path: `/api/v1`.

---

## 1. What existed before (checked 10 Nov)

| Area | What existed | Gap |
|---|---|---|
| Production data | `well_history_phss`, `well_history_pep` (Well Surveillance) | No report endpoint. No SOT / OPS / target data. |
| Areas / fields | `GET /dropdowns/areas` (filter by `field_id` only, 52 rows without a filter, orphans included), `GET /dropdowns/fields?working_area=` | No list per working area, duplicate names. |
| Targets | `rkaps` = project RKAP | No production target table. |
| FE | Routes `/production-report/dashboard/{zone9\|phss\|pep}` with no API calls | – |

---

## 2. New endpoints

### 2.0 Path table

| # | Method | Path | Query / body | PR | Status |
|---|---|---|---|---|---|
| 1 | GET | `/production-report/{working_area}/summary` | `start_date`, `end_date`, `type` (SOT / OPS / FIGURE), `area?`, `field?` | #1459, #1474, #1512, #1524 | Done |
| 2 | GET | `/production-report/{working_area}/top-wells` | `start_date`, `end_date`, `product` (oil / gas), `area?`, `field?` | #1459, #1474, #1524, #1535, #1540 | Done |
| 3 | GET | `/production-report/{working_area}/chart` | `start_date`, `end_date`, `product`, `area?`, `field?` | #1459, #1512, #1524, #1540 | Done |
| 4 | GET | `/working-areas/{working_area}/areas` | – | #1462, #1474 | Done |
| 5 | GET | `/working-areas/{working_area}/fields` | – | #1462, #1474 | Done |
| 6 | GET | `/production-report/input-target/entities/{phss\|pep}` | – | #1512 | Done |
| 7 | GET | `/production-report/input-target/rkap-wpnb` | `working_area?`, `target_year?`, `type?`, `status?`, `page`, `page_size` | #1512 | Done |
| 8 | GET | `/production-report/input-target/rkap-wpnb/{id}` | – | #1512 | Done |
| 9 | POST | `/production-report/input-target/rkap-wpnb` | `{ target_year, type, working_area, status, rows[{ name, oil[12], gas[12] }] }` | #1512 | Done |
| 10 | POST | `/production-report/input-target/rkap-wpnb/{id}/update` | same body as #9 | #1512 | Done |
| 11 | GET | `/production-report/input-target/rkap-wpnb/template` | – | #1512 | Done |
| 12 | POST | `/production-report/input-target/rkap-wpnb/upload/preview` | multipart `file` | #1512 | Done |
| 13 | POST | `/production-report/input-target/rkap-wpnb/upload` | multipart `file` | #1512, #1540 | Done |
| 14 | GET | `/production-report/input-target/sot-ops` | `working_area?`, `status?`, `start_date?`, `end_date?`, `page`, `page_size` | #1512 | Done |
| 15 | GET | `/production-report/input-target/sot-ops/{id}` | – | #1512 | Done |
| 16 | POST | `/production-report/input-target/sot-ops` | `{ working_area, status, start_date, end_date, rows[{ date, name, sot_oil, ops_oil, prod_gas }] }` | #1512 | Done |
| 17 | POST | `/production-report/input-target/sot-ops/{id}/update` | same body as #16 | #1512 | Done |
| 18 | GET | `/production-report/input-target/sot-ops/template` | `working_area?` (phss / pep) | #1512, #1515, #1535 | Done |
| 19 | POST | `/production-report/input-target/sot-ops/upload/preview` | multipart `file` | #1515 | Done |
| 20 | POST | `/production-report/input-target/sot-ops/upload` | multipart `file` | #1512, #1535 | Done |

Notes:
- `{working_area}` on #1–#5 = `zone9`, `phss` or `pep`. Input Target takes only `phss` / `pep` (rows are per working area).
- Top 10 takes no `type` (D17). A sent `type` is ignored.

### 2.1 Summary (#1)
- Validation (400, code `01`): working area; both dates; date format; start ≤ end; dates in 1900–2100; range ≤ 5 years; `type` in SOT / OPS / FIGURE.
- `data`:
  - `type`, `start_date`, `end_date` (the picked range),
  - `selected_period { start_date, end_date }` (the comparison period, D13),
  - `items[]` for `oil` and `gas`: `product`, `unit` (BBLS / MMSCF), `value`, `trend` (`null` = N/A), `chart_data[{ date, value }]`, `breakdown[{ entity, value, percentage }]`.
- Rules: `02` §5.2. Message "Get production summary succeed".

### 2.2 Top wells (#2)
- Validation like #1, with `product` (oil / gas) instead of `type`.
- `data`: `selected_period`, `production_gain[]`, `highest_production[]`, `lowest_contribution[]`. Item: `well_name`, `value`, `unit`, `trend`.
- Units: gain BOPD / MMSCFD; highest / lowest BBLS / MMSCF.
- Rules: `02` §5.3. Message "Get top 10 well succeed".

### 2.3 Chart (#3)
- Validation like #2.
- `data`: `unit`, `production_figure[]`, `production_ops[]`, `production_sot[]`, `prod_gas[]`, `target_rkap[]`, `target_wpnb[]`. Item: `date`, `value` (`null` = no data).
- Every series has one point per day from start to end (5 years = 1,827 points per series).
- Rules: `02` §5.4. Message "Get production chart succeed".

### 2.4 Working Area lists (#4, #5)
- `data: [{ name, working_area }]`, active rows only, one entry per name, sorted by name.
- `phss` / `pep`: that working area. `zone9`:
  - `/areas` = PHSS areas, then PEP areas.
  - `/fields` = PHSS areas, then PEP fields (the Zona 9 Top 10 chips, D18).
- Wrong working area = 400.
- The Production Report uses `/phss/areas` (PHSS tabs), `/pep/fields` (PEP tabs) and `/zone9/fields` (Zona 9 chips).

### 2.5 Input Target (#6–#20)
- Access: view = Production Operations in the active departments; write (#9, #10, #12, #13, #16, #17, #19, #20) = own department Production Operations. Else 403, code `03` (G2).
- #6: `data: [{ name, working_area }]` = the grid rows.
- #7 list item: `id`, `target_year`, `type`, `working_area`, `status`, `source`, `created_at`, `created_by`, `updated_at`, `updated_by`. #8 detail adds `oil_unit`, `gas_unit`, `rows[{ name, oil[12], gas[12] }]`.
- #9 always adds a new line. #10 edits the line; moving onto an existing year + type + working area = 409.
- #12: `{ target_year, type, working_area }` or 400 "Unable to read …". #13: a new submitted line, or 400 with `data.errors[{ row, message }]`.
- #14 list item: `id`, `working_area`, `status`, `source`, `start_date`, `end_date`, `total_rows`, audit columns. #15 adds `oil_unit`, `gas_unit`, `rows[{ date, name, sot_oil, ops_oil, prod_gas }]`.
- #16 / #17 / #20 return the detail plus `replaced_rows`.
- #19: `{ working_area, start_date, end_date, days }`, nothing saved.
- File checks (#12, #13, #19, #20): required, `.xlsx` only, ≤ 5 MB.
- Not found = 404, code `04`.
- Rules: `02` §6.

---

## 3. Endpoints changed

| Endpoint | Change | PR |
|---|---|---|
| #1 Summary | Water removed (oil and gas only) | #1474 |
| #2 Top wells | `type` removed (always FIGURE) | #1474 |
| #4 / #5 | `zone9` accepted; `working_area` on every item | #1474 |
| #1 Summary | SOT / OPS read the submitted Input Target | #1512 |
| #3 Chart | SOT / OPS / `prod_gas` / RKAP / WPNB from Input Target | #1512 |
| #1–#3 | On `zone9`, `area` / `field` = a Zona 9 chip (PHSS area or PEP field) | #1524 |
| #2 Top wells | `trend` 2 decimals (was a whole number) | #1535 |
| #18 / #20 | Template and upload follow the client INPUT sheet layout | #1535 |
| #3 Chart | Every series has every date, `value` nullable | #1540 |
| #1–#3 | Range ≤ 5 years, dates 1900–2100 | #1540 |
| #2 Top wells | Gain list: gains > 0 only | #1540 |
| #13 RKAP upload | Header check (Oil B..M, Gas N..Y, Jan..Dec) | #1540 |

Existing endpoints not changed: `/dropdowns/areas`, `/dropdowns/fields` (kept for other pages).

---

## 4. Build order (as it happened)

1. 10 Nov: Bruno proposal first (#199, #200), reviewed by FE before code.
2. 11–12 Nov: Summary, Top wells, Chart (#1459) and Working Area lists (#1462).
3. 16 Nov: new design (#1474).
4. 20–22 Nov: Input Target and the report reading it (#1512).
5. 23–24 Nov: SOT / OPS preview and template (#1515), Zona 9 chips (#1524), QA fixes (#1535).
6. 25 Nov: chart full dates, range limit, QA fixes (#1540).

---

## 5. Open points for the endpoints
- G1: `version` / `is_latest` on #7 / #8 and a block on #10 for old versions, if the Product Owner keeps "newest only".
- G2: position check on Input Target writes.
- G3: empty cell = 0 on #13 / #20.
- G6: monthly / yearly chart points, if the PRD keeps it.
- G7: a user-chosen comparison period (2 new query params on #1–#3).
