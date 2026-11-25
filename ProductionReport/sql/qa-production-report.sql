/* =====================================================================================
   PRODUCTION REPORT - QUERY VERIFIKASI QA (SQL Server, SELECT saja)
   Endpoint: /api/v1/production-report/{zone9|phss|pep}/summary | top-wells | chart

   SUMBER DATA
   - Figure (default)   : well_history_phss (PHSS) + well_history_pep (PEP), 1 baris = 1 hari per sumur-zona
                          oil = kolom oil (BBLS/hari), gas = kolom gas_out (MMSCF/hari)
   - SOT / OPS / Prod.GAS: production_sot_ops_values (Input Target, hanya status 'submitted')
   - Target RKAP / WPNB : production_targets + production_target_values (submitted, versi terbaru)
   - Tab area / field   : areas + fields (aktif). PHSS dipecah per AREA, PEP dipecah per FIELD.

   RUMUS
   - Cumulative Oil/Gas  = SUM produksi harian dalam periode yang dipilih (bukan cumprod sejak awal)
   - Selected Period     = periode pembanding: panjang sama, berakhir H-1 sebelum tanggal awal
                           cmp_start = start - (end - start + 1) hari, cmp_end = start - 1 hari
   - Trend (% vs.)       = (nilai periode dipilih - nilai pembanding) / nilai pembanding x 100, 2 desimal
                           pembanding = 0 / tanpa data -> NULL (FE tampil N/A)
   - Persentase breakdown = nilai entitas / TOTAL kartu x 100, dibulatkan ke bilangan bulat
   - Sumur tanpa area/field valid tetap masuk TOTAL, tapi tidak masuk breakdown
     (makanya jumlah persen breakdown bisa < 100%)
   - Semua nilai dibulatkan 2 desimal. FE menampilkan format Indonesia (125.174,42).

   CARA PAKAI (DBeaver / SSMS)
   1. Ubah parameter di BAGIAN 0, lalu jalankan BAGIAN 0 (menyiapkan temp table #...).
      DBeaver: Execute Script (Alt+X) untuk seluruh file, atau blok BAGIAN 0 lalu Alt+X.
   2. Jalankan bagian lain yang diperlukan (1-7): blok bagiannya lalu Ctrl+Enter, atau Alt+X.
      Harus di tab editor yang SAMA (temp table hanya hidup di koneksi itu).
   Garis merah di #param / #field / #area / ... di DBeaver itu normal: temp table belum ada
   di metadata DB sebelum BAGIAN 0 dijalankan. Bukan error.
   ===================================================================================== */


/* ===================== BAGIAN 0. PARAMETER + DATA DASAR (wajib dijalankan dulu) ===================== */
-- Parameter ada di baris FROM paling bawah statement ini (tanpa DECLARE, supaya tiap statement
-- tetap jalan walau DBeaver mengeksekusinya satu per satu).
DROP TABLE IF EXISTS #param;
SELECT x.start_date,
       x.end_date,
       DATEADD(day, -(DATEDIFF(day, x.start_date, x.end_date) + 1), x.start_date) AS cmp_start,
       DATEADD(day, -1, x.start_date)                                             AS cmp_end,
       DATEDIFF(day, x.start_date, x.end_date) + 1                                AS days,
       UPPER(x.wa)                                                                AS wa,
       LOWER(LTRIM(RTRIM(x.entity)))                                              AS entity_key,
       LOWER(x.product)                                                           AS product
INTO #param
FROM (SELECT CAST('2026-10-23' AS date)    AS start_date,  -- tanggal awal di date picker
             CAST('2026-11-23' AS date)    AS end_date,    -- tanggal akhir di date picker
             -- 3 parameter di bawah hanya dipakai BAGIAN 3-6 (Top 10, Chart, Target):
             'zone9'                       AS wa,          -- 'zone9' | 'phss' | 'pep'
             CAST(NULL AS nvarchar(100))   AS entity,      -- chip area (tab PHSS) / field (tab PEP), NULL = All. Contoh: N'Mutiara'
             'oil'                         AS product      -- 'oil' | 'gas'
     ) x;

-- Master field aktif & area aktif yang field-nya aktif (area dengan field yatim tidak dihitung).
DROP TABLE IF EXISTS #field;
SELECT f.field_id AS id, LTRIM(RTRIM(f.name)) AS name, LOWER(LTRIM(RTRIM(f.name))) AS name_key,
       UPPER(LTRIM(RTRIM(f.working_area))) AS working_area
