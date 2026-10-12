-- ============================================================
--  MEDICARE PHYSICIAN & PRACTITIONER ANALYTICS
--  Source: CMS Medicare Physician & Other Practitioners
--          by Provider and Service (2023)
--  Scope:  Illinois Psychiatry Providers (2023 source file only)
--  Author: Michal Kuderski
--  DB:     PostgreSQL
--
--  DATA GRAIN: one published aggregate row per NPI x HCPCS x place.
--  Not individual claims. tot_benes is distinct within a row only;
--  SUM(tot_benes) can count a person more than once. All summed
--  beneficiary outputs are named *_approx and are not patient costs.
--  Primary comparison metric: Medicare payment per service unit.
--  Totals reconstructed from rounded averages may differ slightly
--  from underlying claims. Higher payment does not prove inefficiency.
--  Update COPY path to a local 2023 file. PostgreSQL server-side COPY
--  needs file access; in psql use \copy for a client-local file instead.
-- ============================================================


-- ============================================================
-- SECTION 1: SCHEMA SETUP
-- ============================================================
-- Run in a dedicated project database after reviewing this script.
-- A separate schema keeps rebuild operations away from unrelated tables.
CREATE SCHEMA IF NOT EXISTS portfolio_medicare;
SET search_path TO portfolio_medicare, public;

-- Rebuilding drops the project's existing tables and views.
DROP TABLE IF EXISTS portfolio_medicare.utilization  CASCADE;
DROP TABLE IF EXISTS portfolio_medicare.hcpcs_codes  CASCADE;
DROP TABLE IF EXISTS portfolio_medicare.providers    CASCADE;

-- ------------------------------------------------------------
-- 1A. PROVIDERS
--     One row per unique rendering provider (NPI).
--     NPI is the CMS-assigned unique identifier from NPPES.
--     entity_type distinguishes individual clinicians ('I')
--     from organizations ('O') -- affects name field logic.
-- ------------------------------------------------------------
CREATE TABLE providers (
    npi                     BIGINT          PRIMARY KEY,
    last_org_name           VARCHAR(100),
    first_name              VARCHAR(50),
    middle_initial          CHAR(1),
    credentials             VARCHAR(50),
    entity_type             CHAR(1),        -- 'I' = Individual, 'O' = Organization
    street_1                VARCHAR(100),
    street_2                VARCHAR(100),
    city                    VARCHAR(50),
    state                   CHAR(2),
    state_fips              SMALLINT,
    zip5                    CHAR(5),
    ruca_code               NUMERIC(4,1),
    ruca_description        VARCHAR(100),
    country                 CHAR(2),
    provider_type           VARCHAR(100),   -- Specialty (e.g. "Psychiatry")
    medicare_participates   CHAR(1)         -- 'Y' = accepts Medicare assignment
);

-- ------------------------------------------------------------
-- 1B. HCPCS_CODES
--     Reference/lookup table for procedure codes.
--     One row per unique HCPCS code.
--     drug_indicator = 'Y' means the code appears on CMS
--     Part B Drug ASP file -- reimbursement logic differs.
-- ------------------------------------------------------------
CREATE TABLE hcpcs_codes (
    hcpcs_cd        VARCHAR(10)     PRIMARY KEY,
    hcpcs_desc      VARCHAR(256),
    drug_indicator  CHAR(1)         -- 'Y' = Part B Drug, 'N' = Professional service
);

