# Production Report: test cases and test users

Test cases first, then the users for the test. Update the "Result" column after each test run.
Source of the rules: `01-Decision-Log.md` and `02-Knowledge.md`. Endpoints: `03-Endpoint-Plan.md`.

Result words:
- **Unit test**: covered by a test in `src-be/Tests` (name in brackets).
- **Pass (PR #n curl)**: curl run on a local WebApi against the dev DB; results are in the PR description.
- **QA**: checked by QA (M011 run, 25 Nov).
- **To test**: not run yet.

---

## 1. Report endpoints (#1–#5)

### 1.1 Validation (all report calls)
| # | When | Then | Result |
|---|---|---|---|
| T1 | `working_area` = `zona9` | 400 "Invalid working area, must be 'zone9', 'phss' or 'pep'" | Unit test (`TryParse_RejectsInvalidSummaryQueries`) |
| T2 | no `start_date` or no `end_date` | 400 "Both start_date and end_date are required" | Unit test (same) |
| T3 | date `2026-11-01` (not `dd-MM-yyyy`) | 400 "start_date and end_date must be in format dd-MM-yyyy" | Unit test (same) |
| T4 | start after end | 400 "start_date must not be after end_date" | Unit test (same) |
| T5 | `01-01-0001..31-12-2999` or end `31-12-9999` | 400 "start_date and end_date must be between 01-01-1900 and 31-12-2100" | Unit test (same); Pass (#1540 curl) |
| T6 | range 5 years + 1 day | 400 "The date range can be at most 5 years" | Unit test (same); Pass (#1540 curl) |
| T7 | 5Y preset, 5 years from a leap day, years 1900 / 2100 | 200; chart 1,827 points per series on 5Y | Unit test (`TryParse_AcceptsUpToFiveYearsWithinTheYearBounds`); Pass (#1540 curl) |
| T8 | summary `type` = `ACTUAL` or none | 400 "Invalid type, must be 'SOT', 'OPS' or 'FIGURE'" | Unit test (`TryParse_RejectsInvalidSummaryQueries`) |
| T9 | top-wells / chart `product` = `water` or none | 400 "Invalid product, must be 'oil' or 'gas'" | Unit test (`TryParse_RequiresOilOrGasWhenProductIsTaken`) |
| T10 | top-wells with `type=SOT` or any text | 200, FIGURE data (type ignored) | Unit test (`TryParse_WithoutTypeParam_AlwaysReadsFigure`) |

### 1.2 Period and trend
| # | Given | When | Then | Result |
|---|---|---|---|---|
| T11 | – | 01-11-2026..07-11-2026 (1W), 1 day, 10 days | `selected_period` 25-10-2026..31-10-2026; the day before; the 10 days before | Unit test (`Period_ComparesAgainstTheSameLengthRightBefore`) |
| T12 | – | 05-11-2025..05-11-2026 (1Y) | `selected_period` 04-11-2024..04-11-2025 | Unit test (same) |
| T13 | no production in the comparison period | summary / top wells | `trend: null` (FE "N/A") | Unit test (`Math_PercentChange_IsNullWithoutComparisonData_AndNeverNegativeZero`) |
| T14 | equal values | – | `trend: 0` (never `-0`) | Unit test (same) |
| T14b | – | 92 days / 93 days | summary `chart_data` daily / monthly | Unit test (`Period_SwitchesToMonthlyBucketsAfter92Days`) |

### 1.3 Summary (#1)
| # | Given | When | Then | Result |
|---|---|---|---|---|
| T15 | PHSS + PEP history | `zone9`, FIGURE | oil / gas = PHSS + PEP; breakdown PHSS, PEP | Unit test (`Summary_Zone9_SumsBothWorkingAreas_AndBreaksDownPerWorkingArea`) |
| T16 | PEP gas | `zone9` gas | added in MMSCF, no /1000 | Unit test (`Summary_Zone9Gas_AddsPhssAndPepInMmscf_WithoutConversion`) |
| T17 | duplicate area names, orphan areas | `phss` | one bar per name, orphans skipped | Unit test (`Summary_PhssAll_BreaksDownPerArea_MergingDuplicateNames_AndSkippingOrphans`) |
| T18 | a PEP well with no valid area | `pep&field=…` | counted through `wells.field_id` | Unit test (`Summary_PepField_IncludesWellsWhoseFieldComesFromTheWellRow`) |
| T19 | – | any | `items` = oil and gas only (no water) | Unit test (`Summary_ReturnsOilAndGasOnly`) |
| T20 | `area` = Mutiara / " mutiara " / Badak / Unknown | `phss` | only that area (Mutiara = both ids), unknown = 0; `breakdown: []` | Unit test (`Summary_PhssArea_FiltersToThatArea_WithEmptyBreakdown`) |
| T21 | a well without area / field | `phss` | in the card total, not in a bar; bars sum < 100% | Seen on dev (`01` §3) |
| T21b | no Input Target data | `type=SOT` / `OPS` | values 0, `trend: null` | Unit test (`Summary_SotAndOps_WithoutInputTarget_ZeroValues_NullTrend`) |
| T22 | submitted SOT / OPS input + a draft | `type=SOT` | oil = SOT oil, gas = Prod. GAS, draft not counted, trend and breakdown | Unit test (`Summary_Sot_SotOilAndProdGas_SubmittedOnly_WithTrendAndBreakdown`) |
| T23 | – | `type=OPS` | oil = OPS oil | Unit test (`Summary_Ops_ReadsOpsOil`) |
| T24 | – | `type=SOT&area=Badak` (`phss`) | only Badak, `breakdown: []` | Unit test (`Summary_AreaFilter_OnlyThatArea_NoBreakdown`) |
| T25 | – | `phss&field=Northern`, `type=SOT` | 0 (Input Target has no field rows on PHSS) | To test |

### 1.4 Top wells (#2)
| # | Given | When | Then | Result |
|---|---|---|---|---|
| T26 | wells with and without rows in the range | top-wells | only wells with a row in the range compete | Unit test (`TopWells_RanksWellsThatReportedInThePeriod`) |
| T27 | a gas-only well | `product=oil` | not in the oil lists | Unit test (`TopWells_Gas_LeavesOutWellsThatNeverProducedGas`) |
| T28 | – | any | `trend` 2 decimals | Unit test (`TopWells_TrendKeepsTwoDecimals`); Pass (#1535 curl) |
| T29 | a well that fell (DROP-01: 6 → 0) | top-wells | not in `production_gain`; every gain value > 0 | Unit test (`TopWells_RanksWellsThatReportedInThePeriod`); Pass (#1540 curl: PEP gas 17–23 Nov → `production_gain: []`) |
| T30 | the same DROP-01 | top-wells | first in `lowest_contribution`, trend −100 | Unit test (same) |
| T31 | 2 wells with the same value | – | sorted by well name A–Z | Bruno example (#199, tie HL096 / HL020) |
| T32 | `zone9` chips | `area=Badak`, `area=" mutiara"`, `area=Sangasanga`, `field=Tanjung`, `area=Unknown` | Badak / Mutiara = PHSS area; Sangasanga / Tanjung = PEP field; unknown = empty lists; no chip = both working areas | Unit test (`TopWells_Zone9Chip_IsThatWorkingAreasOwnFilter`, `TopWells_Zone9_AllChipKeepsBothWorkingAreas_ChipsDiffer_UnknownChipEmpty`) |

### 1.5 Chart (#3)
| # | Given | When | Then | Result |
|---|---|---|---|---|
| T33 | days with and without history | chart 1M | every series has the same 32 dates; no data = `null` | Unit test (`Chart_EverySeriesHasEveryDate_NullWithoutData`); Pass (#1540 curl) |
| T34 | SOT / OPS input, 2 RKAP versions (newest submitted wins) | `product=oil` | daily SOT / OPS; RKAP = monthly step of the newest submitted line | Unit test (`Chart_Oil_SotOpsDaily_RkapStepFromNewestSubmitted`) |
| T35 | – | `product=gas` | `prod_gas` filled; `production_sot` / `production_ops` all `null` | Unit test (`Chart_Gas_ProdGasOnly`) |
| T36 | – | `area=Badak` | only Badak rows | Unit test (`Chart_AreaFilter_OnlyThatArea`) |
| T37 | RKAP on PHSS, WPNB on PEP | `zone9` | both lines | Unit test (`Chart_Zone9_RkapFromPhss_WpnbFromPep`) |
| T38 | `zone9` chip | summary and chart with the same chip | same filter on both | Unit test (`SummaryAndChart_Zone9Chip_FollowTheSameFilter`) |

### 1.6 Working Area lists (#4, #5)
| # | When | Then | Result |
|---|---|---|---|
| T39 | `/working-areas/phss/areas` | active areas under active PHSS fields, one per name | Unit test (`Areas_Phss_AreActiveAreasUnderActivePhssFields_OnePerName`) |
| T40 | `/working-areas/pep/areas` | only areas under PEP fields | Unit test (`Areas_Pep_AreScopedToPepFields`) |
| T41 | `/working-areas/zone9/areas` | PHSS areas then PEP areas, each with `working_area` | Unit test (`Areas_Zone9_ArePhssAreasThenPepAreas_EachTaggedWithItsWorkingArea`) |
| T42 | `/working-areas/zone9/fields` | PHSS areas then PEP fields (the Zona 9 chips) | Unit test (`Fields_Zone9_AreTheZona9Chips_PhssAreasThenPepFields`) |
| T43 | `/working-areas/bogus/areas` | 400 "Invalid working area, must be 'zone9', 'phss' or 'pep'" | To test |

---

## 2. Input Target (#6–#20)

### 2.1 RKAP / WPNB
| # | Given | When | Then | Result |
|---|---|---|---|---|
| T44 | WF rows inactive in the master data | `GET /entities/phss`, `/entities/pep` | active PHSS areas, active PEP fields (no WF) | Unit test (`Entities_PhssAreasAndPepFields_WithoutWaterFlood`) |
| T45 | a line RKAP 2099 PHSS | create the same key again | a new line; list shows the newest first | Unit test (`Create_SameKeyTwice_AddsNewLine_NewestFirst`); Pass (#1512 curl) |
| T46 | – | `oil` with 11 values, or a negative value | 400 "… must have 12 values (Jan..Dec)" / "… must be a number >= 0" | Unit test (`Create_BadMonths_Rejected`) |
| T47 | – | submit with some areas missing | 400 "rows must include every PHSS area: missing …"; a draft with some rows = 200 | Unit test (`Submit_WithoutEveryArea_Rejected_DraftMayBePartial`); Pass (#1512 curl #16–#21) |
| T48 | an older line | update it | 200 (every line can be edited, G1) | Unit test (`Update_OlderLine_IsEditableToo`) |
| T49 | a submitted line | update with `status: draft` | 400 | Unit test (`Update_SubmittedBackToDraft_Rejected`) |
| T50 | a draft line | update with new rows and `status: submitted` | same id, rows replaced, submitted | Unit test (`Update_OverwritesTheSameLine_AndSubmitsDraft`) |
| T51 | lines RKAP 2099 PHSS and WPNB 2099 PHSS | move the RKAP line to WPNB 2099 PHSS | 409 "WPNB 2099 PHSS already exists; add a new line there instead" | Unit test (`Update_MoveOntoExistingKey_Conflict`) |
| T52 | – | move a line to a free key | 200; the other lines stay | Unit test (`Update_MoveToFreeKey_LeavesTheOtherLineBehind`) |
| T53 | – | `GET /rkap-wpnb/{unknown id}` | 404 | Unit test (`Detail_UnknownId_NotFound`) |
| T54 | – | download template | one sheet "Target", header and names empty | Unit test (`Template_OneSheet_HeaderAndNamesEmpty`) |
| T55 | a filled template | upload | a new submitted line, `source` `bulk_upload` | Unit test (`Upload_FilledTemplate_SavedAsNewSubmittedLine`) |
| T56 | bad cells | upload | 400 with `errors[{ row, message }]`, nothing saved | Unit test (`Upload_BadCells_RejectedWithRowErrors_NothingSaved`) |
| T57 | a file without the Gas block | upload | 400 "Row 5 must have Gas over N..Y with Jan..Dec under it …", count of lines unchanged | Unit test (`Upload_WithoutGasColumns_FileError_NothingSaved`); Pass (#1540 curl) |
| T58 | B1..B3 filled | preview | `{ target_year, type, working_area }`, nothing saved | Unit test (`Preview_FilledHeader_ReturnsYearTypeEntity_SavesNothing`) |
| T59 | B1..B3 empty | preview | 400 "Unable to read year, type, working area" | Unit test (`Preview_Unreadable_NamesWhatIsMissing`) |
| T60 | a `.txt` renamed to `.xlsx` | upload | 400 "The file is not a valid .xlsx workbook" | Unit test (`Upload_NotAWorkbook_FileError`) |
| T61 | – | a `.csv` file / a 6 MB file / no file | 400 "Only .xlsx files are accepted" / "larger than 5 MB" / "File is required" | To test |

### 2.2 SOT / OPS
| # | Given | When | Then | Result |
|---|---|---|---|---|
| T62 | – | create with rows 01..03-01-2099 | `start_date` / `end_date` follow the rows | Unit test (`SotOps_Create_RangeFollowsRows`); Pass (#1512 curl) |
| T63 | a submitted input A (01..03) | submit input B with 02-01 | A keeps 01 and 03; `replaced_rows` 1; an input with no days left is soft-deleted | Unit test (`SotOps_Submit_ReplacesDays_ShrinksAndDropsOlderInputs`) |
| T64 | a draft on a clashing day | save draft, then submit | the draft replaces nothing until it is submitted | Unit test (`SotOps_Draft_TouchesNothing_UntilItIsSubmitted`) |
| T65 | a submitted input | update to draft | 400 | Unit test (`SotOps_SubmittedBackToDraft_Rejected`) |
| T66 | an input | update its own rows | rows replaced, own rows not counted in `replaced_rows` | Unit test (`SotOps_Update_ReplacesOwnRows_WithoutCountingThemAsReplaced`) |
| T67 | – | the same name + date twice | 400 "… appears more than once" | Unit test (`SotOps_DuplicateNameAndDate_Rejected`) |
| T68 | drafts and submitted inputs | list `status=draft` | drafts only | Unit test (`SotOps_ListFiltersByStatus`) |
| T69 | – | range of 367 days | 400 "The range can be at most 366 days" | To test |
| T70 | – | template without param / `phss` / `pep` / `zone9` | 2 sheets / sheet PHSS / sheet PEP / 400 | Unit test (`SotOps_Template_OneSheetPerEntity_BlockPerName`, `SotOps_TemplatePerEntity_OneSheet_AndUploadsAsIs`); Pass (#1535 curl) |
| T71 | a filled PEP sheet (client INPUT data 24..26-12-2025) | preview | 200, `days` 3, nothing saved | Unit test (`SotOps_Preview_EntityAndDates_ValuesLeftToUpload_SavesNothing`); Pass (#1535 curl) |
| T72 | no readable date / both sheets filled | preview | 400 "Unable to read dates" / "Fill only one sheet (PHSS or PEP) per upload" | Unit test (`SotOps_Preview_NoReadableDate_Or_TwoSheets_Rejected`) |
| T73 | a filled sheet | upload | one submitted input; clashing submitted days replaced | Unit test (`SotOps_Upload_FilledSheet_BecomesOneSubmittedInput`, `SotOps_Upload_ReplacesClashingSubmittedDays`) |
| T74 | bad cells | upload | 400 with row errors, nothing saved | Unit test (`SotOps_Upload_BadCells_RejectedWithRowErrors_NothingSaved`) |
| T75 | the client INPUT header (upper case, name in every cell, no merge) | upload | accepted | Unit test (`SotOps_Upload_InputSheetHeader_UppercaseNameInEveryCell`) |
| T76 | a template of the old layout | upload | 400 (download the template again) | Pass (#1535 curl) |
| T77 | one area filled for a date, the other cells empty | upload | the other areas of that date become 0 and replace their old values (G3) | Pass (#1512 curl: `replaced_rows` 2) |

### 2.3 Access
| # | User | When | Then | Result |
|---|---|---|---|---|
| T78 | Production Operations member | list / create / upload | 200 | Pass (#1512 curl) |
| T79 | SDA member | list | 403 code `03` "Input Target is only available to the Production Operations department" | To test |
| T80 | Senior Manager (any department) | list | 200 (view) | To test |
| T81 | Senior Manager | create | 403 "Only the Production Operations department can change Input Target data", unless the SM picked Production Operations (G2) | To test |

---

## 3. QA run (25 Nov) and SQL check

- QA module M011: 93 test cases. 3 automated fails, all FE (PHI-3008: gas chart `prod_gas` and legend).
- QA findings fixed in #1540: tooltip / X axis had only Figure dates (now every date), RKAP upload without Gas was accepted, Top 10 gain listed values ≤ 0.
- QA questions answered without code: data on dev (seeds, test wells), preview does not check names (G4), chart per day (G6).
- `sql/qa-production-report.sql`: SELECT-only script for QA to check the numbers (summary, breakdown, Top 10, chart, RKAP / WPNB, SOT / OPS). It matched the API 100% on 23 Nov (1M 23-10..23-11-2026 + the 2099 data). Updated on 25 Nov for #1535 (trend 2 decimals) and #1540 (gain > 0). Set the parameters in "BAGIAN 0" first.

---

## 4. Test users

Dev users from `mock_auth_sessions` (login `POST /api/v1/auth/login` with the user name; the local password is in the team notes, not here).

| User | Department / role | Use |
|---|---|---|
| `PHIRBAC.ROLE.PO.MEMBER` | Production Operations, member | Input Target write and read (#1512, #1515 curl) |
| `PHIRBAC.ROLE.SM` | Senior Manager | Input Target view. **Careful:** a login on dev clears `users.department` (the SM picks a department at each login); call `POST /api/v1/users/me/department` before other calls |
| `phirbac.role.sda2.member` | SDA 2, member | Report view; Input Target 403 |

Notes:
- curl needs `Authorization: Bearer <token>` (the word `Bearer` is required; Swagger adds it itself).
- A local WebApi for curl: turn off the jobs (`Quartz__Enabled=false`, `DataScienceSchedule__Enabled=false`, `RedisStreamsConfig__Enabled=false`).
- Write tests (create / upload) use year 2099 so they never touch real targets.