INTO #field
FROM fields f
WHERE f.deleted_at IS NULL AND f.is_active = 1;

DROP TABLE IF EXISTS #area;
SELECT a.id, LTRIM(RTRIM(a.name)) AS name, LOWER(LTRIM(RTRIM(a.name))) AS name_key, a.field_id, f.working_area
INTO #area
FROM areas a
JOIN #field f ON f.id = a.field_id
WHERE a.deleted_at IS NULL AND a.is_active = 1;

-- Daftar tab: 1 tab per nama (Mutiara ada di Northern & Southern -> tetap 1 tab "Mutiara").
DROP TABLE IF EXISTS #tab;
SELECT 'PHSS' AS working_area, name_key, MIN(name) AS name INTO #tab
FROM #area WHERE working_area = 'PHSS' AND name <> '' GROUP BY name_key
UNION ALL
SELECT 'PEP', name_key, MIN(name) FROM #field WHERE working_area = 'PEP' AND name <> '' GROUP BY name_key;

-- Semua baris history Figure dari awal periode pembanding s/d akhir periode dipilih.
-- area_tab  : tab area sumur (PHSS) -> dari wells.area_id
-- field_tab : tab field sumur (PEP) -> field milik area sumur, kalau area tidak valid, pakai wells.field_id
DROP TABLE IF EXISTS #hist;
SELECT src.source, src.well_id, w.well_name, src.prod_date,
       CASE WHEN src.prod_date >= p.start_date THEN 'CURRENT' ELSE 'COMPARE' END AS period,
       src.oil, src.gas,
       CASE WHEN src.prod_date >= p.start_date THEN src.oil ELSE 0 END AS oil_cur,
       CASE WHEN src.prod_date <  p.start_date THEN src.oil ELSE 0 END AS oil_prev,
       CASE WHEN src.prod_date >= p.start_date THEN src.gas ELSE 0 END AS gas_cur,
       CASE WHEN src.prod_date <  p.start_date THEN src.gas ELSE 0 END AS gas_prev,
       CASE WHEN a.working_area = src.source THEN a.name_key END AS area_key,
       CASE WHEN f.working_area = src.source THEN f.name_key END AS field_key
INTO #hist
FROM (
    SELECT 'PHSS' AS source, h.well_id, h.prod_date, ISNULL(h.oil, 0) AS oil, ISNULL(h.gas_out, 0) AS gas
    FROM well_history_phss h
    WHERE h.deleted_at IS NULL
    UNION ALL
    SELECT 'PEP', h.well_id, h.prod_date, ISNULL(h.oil, 0), ISNULL(h.gas_out, 0)
    FROM well_history_pep h
    WHERE h.deleted_at IS NULL
) src
JOIN wells w ON w.id = src.well_id AND w.deleted_at IS NULL
CROSS JOIN #param p
LEFT JOIN #area a  ON a.id = w.area_id
LEFT JOIN #field f ON f.id = COALESCE(a.field_id, w.field_id)
WHERE src.prod_date BETWEEN p.cmp_start AND p.end_date;

-- Baris yang masuk scope parameter wa / entity (dipakai Top 10 & Chart).
DROP TABLE IF EXISTS #scope;
SELECT h.*
INTO #scope
FROM #hist h CROSS JOIN #param p
WHERE p.wa = 'ZONE9'
   OR (p.wa = 'PHSS' AND h.source = 'PHSS' AND (p.entity_key IS NULL OR h.area_key  = p.entity_key))
   OR (p.wa = 'PEP'  AND h.source = 'PEP'  AND (p.entity_key IS NULL OR h.field_key = p.entity_key));


/* ===================== BAGIAN 1. PERIODE (cek label "Selected Period") ===================== */
SELECT start_date, end_date, days,
       cmp_start AS selected_period_start, cmp_end AS selected_period_end
FROM #param;


/* ===================== BAGIAN 2. PRODUCTION SUMMARY - FIGURE (tab Zona 9, PHSS, PEP + tiap area/field) =====================
   Baris TOTAL         = angka besar di kartu Cumulative Oil / Gas + badge "% vs. Selected".
   Baris entitas       = angka kecil breakdown di kartu (nilai . persen).
   Baris entitas juga  = angka kartu saat chip area (PHSS) / field (PEP) itu dipilih (breakdown jadi kosong).
   Contoh tab Zona 9: TOTAL = PHSS + PEP.                                                                     */