-- ------------------------------------------------------------
-- 1C. UTILIZATION  (Fact Table)
--     One row per provider x HCPCS code x place of service.
--     All volume and payment columns live here.
--
--     KEY PAYMENT FIELD DEFINITIONS (per CMS Data Dictionary):
--       avg_submitted_charge    -- Provider's submitted charge; not Medicare spending.
--       avg_medicare_allowed    -- CMS fee schedule allowed amount; includes
--                                  Medicare's share + beneficiary deductible/coinsurance.
--       avg_medicare_payment    -- Average Medicare payment per service
--                                  after deductibles and coinsurance are removed.
--                                  This is Medicare payment, not total provider revenue.
--       avg_medicare_standardized -- Geography-adjusted payment; removes regional
--                                  wage differences. Use for cross-market comparisons.
-- ------------------------------------------------------------
CREATE TABLE utilization (
    util_id                     SERIAL          PRIMARY KEY,
    npi                         BIGINT          NOT NULL REFERENCES providers(npi),
    hcpcs_cd                    VARCHAR(10)     NOT NULL REFERENCES hcpcs_codes(hcpcs_cd),
    place_of_service            CHAR(1),        -- 'F' = Facility, 'O' = Office/Non-Facility
    tot_benes                   INTEGER,        -- Distinct Medicare beneficiaries served
    tot_srvcs                   NUMERIC(12,2),  -- Total service units rendered
    tot_bene_day_srvcs          NUMERIC(12,2),  -- De-duplicated beneficiary/day count
    avg_submitted_charge        NUMERIC(12,2),
    avg_medicare_allowed        NUMERIC(12,2),
    avg_medicare_payment        NUMERIC(12,2),
    avg_medicare_standardized   NUMERIC(12,2)
);

-- Indexes to support JOIN and filter performance
CREATE INDEX idx_util_npi      ON utilization(npi);
CREATE INDEX idx_util_hcpcs    ON utilization(hcpcs_cd);
CREATE INDEX idx_prov_state    ON providers(state);
CREATE INDEX idx_prov_type     ON providers(provider_type);


-- ============================================================
-- SECTION 2: DATA IMPORT
-- ============================================================
-- Import the raw CSV into a staging table first, then populate
-- the normalized tables. This avoids data type conflicts on
-- import and lets us inspect raw values before transformation.

-- ------------------------------------------------------------
-- 2A. STAGING TABLE (mirrors CSV structure exactly)
-- ------------------------------------------------------------
CREATE TEMP TABLE staging_raw (
    Rndrng_NPI                  TEXT,
    Rndrng_Prvdr_Last_Org_Name  TEXT,
    Rndrng_Prvdr_First_Name     TEXT,
    Rndrng_Prvdr_MI             TEXT,
    Rndrng_Prvdr_Crdntls        TEXT,
    Rndrng_Prvdr_Ent_Cd         TEXT,
    Rndrng_Prvdr_St1            TEXT,
    Rndrng_Prvdr_St2            TEXT,
    Rndrng_Prvdr_City           TEXT,
    Rndrng_Prvdr_State_Abrvtn   TEXT,
    Rndrng_Prvdr_State_FIPS     TEXT,
    Rndrng_Prvdr_Zip5           TEXT,
    Rndrng_Prvdr_RUCA           TEXT,
    Rndrng_Prvdr_RUCA_Desc      TEXT,
    Rndrng_Prvdr_Cntry          TEXT,
    Rndrng_Prvdr_Type           TEXT,
    Rndrng_Prvdr_Mdcr_Prtcptg_Ind TEXT,
    HCPCS_Cd                    TEXT,
    HCPCS_Desc                  TEXT,
    HCPCS_Drug_Ind              TEXT,
    Place_Of_Srvc               TEXT,
    Tot_Benes                   TEXT,
    Tot_Srvcs                   TEXT,
    Tot_Bene_Day_Srvcs          TEXT,
    Avg_Sbmtd_Chrg              TEXT,
    Avg_Mdcr_Alowd_Amt          TEXT,
    Avg_Mdcr_Pymt_Amt           TEXT,
    Avg_Mdcr_Stdzd_Amt          TEXT
);

-- ------------------------------------------------------------
-- 2B. LOAD CSV INTO STAGING
--     Update the file path to match your local environment.
--     HEADER skips the first row. CSV handles quoted fields.
-- ------------------------------------------------------------
COPY staging_raw
FROM '/your/path/to/Medicare_Physician_Other_Practitioners_by_Provider_and_Service_2023.csv'
WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');

-- Quick row count to verify load
-- SELECT COUNT(*) FROM staging_raw;

-- ------------------------------------------------------------
-- 2C. POPULATE NORMALIZED TABLES FROM STAGING
--     Filter to Illinois Psychiatry at this stage.
--     DISTINCT ON prevents duplicate NPIs when the same
--     provider appears across multiple service rows.
-- ------------------------------------------------------------

