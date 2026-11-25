# Production Report: Figma screens for each endpoint

Made on 25 Nov. Source: Figma "PHI - Latest Design" (nodes in `02-Knowledge.md` §7) and the design notes of 16–19 Nov. The endpoint numbers are from `03-Endpoint-Plan.md`.
No screenshots yet (the Figma file and the prototype artifacts are not open to this account). Add them to `img/endpoints/` later.

---

## 1. Page tabs and time range filter (PHI-2498 / 2499 / 2500)
- Tabs: Zona 9, PHSS, PEP → the `{working_area}` of every call (`zone9`, `phss`, `pep`).
- Time range: presets 1D, 1W, 1M (default), 1Y, 5Y, and a custom range → `start_date`, `end_date` on #1, #2, #3.
- The longest preset is 5Y, so the API refuses a range over 5 years (D35).

## 2. Production Summary cards (PHI-2501 / 2502 / 2503), node `16807-37247`
- Calls #1 `GET /production-report/{wa}/summary?type=` with the SOT / OPS / Figure tab.
- Card oil and card gas → `items[]` (`product` oil / gas).
- Big number → `value` + `unit`.
- Badge "vs. selected period" → `trend` (`null` = N/A).
- "Selected Period: <dates>" → `selected_period` (the comparison dates).
- Breakdown bars:
  - Zona 9: PHSS vs PEP.
  - PHSS: one bar per area (from #4 `/working-areas/phss/areas`).
  - PEP: one bar per field (from #5 `/working-areas/pep/fields`).
  - → `breakdown[]` (`entity`, `value`, `percentage`).
- No sparkline in the new design, so `chart_data` is not used.

## 3. Production chart (PHI-2504 / 2505 / 2506), node `16807-37356`
- Calls #3 `GET /production-report/{wa}/chart?product=oil|gas`.
- Oil chart: Figure, SOT, OPS, RKAP, WPNB → `production_figure`, `production_sot`, `production_ops`, `target_rkap`, `target_wpnb`.
- Gas chart: Figure, RKAP, WPNB, Prod. GAS → `production_figure`, `target_rkap`, `target_wpnb`, `prod_gas`.
- Series dropdown, default Figure + RKAP (FE only).
- Tooltip "difference" = Figure − the other series (FE computes it; every series has the same dates, D33).
- The 1Y frame shows Jan–Dec. The API sends days (D34, gap G6).

## 4. Top 10 (PHI-2507–2509 oil, PHI-2511–2513 gas), node `16807-37514`
- Calls #2 `GET /production-report/{wa}/top-wells?product=oil|gas` (no type).
- 3 lists:
  - Production Gain → `production_gain` (BOPD / MMSCFD),
  - Highest Production → `highest_production` (BBLS / MMSCF),
  - Lowest Contribution → `lowest_contribution`.
- Chips:
  - PHSS: areas from #4 `/working-areas/phss/areas`, sent as `area=`.
  - PEP: fields from #5 `/working-areas/pep/fields`, sent as `field=`.
  - Zona 9: #5 `/working-areas/zone9/fields` (PHSS areas + PEP fields, each with `working_area`), sent as `area=` or `field=` on `zone9` (#1524 resolves it).
- Treemap box size and the 1-decimal trend are FE (see `02` §1.D).

## 5. Input Target window: RKAP & WPNB tab (PHI-2804–2809)
| Screen part | Endpoint |
|---|---|
| "Input Target" button → list (Year, Type, Entity, Status) | #7 `GET /input-target/rkap-wpnb` |
| Add Data → Manual Input: grid rows | #6 `GET /input-target/entities/{phss\|pep}` |
| Save as Draft / Submit | #9 `POST /input-target/rkap-wpnb` (`status` draft / submitted) |
| Detail | #8 `GET /input-target/rkap-wpnb/{id}` |
| Edit → Save Changes | #10 `POST /input-target/rkap-wpnb/{id}/update` |
| Bulk Upload → Download template | #11 `GET /input-target/rkap-wpnb/template` |
| Bulk Upload → "Detected from file" | #12 `POST /input-target/rkap-wpnb/upload/preview` |
| Bulk Upload → Upload | #13 `POST /input-target/rkap-wpnb/upload` |

## 6. Input Target window: SOT & OPS tab (PHI-2804–2809)
| Screen part | Endpoint |
|---|---|
| List (date range, Entity, Status) | #14 `GET /input-target/sot-ops` |
| Manual Input: grid date × area / field (SOT, OPS, Prod. GAS) | #6 for the rows, #16 `POST /input-target/sot-ops` |
| Detail | #15 `GET /input-target/sot-ops/{id}` |
| Edit | #17 `POST /input-target/sot-ops/{id}/update` |
| Bulk Upload → Download template (PHSS / PEP) | #18 `GET /input-target/sot-ops/template?working_area=` |
| Bulk Upload → "Detected from file" | #19 `POST /input-target/sot-ops/upload/preview` |
| Bulk Upload → Upload | #20 `POST /input-target/sot-ops/upload` |

Notes:
- In Zona 9 the user picks the entity (PHSS / PEP) in the window. Inside PHSS or PEP it is fixed (FE).
- There is no delete and no history in the design (D20).

## Endpoints with no screen in this file
- None. Every endpoint of `03` has a screen above.