WITH rows_ AS (
    -- Zona 9: total semua sumur, breakdown PHSS / PEP
    SELECT 1 AS tab_order, 'ZONA 9' AS tab, 0 AS row_order, 'TOTAL' AS entity,
           SUM(oil_cur) oil_cur, SUM(oil_prev) oil_prev, SUM(gas_cur) gas_cur, SUM(gas_prev) gas_prev
    FROM #hist
    UNION ALL
    SELECT 1, 'ZONA 9', 1, s.source, SUM(h.oil_cur), SUM(h.oil_prev), SUM(h.gas_cur), SUM(h.gas_prev)
    FROM (VALUES ('PHSS'), ('PEP')) s(source) LEFT JOIN #hist h ON h.source = s.source
    GROUP BY s.source
    -- PHSS: total semua sumur PHSS, breakdown per area
    UNION ALL
    SELECT 2, 'PHSS', 0, 'TOTAL', SUM(oil_cur), SUM(oil_prev), SUM(gas_cur), SUM(gas_prev)
    FROM #hist WHERE source = 'PHSS'
    UNION ALL
    SELECT 2, 'PHSS', 1, t.name, SUM(h.oil_cur), SUM(h.oil_prev), SUM(h.gas_cur), SUM(h.gas_prev)
    FROM #tab t LEFT JOIN #hist h ON h.source = 'PHSS' AND h.area_key = t.name_key
    WHERE t.working_area = 'PHSS'
    GROUP BY t.name
    UNION ALL
    SELECT 2, 'PHSS', 2, '(sumur tanpa area valid - tidak tampil)', SUM(oil_cur), SUM(oil_prev), SUM(gas_cur), SUM(gas_prev)
    FROM #hist WHERE source = 'PHSS' AND area_key IS NULL
    -- PEP: total semua sumur PEP, breakdown per field
    UNION ALL
    SELECT 3, 'PEP', 0, 'TOTAL', SUM(oil_cur), SUM(oil_prev), SUM(gas_cur), SUM(gas_prev)
    FROM #hist WHERE source = 'PEP'
    UNION ALL
    SELECT 3, 'PEP', 1, t.name, SUM(h.oil_cur), SUM(h.oil_prev), SUM(h.gas_cur), SUM(h.gas_prev)
    FROM #tab t LEFT JOIN #hist h ON h.source = 'PEP' AND h.field_key = t.name_key
    WHERE t.working_area = 'PEP'
    GROUP BY t.name
    UNION ALL
    SELECT 3, 'PEP', 2, '(sumur tanpa field valid - tidak tampil)', SUM(oil_cur), SUM(oil_prev), SUM(gas_cur), SUM(gas_prev)
    FROM #hist WHERE source = 'PEP' AND field_key IS NULL
), r AS (
    SELECT tab_order, tab, row_order, entity,
           ISNULL(oil_cur, 0) oil_cur, ISNULL(oil_prev, 0) oil_prev, ISNULL(gas_cur, 0) gas_cur, ISNULL(gas_prev, 0) gas_prev
    FROM rows_
)
SELECT r.tab, r.entity,
       ROUND(r.oil_cur, 2)                                                       AS oil_bbls,
       CASE WHEN r.oil_prev = 0 THEN NULL
            ELSE ROUND((r.oil_cur - r.oil_prev) / r.oil_prev * 100, 2) END       AS oil_trend_pct,
       CASE WHEN r.row_order = 0 THEN NULL
            ELSE CAST(ROUND(r.oil_cur / NULLIF(t.oil_cur, 0) * 100, 0) AS int) END AS oil_share_pct,
       ROUND(r.gas_cur, 2)                                                       AS gas_mmscf,
       CASE WHEN r.gas_prev = 0 THEN NULL
            ELSE ROUND((r.gas_cur - r.gas_prev) / r.gas_prev * 100, 2) END       AS gas_trend_pct,
       CASE WHEN r.row_order = 0 THEN NULL
            ELSE CAST(ROUND(r.gas_cur / NULLIF(t.gas_cur, 0) * 100, 0) AS int) END AS gas_share_pct,
       ROUND(r.oil_prev, 2) AS oil_bbls_selected_period,   -- nilai pembanding (penyebut trend)
       ROUND(r.gas_prev, 2) AS gas_mmscf_selected_period
FROM r
JOIN r t ON t.tab = r.tab AND t.row_order = 0
ORDER BY r.tab_order, r.row_order, r.entity;