-- Providers (Illinois Psychiatry only)
INSERT INTO providers
SELECT DISTINCT ON (Rndrng_NPI)
    Rndrng_NPI::BIGINT,
    Rndrng_Prvdr_Last_Org_Name,
    Rndrng_Prvdr_First_Name,
    NULLIF(Rndrng_Prvdr_MI, ''),
    NULLIF(Rndrng_Prvdr_Crdntls, ''),
    Rndrng_Prvdr_Ent_Cd,
    Rndrng_Prvdr_St1,
    NULLIF(Rndrng_Prvdr_St2, ''),
    Rndrng_Prvdr_City,
    Rndrng_Prvdr_State_Abrvtn,
    Rndrng_Prvdr_State_FIPS::SMALLINT,
    Rndrng_Prvdr_Zip5,
    NULLIF(Rndrng_Prvdr_RUCA, '')::NUMERIC(4,1),
    Rndrng_Prvdr_RUCA_Desc,
    Rndrng_Prvdr_Cntry,
    Rndrng_Prvdr_Type,
    Rndrng_Prvdr_Mdcr_Prtcptg_Ind
FROM staging_raw
WHERE Rndrng_Prvdr_State_Abrvtn = 'IL'
  AND Rndrng_Prvdr_Type = 'Psychiatry'
ORDER BY Rndrng_NPI;

-- HCPCS reference codes (for codes appearing in the IL Psychiatry cohort)
INSERT INTO hcpcs_codes
SELECT DISTINCT
    HCPCS_Cd,
    HCPCS_Desc,
    HCPCS_Drug_Ind
FROM staging_raw
WHERE Rndrng_Prvdr_State_Abrvtn = 'IL'
  AND Rndrng_Prvdr_Type = 'Psychiatry'
ON CONFLICT (hcpcs_cd) DO NOTHING;

-- Utilization fact rows (Illinois Psychiatry only)
INSERT INTO utilization (
    npi, hcpcs_cd, place_of_service,
    tot_benes, tot_srvcs, tot_bene_day_srvcs,
    avg_submitted_charge, avg_medicare_allowed,
    avg_medicare_payment, avg_medicare_standardized
)
SELECT
    Rndrng_NPI::BIGINT,
    HCPCS_Cd,
    Place_Of_Srvc,
    NULLIF(Tot_Benes, '')::INTEGER,
    NULLIF(Tot_Srvcs, '')::NUMERIC(12,2),
    NULLIF(Tot_Bene_Day_Srvcs, '')::NUMERIC(12,2),
    NULLIF(Avg_Sbmtd_Chrg, '')::NUMERIC(12,2),
    NULLIF(Avg_Mdcr_Alowd_Amt, '')::NUMERIC(12,2),
    NULLIF(Avg_Mdcr_Pymt_Amt, '')::NUMERIC(12,2),
    NULLIF(Avg_Mdcr_Stdzd_Amt, '')::NUMERIC(12,2)
FROM staging_raw
WHERE Rndrng_Prvdr_State_Abrvtn = 'IL'
  AND Rndrng_Prvdr_Type = 'Psychiatry';


-- ============================================================
-- SECTION 3: KPI QUERIES
-- ============================================================


-- ------------------------------------------------------------
-- QUERY 3.1
-- WHICH SPECIALTIES GENERATE THE HIGHEST TOTAL MEDICARE SPENDING?
--
-- Logic: Total Medicare payment = avg_medicare_payment * tot_srvcs
-- This reconstructs payment totals from published per-service averages.
-- We also calculate total allowed amount and submitted charges
-- to show the full reimbursement funnel.
-- ------------------------------------------------------------