/* ===================== BAGIAN 2b. RINCIAN PER HARI (kalau angka BAGIAN 2 perlu ditelusuri) ===================== */
SELECT period, prod_date, source,
       COUNT(*)              AS jumlah_baris_history,
       COUNT(DISTINCT well_id) AS jumlah_sumur,
       ROUND(SUM(oil), 2)    AS oil_bbls,
       ROUND(SUM(gas), 2)    AS gas_mmscf
FROM #hist
GROUP BY period, prod_date, source
ORDER BY prod_date, source;


/* ===================== BAGIAN 3. TOP 10 RANKING (pakai parameter wa, entity, product) =====================
   Selalu data Figure. Kandidat = sumur yang punya baris di periode dipilih DAN produksinya > 0
   di periode dipilih atau di periode pembanding.
   - Production Gain     : rata-rata harian dipilih - rata-rata harian pembanding (BOPD / MMSCFD), urut terbesar
   - Highest Production  : total periode dipilih (BBLS / MMSCF), urut terbesar
   - Lowest Contribution : total periode dipilih (BBLS / MMSCF), urut terkecil (0 ikut dihitung)
   Production Gain hanya gain > 0 (setelah dibulatkan 2 desimal, PR #1540).
   Seri diurutkan nama sumur A-Z. Trend 2 desimal (PR #1535), NULL = N/A.                     */
WITH w AS (
    SELECT s.well_id, MIN(s.well_name) AS well_name,
           SUM(CASE WHEN p.product = 'gas' THEN s.gas_cur  ELSE s.oil_cur  END) AS cur,
           SUM(CASE WHEN p.product = 'gas' THEN s.gas_prev ELSE s.oil_prev END) AS prev,
           SUM(CASE WHEN s.period = 'CURRENT' THEN 1 ELSE 0 END)                AS cur_rows
    FROM #scope s CROSS JOIN #param p
    GROUP BY s.well_id
), c AS (
    SELECT w.*, w.cur / p.days AS cur_rate, w.prev / p.days AS prev_rate, p.product
    FROM w CROSS JOIN #param p
    WHERE w.cur_rows > 0 AND (w.cur > 0 OR w.prev > 0)
), ranked AS (
    SELECT 1 AS list_order, 'Production Gain' AS list,
           ROW_NUMBER() OVER (ORDER BY cur_rate - prev_rate DESC, well_name) AS rnk, well_name,
           ROUND(cur_rate - prev_rate, 2) AS value,
           CASE WHEN product = 'gas' THEN 'MMSCFD' ELSE 'BOPD' END AS unit,
           CASE WHEN prev_rate = 0 THEN NULL ELSE CAST(ROUND((cur_rate - prev_rate) / prev_rate * 100, 2) AS decimal(18, 2)) END AS trend_pct
    FROM c
    WHERE ROUND(cur_rate - prev_rate, 2) > 0
    UNION ALL
    SELECT 2, 'Highest Production', ROW_NUMBER() OVER (ORDER BY cur DESC, well_name), well_name,
           ROUND(cur, 2), CASE WHEN product = 'gas' THEN 'MMSCF' ELSE 'BBLS' END,
           CASE WHEN prev = 0 THEN NULL ELSE CAST(ROUND((cur - prev) / prev * 100, 2) AS decimal(18, 2)) END
    FROM c
    UNION ALL
    SELECT 3, 'Lowest Contribution', ROW_NUMBER() OVER (ORDER BY cur ASC, well_name), well_name,
           ROUND(cur, 2), CASE WHEN product = 'gas' THEN 'MMSCF' ELSE 'BBLS' END,
           CASE WHEN prev = 0 THEN NULL ELSE CAST(ROUND((cur - prev) / prev * 100, 2) AS decimal(18, 2)) END
    FROM c
)
SELECT list, rnk, well_name, value, unit, trend_pct
FROM ranked
WHERE rnk <= 10
ORDER BY list_order, rnk;


/* ===================== BAGIAN 4. PRODUCTION CHART - garis FIGURE (pakai parameter wa, entity) =====================
   1 titik per tanggal di periode dipilih = total produksi semua sumur hari itu (BOPD / MMSCFD).
   Query ini hanya menampilkan tanggal yang ada data. API (sejak PR #1540) mengirim SEMUA tanggal
   start..end di setiap seri; tanggal tanpa data = value null.                                           */