SELECT
    p.provider_type                                         AS specialty,
    COUNT(DISTINCT p.npi)                                   AS provider_count,
    SUM(u.tot_srvcs)                                        AS total_services,
    SUM(u.tot_benes)                                        AS sum_benes_approx,

    -- Total dollars CMS actually paid out
    ROUND(SUM(u.avg_medicare_payment * u.tot_srvcs), 2)     AS total_medicare_payment,

    -- Total allowed (Medicare payment + beneficiary cost-sharing)
    ROUND(SUM(u.avg_medicare_allowed * u.tot_srvcs), 2)     AS total_medicare_allowed,

    -- Total billed (providers' submitted charges — not a true cost figure)
    ROUND(SUM(u.avg_submitted_charge * u.tot_srvcs), 2)     AS total_submitted_charges,

    -- Payment-to-allowed ratio: how much of allowed amount CMS covered
    -- (the remainder is not Medicare payment; do not call it unpaid revenue)
    ROUND(
        SUM(u.avg_medicare_payment * u.tot_srvcs) /
        NULLIF(SUM(u.avg_medicare_allowed * u.tot_srvcs), 0) * 100,
    1)                                                      AS pct_allowed_paid_by_medicare

FROM utilization u
JOIN providers p ON u.npi = p.npi

GROUP BY p.provider_type
ORDER BY total_medicare_payment DESC;


-- ------------------------------------------------------------
-- QUERY 3.2
-- AVERAGE MEDICARE PAYMENT PER SERVICE BY SPECIALTY
--
-- Uses a CTE to pre-aggregate at the specialty level, then
-- calculates per-service and per-beneficiary averages.
-- Includes standardized payment for geographic comparability.
-- ------------------------------------------------------------

WITH specialty_totals AS (
    -- Aggregate raw payment and volume by specialty
    SELECT
        p.provider_type                                         AS specialty,
        COUNT(DISTINCT p.npi)                                   AS provider_count,
        SUM(u.tot_srvcs)                                        AS total_services,
        SUM(u.tot_benes)                                        AS sum_benes_approx,
        SUM(u.avg_medicare_payment     * u.tot_srvcs)           AS total_payment,
        SUM(u.avg_medicare_allowed     * u.tot_srvcs)           AS total_allowed,
        SUM(u.avg_medicare_standardized * u.tot_srvcs)          AS total_standardized
    FROM utilization u
    JOIN providers p ON u.npi = p.npi
    GROUP BY p.provider_type
)

SELECT
    specialty,
    provider_count,
    total_services,
    sum_benes_approx,

    -- Average actual payment per service unit
    ROUND(total_payment / NULLIF(total_services, 0), 2)         AS avg_payment_per_service,

    -- Average allowed amount per service (includes patient cost-sharing)
    ROUND(total_allowed / NULLIF(total_services, 0), 2)         AS avg_allowed_per_service,

    -- Geography-adjusted payment per service (best for cross-region comparison)
    ROUND(total_standardized / NULLIF(total_services, 0), 2)    AS avg_standardized_per_service,

    -- Cost per beneficiary (population-level efficiency metric)
    ROUND(total_payment / NULLIF(sum_benes_approx, 0), 2)    AS avg_payment_per_bene_approx_approx

FROM specialty_totals
ORDER BY avg_payment_per_service DESC;


-- ------------------------------------------------------------
-- QUERY 3.3
-- WHICH PROVIDERS ARE OUTLIERS IN PAYMENT PER SERVICE
-- WITHIN THEIR SPECIALTY?
--
-- Uses a window function to compute specialty-level averages
-- alongside each provider's individual metrics, then flags
-- providers whose per-service payment deviates significantly.
-- A subquery filters to outliers only for the final output.
-- ------------------------------------------------------------

WITH provider_metrics AS (
    -- Individual provider-level payment per service
    SELECT
        p.npi,
        p.first_name,
        p.last_org_name,
        p.credentials,
        p.city,
        p.provider_type                                                 AS specialty,
        SUM(u.tot_srvcs)                                                AS total_services,
        SUM(u.tot_benes)                                                AS sum_benes_approx,
        ROUND(SUM(u.avg_medicare_payment * u.tot_srvcs), 2)             AS total_payment,

        -- Provider's own payment per service
        ROUND(
            SUM(u.avg_medicare_payment * u.tot_srvcs) /
            NULLIF(SUM(u.tot_srvcs), 0),
        2)                                                              AS provider_pay_per_svc,

        -- Specialty average payment per service (window function over specialty group)
        ROUND(
            SUM(SUM(u.avg_medicare_payment * u.tot_srvcs)) OVER (PARTITION BY p.provider_type) /
            NULLIF(SUM(SUM(u.tot_srvcs)) OVER (PARTITION BY p.provider_type), 0),
        2)                                                              AS specialty_avg_pay_per_svc

    FROM utilization u
    JOIN providers p ON u.npi = p.npi
    GROUP BY p.npi, p.first_name, p.last_org_name, p.credentials, p.city, p.provider_type
),

-- Add deviation from specialty mean and rank within specialty
ranked_providers AS (
    SELECT
        *,
        -- Absolute dollar deviation from specialty average
        ROUND(provider_pay_per_svc - specialty_avg_pay_per_svc, 2)     AS deviation_from_avg,

        -- Percent deviation from specialty average
        ROUND(
            (provider_pay_per_svc - specialty_avg_pay_per_svc) /
            NULLIF(specialty_avg_pay_per_svc, 0) * 100,
        1)                                                              AS pct_deviation,

        -- Rank within specialty (highest payment per service = rank 1)
        RANK() OVER (
            PARTITION BY specialty
            ORDER BY provider_pay_per_svc DESC
        )                                                               AS specialty_rank
    FROM provider_metrics
)

-- Final output: filter to providers who deviate > 50% from specialty mean
-- and have at least 10 services (low-volume providers can appear as outliers by chance)
SELECT
    specialty,
    specialty_rank,
    npi,
    CONCAT(first_name, ' ', last_org_name)  AS provider_name,
    credentials,
    city,
    total_services,
    sum_benes_approx,
    total_payment,
    provider_pay_per_svc,
    specialty_avg_pay_per_svc,
    deviation_from_avg,
    pct_deviation,
    CASE
        WHEN pct_deviation > 50  THEN 'HIGH OUTLIER'
        WHEN pct_deviation < -50 THEN 'LOW OUTLIER'
        ELSE 'Within Range'
    END                                     AS outlier_flag

FROM ranked_providers
WHERE ABS(pct_deviation) > 50
  AND total_services >= 10
ORDER BY specialty, pct_deviation DESC;


-- ------------------------------------------------------------
-- QUERY 3.4
-- WHICH PROCEDURES (HCPCS CODES) DRIVE THE HIGHEST
-- AGGREGATE MEDICARE SPENDING?
--
-- Identifies the top cost drivers at the procedure level.
-- Distinguishes drug codes from professional service codes,
-- as these follow fundamentally different pricing mechanisms.
-- Uses a subquery to pre-calculate procedure totals, then
-- ranks them and shows concentration (top N % of spend).
-- ------------------------------------------------------------

WITH procedure_spend AS (
    SELECT
        h.hcpcs_cd,
        h.hcpcs_desc,
        h.drug_indicator,
        COUNT(DISTINCT u.npi)                                           AS provider_count,
        SUM(u.tot_benes)                                                AS sum_benes_approx,
        SUM(u.tot_srvcs)                                                AS total_services,
        ROUND(SUM(u.avg_medicare_payment  * u.tot_srvcs), 2)           AS total_payment,
        ROUND(SUM(u.avg_medicare_allowed  * u.tot_srvcs), 2)           AS total_allowed,
        ROUND(SUM(u.avg_submitted_charge  * u.tot_srvcs), 2)           AS total_submitted,

        -- Per-service cost benchmark
        ROUND(
            SUM(u.avg_medicare_payment * u.tot_srvcs) /
            NULLIF(SUM(u.tot_srvcs), 0),
        2)                                                              AS avg_payment_per_svc

    FROM utilization u
    JOIN hcpcs_codes h ON u.hcpcs_cd = h.hcpcs_cd
    GROUP BY h.hcpcs_cd, h.hcpcs_desc, h.drug_indicator
)

SELECT
    RANK() OVER (ORDER BY total_payment DESC)           AS cost_rank,
    hcpcs_cd,
    hcpcs_desc,
    CASE drug_indicator
        WHEN 'Y' THEN 'Part B Drug (ASP-based)'
        ELSE           'Professional Service'
    END                                                 AS code_type,
    provider_count,
    sum_benes_approx,
    total_services,
    total_payment,
    avg_payment_per_svc,

    -- Running cumulative share of total spend (spending concentration)
    ROUND(
        SUM(total_payment) OVER (ORDER BY total_payment DESC) /
        SUM(total_payment) OVER () * 100,
    1)                                                  AS cumulative_pct_of_spend

FROM procedure_spend
ORDER BY total_payment DESC
LIMIT 25;  -- Top 25 procedures by Medicare spend


-- ------------------------------------------------------------
-- QUERY 3.5
-- PAYMENT-PER-SERVICE VARIATION WITHIN SPECIALTY
-- Uses unweighted provider-level distribution statistics, unlike Q3.3's
-- service-weighted specialty mean. These are descriptive screens, not
-- risk-adjusted efficiency, quality, fraud, or clinical-acuity measures.
-- ------------------------------------------------------------
WITH provider_metrics AS (
    SELECT
        p.npi,
        CONCAT_WS(' ', p.first_name, p.last_org_name) AS provider_name,
        p.city,
        p.provider_type AS specialty,
        SUM(u.tot_srvcs) AS total_services,
        SUM(u.tot_benes) AS sum_benes_approx,
        SUM(u.avg_medicare_payment * u.tot_srvcs) AS total_payment,
        SUM(u.avg_medicare_payment * u.tot_srvcs)
            / NULLIF(SUM(u.tot_srvcs), 0) AS payment_per_service
    FROM utilization u
    JOIN providers p ON p.npi = u.npi
    GROUP BY p.npi, p.first_name, p.last_org_name, p.city, p.provider_type
    HAVING SUM(u.tot_srvcs) >= 10
), specialty_stats AS (
    SELECT
        specialty,
        AVG(payment_per_service) AS mean_pay_per_svc,
        STDDEV_SAMP(payment_per_service) AS stddev_pay_per_svc,
        PERCENTILE_CONT(0.5) WITHIN GROUP
            (ORDER BY payment_per_service) AS median_pay_per_svc,
        PERCENTILE_CONT(0.25) WITHIN GROUP
            (ORDER BY payment_per_service) AS p25,
        PERCENTILE_CONT(0.75) WITHIN GROUP
            (ORDER BY payment_per_service) AS p75
    FROM provider_metrics
    GROUP BY specialty
)
SELECT
    pm.specialty, pm.npi, pm.provider_name, pm.city,
    pm.total_services, pm.sum_benes_approx,
    ROUND(pm.total_payment, 2) AS total_payment,
    ROUND(pm.payment_per_service, 2) AS payment_per_service,
    ROUND(ss.mean_pay_per_svc, 2) AS specialty_mean,
    ROUND(ss.median_pay_per_svc::NUMERIC, 2) AS specialty_median,
    ROUND(ss.p25::NUMERIC, 2) AS specialty_p25,
    ROUND(ss.p75::NUMERIC, 2) AS specialty_p75,
    ROUND((pm.payment_per_service - ss.mean_pay_per_svc)
        / NULLIF(ss.stddev_pay_per_svc, 0), 2) AS z_score,
    CASE
        WHEN pm.payment_per_service > ss.p75 THEN 'Above IQR (Higher Payment)'
        WHEN pm.payment_per_service < ss.p25 THEN 'Below IQR (Lower Payment)'
        ELSE 'Within IQR (Typical)'
    END AS payment_band
FROM provider_metrics pm
JOIN specialty_stats ss ON ss.specialty = pm.specialty
ORDER BY pm.specialty, pm.payment_per_service DESC;

-- ------------------------------------------------------------
-- QUERY 3.6
-- TELEPHONE-CODED SERVICE SHARE BY PROVIDER CITY
-- Codes 99441-99443 identify telephone-coded services, not all telehealth.
-- Denominator: all published service units for psychiatry providers in
-- that city. Provider city is a billing-provider attribute, not patient
-- residence. Keep the provider counts and volumes next to percentages.
-- ------------------------------------------------------------
WITH city_services AS (
    SELECT
        INITCAP(TRIM(p.city)) AS city,
        COUNT(DISTINCT p.npi) AS total_provider_count,
        COUNT(DISTINCT p.npi) FILTER (
            WHERE u.hcpcs_cd IN ('99441', '99442', '99443')
        ) AS telephone_provider_count,
        SUM(u.tot_srvcs) AS total_service_units,
        COALESCE(SUM(u.tot_srvcs) FILTER (
            WHERE u.hcpcs_cd IN ('99441', '99442', '99443')
        ), 0) AS telephone_service_units,
        COALESCE(SUM(u.avg_medicare_payment * u.tot_srvcs) FILTER (
            WHERE u.hcpcs_cd IN ('99441', '99442', '99443')
        ), 0) AS telephone_medicare_payment
    FROM utilization u
    JOIN providers p ON p.npi = u.npi
    WHERE p.state = 'IL' AND p.provider_type = 'Psychiatry'
    GROUP BY INITCAP(TRIM(p.city))
)
SELECT
    city, total_provider_count, telephone_provider_count,
    total_service_units, telephone_service_units,
    ROUND(telephone_medicare_payment, 2) AS telephone_medicare_payment,
    ROUND(100.0 * telephone_service_units
        / NULLIF(total_service_units, 0), 1) AS telephone_service_pct
FROM city_services
WHERE telephone_service_units > 0
ORDER BY telephone_service_units DESC, city;


-- ============================================================
-- SECTION 4: EXPORT-READY SUMMARY VIEWS
-- (Use these to drive Excel pivot tables and dashboards)
-- ============================================================

-- ------------------------------------------------------------
-- 4A. SPECIALTY SUMMARY VIEW
--     Export this for Specialty Pivot Table in Excel
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_specialty_summary AS
WITH base AS (
    SELECT
        p.provider_type                                             AS specialty,
        COUNT(DISTINCT p.npi)                                       AS provider_count,
        COUNT(DISTINCT u.hcpcs_cd)                                  AS distinct_procedures,
        SUM(u.tot_benes)                                            AS sum_benes_approx,
        SUM(u.tot_srvcs)                                            AS total_services,
        SUM(u.avg_submitted_charge   * u.tot_srvcs)                 AS total_submitted,
        SUM(u.avg_medicare_allowed   * u.tot_srvcs)                 AS total_allowed,
        SUM(u.avg_medicare_payment   * u.tot_srvcs)                 AS total_payment,
        SUM(u.avg_medicare_standardized * u.tot_srvcs)              AS total_standardized
    FROM utilization u
    JOIN providers p ON u.npi = p.npi
    GROUP BY p.provider_type
)
SELECT
    specialty,
    provider_count,
    distinct_procedures,
    sum_benes_approx,
    total_services,
    ROUND(total_submitted,    2)                                    AS total_submitted,
    ROUND(total_allowed,      2)                                    AS total_allowed,
    ROUND(total_payment,      2)                                    AS total_payment,
    ROUND(total_standardized, 2)                                    AS total_standardized,
    ROUND(total_payment / NULLIF(total_services,      0), 2)        AS avg_payment_per_svc,
    ROUND(total_payment / NULLIF(sum_benes_approx, 0), 2)        AS avg_payment_per_bene_approx,
    ROUND(total_submitted / NULLIF(total_payment,     0), 2)        AS charge_to_payment_ratio
FROM base
ORDER BY total_payment DESC;

-- SELECT * FROM vw_specialty_summary;


-- ------------------------------------------------------------
-- 4B. PROCEDURE SUMMARY VIEW
--     Export this for HCPCS Code Pivot Table in Excel
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_procedure_summary AS
SELECT
    h.hcpcs_cd,
    h.hcpcs_desc,
    CASE h.drug_indicator
        WHEN 'Y' THEN 'Part B Drug'
        ELSE           'Professional Service'
    END                                                             AS code_type,
    COUNT(DISTINCT u.npi)                                           AS provider_count,
    SUM(u.tot_benes)                                                AS sum_benes_approx,
    SUM(u.tot_srvcs)                                                AS total_services,
    ROUND(SUM(u.avg_medicare_payment  * u.tot_srvcs), 2)            AS total_payment,
    ROUND(SUM(u.avg_medicare_allowed  * u.tot_srvcs), 2)            AS total_allowed,
    ROUND(
        SUM(u.avg_medicare_payment * u.tot_srvcs) /
        NULLIF(SUM(u.tot_srvcs), 0),
    2)                                                              AS avg_payment_per_svc,
    ROUND(
        SUM(u.avg_medicare_payment * u.tot_srvcs) /
        NULLIF(SUM(u.tot_benes), 0),
    2)                                                              AS avg_payment_per_bene_approx
FROM utilization u
JOIN hcpcs_codes h ON u.hcpcs_cd = h.hcpcs_cd
GROUP BY h.hcpcs_cd, h.hcpcs_desc, h.drug_indicator
ORDER BY total_payment DESC;

-- SELECT * FROM vw_procedure_summary;


-- ------------------------------------------------------------
-- 4C. PROVIDER KPI VIEW
--     Export this for Provider-Level Analysis in Excel
--     *_bene_approx columns use summed row-level beneficiaries.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_provider_kpi AS
SELECT
    p.npi,
    CASE p.entity_type
        WHEN 'I' THEN CONCAT(p.first_name, ' ', p.last_org_name)
        ELSE p.last_org_name
    END                                                             AS provider_name,
    p.credentials,
    p.entity_type,
    p.city,
    p.zip5,
    p.provider_type                                                 AS specialty,
    p.medicare_participates,
    COUNT(DISTINCT u.hcpcs_cd)                                      AS distinct_procedures,
    SUM(u.tot_benes)                                                AS sum_benes_approx,
    SUM(u.tot_srvcs)                                                AS total_services,
    ROUND(SUM(u.avg_medicare_payment  * u.tot_srvcs), 2)            AS total_payment,
    ROUND(SUM(u.avg_medicare_allowed  * u.tot_srvcs), 2)            AS total_allowed,
    ROUND(SUM(u.avg_submitted_charge  * u.tot_srvcs), 2)            AS total_submitted,
    ROUND(
        SUM(u.avg_medicare_payment * u.tot_srvcs) /
        NULLIF(SUM(u.tot_srvcs), 0),
    2)                                                              AS avg_payment_per_svc,
    ROUND(
        SUM(u.avg_medicare_payment * u.tot_srvcs) /
        NULLIF(SUM(u.tot_benes), 0),
    2)                                                              AS avg_payment_per_bene_approx,
    ROUND(
        SUM(u.tot_srvcs) /
        NULLIF(SUM(u.tot_benes), 0),
    2)                                                              AS srvcs_per_bene_approx,
    ROUND(
        SUM(u.avg_submitted_charge * u.tot_srvcs) /
        NULLIF(SUM(u.avg_medicare_payment * u.tot_srvcs), 0),
    2)                                                              AS charge_to_payment_ratio
FROM utilization u
JOIN providers p ON u.npi = p.npi
GROUP BY
    p.npi, p.first_name, p.last_org_name, p.credentials,
    p.entity_type, p.city, p.zip5, p.provider_type,
    p.medicare_participates
ORDER BY total_payment DESC;

-- SELECT * FROM vw_provider_kpi;


-- ============================================================
-- SECTION 5: DATA-QUALITY CHECKS (inspect before interpreting outputs)
-- Duplicate rows at the expected source grain should return no results.
SELECT npi, hcpcs_cd, place_of_service, COUNT(*) AS row_count
FROM utilization
GROUP BY npi, hcpcs_cd, place_of_service
HAVING COUNT(*) > 1;

-- Null, non-positive volume, and negative-payment checks.
SELECT
    COUNT(*) AS published_rows,
    COUNT(*) FILTER (WHERE tot_srvcs IS NULL OR tot_srvcs <= 0)
        AS invalid_service_rows,
    COUNT(*) FILTER (WHERE avg_medicare_payment IS NULL
        OR avg_medicare_payment < 0) AS invalid_payment_rows
FROM utilization;

-- END OF SCRIPT
-- ============================================================