SELECT prod_date AS date,
       ROUND(SUM(oil), 2) AS figure_oil_bopd,
       ROUND(SUM(gas), 2) AS figure_gas_mmscfd
FROM #scope
WHERE period = 'CURRENT'
GROUP BY prod_date
ORDER BY prod_date;


/* ===================== BAGIAN 5. PRODUCTION CHART - garis SOT / OPS / Prod. GAS (Input Target) =====================
   Oil: production_sot = sot_oil, production_ops = ops_oil. Gas: hanya prod_gas (SOT/OPS gas kosong).
   Hanya baris 'submitted'. Filter chip: PHSS = nama area, PEP = nama field.                           */
SELECT v.prod_date AS date,
       ROUND(SUM(v.sot_oil), 2)  AS production_sot_bopd,
       ROUND(SUM(v.ops_oil), 2)  AS production_ops_bopd,
       ROUND(SUM(v.prod_gas), 2) AS prod_gas_mmscfd
FROM production_sot_ops_values v
JOIN production_sot_ops_inputs i ON i.id = v.production_sot_ops_input_id AND i.deleted_at IS NULL
CROSS JOIN #param p
WHERE v.status = 'submitted'
  AND v.prod_date BETWEEN p.start_date AND p.end_date
  AND (p.wa = 'ZONE9'
       OR (UPPER(v.working_area) = p.wa AND (p.entity_key IS NULL OR LOWER(LTRIM(RTRIM(v.entity_name))) = p.entity_key)))
GROUP BY v.prod_date
ORDER BY v.prod_date;


/* ===================== BAGIAN 6. PRODUCTION CHART - garis Target RKAP / WPNB =====================
   Per tahun + type + working area hanya versi submitted TERBARU (draft tidak dihitung).
   Nilai = jumlah semua area/field per bulan. API mengulang nilai bulan itu di SETIAP tanggal
   bulan tsb. dalam periode (garis tangga).                                                     */
WITH newest AS (
    SELECT t.id, t.target_year, t.type, t.working_area, t.version,
           ROW_NUMBER() OVER (PARTITION BY t.target_year, t.type, t.working_area ORDER BY t.version DESC) AS rn
    FROM production_targets t CROSS JOIN #param p
    WHERE t.deleted_at IS NULL
      AND t.status = 'submitted'
      AND t.target_year BETWEEN YEAR(p.start_date) AND YEAR(p.end_date)
      AND (p.wa = 'ZONE9' OR UPPER(t.working_area) = p.wa)
)
SELECT n.type, n.target_year, v.month,
       ROUND(SUM(v.oil), 2) AS target_oil_bopd,
       ROUND(SUM(v.gas), 2) AS target_gas_mmscfd
FROM newest n
JOIN production_target_values v ON v.production_target_id = n.id
CROSS JOIN #param p
WHERE n.rn = 1
  AND (p.entity_key IS NULL OR LOWER(LTRIM(RTRIM(v.entity_name))) = p.entity_key)
GROUP BY n.type, n.target_year, v.month
ORDER BY n.type, n.target_year, v.month;


/* ===================== BAGIAN 7. PRODUCTION SUMMARY - tombol SOT / OPS =====================
   Kartu Oil  : SOT -> SUM(sot_oil), OPS -> SUM(ops_oil)
   Kartu Gas  : SOT & OPS sama-sama SUM(prod_gas)
   Struktur baris sama dengan BAGIAN 2 (TOTAL, breakdown, trend vs periode pembanding).        */
WITH v AS (
    SELECT UPPER(v.working_area) AS source, LOWER(LTRIM(RTRIM(v.entity_name))) AS entity_key,
           CASE WHEN v.prod_date >= p.start_date THEN v.sot_oil  ELSE 0 END AS sot_cur,
           CASE WHEN v.prod_date <  p.start_date THEN v.sot_oil  ELSE 0 END AS sot_prev,
           CASE WHEN v.prod_date >= p.start_date THEN v.ops_oil  ELSE 0 END AS ops_cur,
           CASE WHEN v.prod_date <  p.start_date THEN v.ops_oil  ELSE 0 END AS ops_prev,
           CASE WHEN v.prod_date >= p.start_date THEN v.prod_gas ELSE 0 END AS gas_cur,
           CASE WHEN v.prod_date <  p.start_date THEN v.prod_gas ELSE 0 END AS gas_prev
    FROM production_sot_ops_values v
    JOIN production_sot_ops_inputs i ON i.id = v.production_sot_ops_input_id AND i.deleted_at IS NULL
    CROSS JOIN #param p
    WHERE v.status = 'submitted' AND v.prod_date BETWEEN p.cmp_start AND p.end_date
), rows_ AS (
    SELECT 1 AS tab_order, 'ZONA 9' AS tab, 0 AS row_order, 'TOTAL' AS entity,
           SUM(sot_cur) sot_cur, SUM(sot_prev) sot_prev, SUM(ops_cur) ops_cur, SUM(ops_prev) ops_prev, SUM(gas_cur) gas_cur, SUM(gas_prev) gas_prev
    FROM v
    UNION ALL
    SELECT 1, 'ZONA 9', 1, s.source, SUM(sot_cur), SUM(sot_prev), SUM(ops_cur), SUM(ops_prev), SUM(gas_cur), SUM(gas_prev)
    FROM (VALUES ('PHSS'), ('PEP')) s(source) LEFT JOIN v ON v.source = s.source
    GROUP BY s.source
    UNION ALL
    SELECT 2, 'PHSS', 0, 'TOTAL', SUM(sot_cur), SUM(sot_prev), SUM(ops_cur), SUM(ops_prev), SUM(gas_cur), SUM(gas_prev)
    FROM v WHERE source = 'PHSS'
    UNION ALL
    SELECT 2, 'PHSS', 1, t.name, SUM(sot_cur), SUM(sot_prev), SUM(ops_cur), SUM(ops_prev), SUM(gas_cur), SUM(gas_prev)
    FROM #tab t LEFT JOIN v ON v.source = 'PHSS' AND v.entity_key = t.name_key
    WHERE t.working_area = 'PHSS'
    GROUP BY t.name
    UNION ALL
    SELECT 3, 'PEP', 0, 'TOTAL', SUM(sot_cur), SUM(sot_prev), SUM(ops_cur), SUM(ops_prev), SUM(gas_cur), SUM(gas_prev)
    FROM v WHERE source = 'PEP'
    UNION ALL
    SELECT 3, 'PEP', 1, t.name, SUM(sot_cur), SUM(sot_prev), SUM(ops_cur), SUM(ops_prev), SUM(gas_cur), SUM(gas_prev)
    FROM #tab t LEFT JOIN v ON v.source = 'PEP' AND v.entity_key = t.name_key
    WHERE t.working_area = 'PEP'
    GROUP BY t.name
), r AS (
    SELECT tab_order, tab, row_order, entity,
           ISNULL(sot_cur, 0) sot_cur, ISNULL(sot_prev, 0) sot_prev, ISNULL(ops_cur, 0) ops_cur,
           ISNULL(ops_prev, 0) ops_prev, ISNULL(gas_cur, 0) gas_cur, ISNULL(gas_prev, 0) gas_prev
    FROM rows_
)
SELECT r.tab, r.entity,
       ROUND(r.sot_cur, 2) AS sot_oil,
       CASE WHEN r.sot_prev = 0 THEN NULL ELSE ROUND((r.sot_cur - r.sot_prev) / r.sot_prev * 100, 2) END AS sot_trend_pct,
       CASE WHEN r.row_order = 0 THEN NULL ELSE CAST(ROUND(r.sot_cur / NULLIF(t.sot_cur, 0) * 100, 0) AS int) END AS sot_share_pct,
       ROUND(r.ops_cur, 2) AS ops_oil,
       CASE WHEN r.ops_prev = 0 THEN NULL ELSE ROUND((r.ops_cur - r.ops_prev) / r.ops_prev * 100, 2) END AS ops_trend_pct,
       CASE WHEN r.row_order = 0 THEN NULL ELSE CAST(ROUND(r.ops_cur / NULLIF(t.ops_cur, 0) * 100, 0) AS int) END AS ops_share_pct,
       ROUND(r.gas_cur, 2) AS prod_gas,
       CASE WHEN r.gas_prev = 0 THEN NULL ELSE ROUND((r.gas_cur - r.gas_prev) / r.gas_prev * 100, 2) END AS gas_trend_pct,
       CASE WHEN r.row_order = 0 THEN NULL ELSE CAST(ROUND(r.gas_cur / NULLIF(t.gas_cur, 0) * 100, 0) AS int) END AS gas_share_pct
FROM r
JOIN r t ON t.tab = r.tab AND t.row_order = 0
ORDER BY r.tab_order, r.row_order, r.entity;
