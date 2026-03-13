{\rtf1\ansi\ansicpg1252\cocoartf2822
\cocoatextscaling0\cocoaplatform0{\fonttbl\f0\fswiss\fcharset0 Helvetica;}
{\colortbl;\red255\green255\blue255;}
{\*\expandedcolortbl;;}
\margl1440\margr1440\vieww11520\viewh8400\viewkind0
\pard\tx720\tx1440\tx2160\tx2880\tx3600\tx4320\tx5040\tx5760\tx6480\tx7200\tx7920\tx8640\pardirnatural\partightenfactor0

\f0\fs24 \cf0 -- ============================================================\
--  MEDICARE PHYSICIAN & PRACTITIONER ANALYTICS\
--  Source: CMS Medicare Physician & Other Practitioners\
--          by Provider and Service (2023)\
--  Scope:  Illinois Providers\
--  Author: Michal Kuderski\
--  DB:     PostgreSQL\
-- ============================================================\
\
\
-- ============================================================\
-- SECTION 1: SCHEMA SETUP\
-- ============================================================\
-- Drop tables if rebuilding from scratch (safe re-run)\
DROP TABLE IF EXISTS utilization  CASCADE;\
DROP TABLE IF EXISTS hcpcs_codes  CASCADE;\
DROP TABLE IF EXISTS providers    CASCADE;\
\
-- ------------------------------------------------------------\
-- 1A. PROVIDERS\
--     One row per unique rendering provider (NPI).\
--     NPI is the CMS-assigned unique identifier from NPPES.\
--     entity_type distinguishes individual clinicians ('I')\
--     from organizations ('O') -- affects name field logic.\
-- ------------------------------------------------------------\
CREATE TABLE providers (\
    npi                     BIGINT          PRIMARY KEY,\
    last_org_name           VARCHAR(100),\
    first_name              VARCHAR(50),\
    middle_initial          CHAR(1),\
    credentials             VARCHAR(50),\
    entity_type             CHAR(1),        -- 'I' = Individual, 'O' = Organization\
    street_1                VARCHAR(100),\
    street_2                VARCHAR(100),\
    city                    VARCHAR(50),\
    state                   CHAR(2),\
    state_fips              SMALLINT,\
    zip5                    CHAR(5),\
    ruca_code               NUMERIC(4,1),\
    ruca_description        VARCHAR(100),\
    country                 CHAR(2),\
    provider_type           VARCHAR(100),   -- Specialty (e.g. "Psychiatry")\
    medicare_participates   CHAR(1)         -- 'Y' = accepts Medicare assignment\
);\
\
-- ------------------------------------------------------------\
-- 1B. HCPCS_CODES\
--     Reference/lookup table for procedure codes.\
--     One row per unique HCPCS code.\
--     drug_indicator = 'Y' means the code appears on CMS\
--     Part B Drug ASP file -- reimbursement logic differs.\
-- ------------------------------------------------------------\
CREATE TABLE hcpcs_codes (\
    hcpcs_cd        VARCHAR(10)     PRIMARY KEY,\
    hcpcs_desc      VARCHAR(256),\
    drug_indicator  CHAR(1)         -- 'Y' = Part B Drug, 'N' = Professional service\
);\
\
-- ------------------------------------------------------------\
-- 1C. UTILIZATION  (Fact Table)\
--     One row per provider x HCPCS code x place of service.\
--     All volume and payment columns live here.\
--\
--     KEY PAYMENT FIELD DEFINITIONS (per CMS Data Dictionary):\
--       avg_submitted_charge    -- Provider's billed amount; NOT a cost measure.\
--                                  Providers routinely bill 2-5x the allowed amount.\
--       avg_medicare_allowed    -- CMS fee schedule allowed amount; includes\
--                                  Medicare's share + beneficiary deductible/coinsurance.\
--       avg_medicare_payment    -- What CMS actually transferred to the provider\
--                                  after deductibles and coinsurance are removed.\
--                                  Includes mandatory 2% sequestration reduction.\
--       avg_medicare_standardized -- Geography-adjusted payment; removes regional\
--                                  wage differences. Use for cross-market comparisons.\
-- ------------------------------------------------------------\
CREATE TABLE utilization (\
    util_id                     SERIAL          PRIMARY KEY,\
    npi                         BIGINT          NOT NULL REFERENCES providers(npi),\
    hcpcs_cd                    VARCHAR(10)     NOT NULL REFERENCES hcpcs_codes(hcpcs_cd),\
    place_of_service            CHAR(1),        -- 'F' = Facility, 'O' = Office/Non-Facility\
    tot_benes                   INTEGER,        -- Distinct Medicare beneficiaries served\
    tot_srvcs                   NUMERIC(12,2),  -- Total service units rendered\
    tot_bene_day_srvcs          NUMERIC(12,2),  -- De-duplicated beneficiary/day count\
    avg_submitted_charge        NUMERIC(12,2),\
    avg_medicare_allowed        NUMERIC(12,2),\
    avg_medicare_payment        NUMERIC(12,2),\
    avg_medicare_standardized   NUMERIC(12,2)\
);\
\
-- Indexes to support JOIN and filter performance\
CREATE INDEX idx_util_npi      ON utilization(npi);\
CREATE INDEX idx_util_hcpcs    ON utilization(hcpcs_cd);\
CREATE INDEX idx_prov_state    ON providers(state);\
CREATE INDEX idx_prov_type     ON providers(provider_type);\
\
\
-- ============================================================\
-- SECTION 2: DATA IMPORT\
-- ============================================================\
-- Import the raw CSV into a staging table first, then populate\
-- the normalized tables. This avoids data type conflicts on\
-- import and lets us inspect raw values before transformation.\
\
-- ------------------------------------------------------------\
-- 2A. STAGING TABLE (mirrors CSV structure exactly)\
-- ------------------------------------------------------------\
DROP TABLE IF EXISTS staging_raw;\
\
CREATE TEMP TABLE staging_raw (\
    Rndrng_NPI                  TEXT,\
    Rndrng_Prvdr_Last_Org_Name  TEXT,\
    Rndrng_Prvdr_First_Name     TEXT,\
    Rndrng_Prvdr_MI             TEXT,\
    Rndrng_Prvdr_Crdntls        TEXT,\
    Rndrng_Prvdr_Ent_Cd         TEXT,\
    Rndrng_Prvdr_St1            TEXT,\
    Rndrng_Prvdr_St2            TEXT,\
    Rndrng_Prvdr_City           TEXT,\
    Rndrng_Prvdr_State_Abrvtn   TEXT,\
    Rndrng_Prvdr_State_FIPS     TEXT,\
    Rndrng_Prvdr_Zip5           TEXT,\
    Rndrng_Prvdr_RUCA           TEXT,\
    Rndrng_Prvdr_RUCA_Desc      TEXT,\
    Rndrng_Prvdr_Cntry          TEXT,\
    Rndrng_Prvdr_Type           TEXT,\
    Rndrng_Prvdr_Mdcr_Prtcptg_Ind TEXT,\
    HCPCS_Cd                    TEXT,\
    HCPCS_Desc                  TEXT,\
    HCPCS_Drug_Ind              TEXT,\
    Place_Of_Srvc               TEXT,\
    Tot_Benes                   TEXT,\
    Tot_Srvcs                   TEXT,\
    Tot_Bene_Day_Srvcs          TEXT,\
    Avg_Sbmtd_Chrg              TEXT,\
    Avg_Mdcr_Alowd_Amt          TEXT,\
    Avg_Mdcr_Pymt_Amt           TEXT,\
    Avg_Mdcr_Stdzd_Amt          TEXT\
);\
\
-- ------------------------------------------------------------\
-- 2B. LOAD CSV INTO STAGING\
--     Update the file path to match your local environment.\
--     HEADER skips the first row. CSV handles quoted fields.\
-- ------------------------------------------------------------\
COPY staging_raw\
FROM '/Users/michalkuderski/Data_Analytics_Portfolio/Medicare_Physician_Other_Practitioners_by_Provider_and_Service_2023.csv'\
WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');\
\
-- Quick row count to verify load\
SELECT COUNT(*) FROM staging_raw;\
\
-- ------------------------------------------------------------\
-- 2C. POPULATE NORMALIZED TABLES FROM STAGING\
--     Filter to Illinois (state = 'IL') at this stage.\
--     INSERT DISTINCT prevents duplicate NPIs when the same\
--     provider appears across multiple service rows.\
-- ------------------------------------------------------------\
\
-- Providers (Illinois only)\
INSERT INTO providers\
SELECT DISTINCT ON (Rndrng_NPI)\
    Rndrng_NPI::BIGINT,\
    Rndrng_Prvdr_Last_Org_Name,\
    Rndrng_Prvdr_First_Name,\
    NULLIF(Rndrng_Prvdr_MI, ''),\
    NULLIF(Rndrng_Prvdr_Crdntls, ''),\
    Rndrng_Prvdr_Ent_Cd,\
    Rndrng_Prvdr_St1,\
    NULLIF(Rndrng_Prvdr_St2, ''),\
    Rndrng_Prvdr_City,\
    Rndrng_Prvdr_State_Abrvtn,\
    Rndrng_Prvdr_State_FIPS::SMALLINT,\
    Rndrng_Prvdr_Zip5,\
    NULLIF(Rndrng_Prvdr_RUCA, '')::NUMERIC(4,1),\
    Rndrng_Prvdr_RUCA_Desc,\
    Rndrng_Prvdr_Cntry,\
    Rndrng_Prvdr_Type,\
    Rndrng_Prvdr_Mdcr_Prtcptg_Ind\
FROM staging_raw\
WHERE Rndrng_Prvdr_State_Abrvtn = 'IL'\
ORDER BY Rndrng_NPI;\
\
-- HCPCS reference codes (for all codes that appear in IL data)\
INSERT INTO hcpcs_codes\
SELECT DISTINCT\
    HCPCS_Cd,\
    HCPCS_Desc,\
    HCPCS_Drug_Ind\
FROM staging_raw\
WHERE Rndrng_Prvdr_State_Abrvtn = 'IL'\
ON CONFLICT (hcpcs_cd) DO NOTHING;\
\
-- Utilization fact rows (Illinois only)\
INSERT INTO utilization (\
    npi, hcpcs_cd, place_of_service,\
    tot_benes, tot_srvcs, tot_bene_day_srvcs,\
    avg_submitted_charge, avg_medicare_allowed,\
    avg_medicare_payment, avg_medicare_standardized\
)\
SELECT\
    Rndrng_NPI::BIGINT,\
    HCPCS_Cd,\
    Place_Of_Srvc,\
    NULLIF(Tot_Benes, '')::INTEGER,\
    NULLIF(Tot_Srvcs, '')::NUMERIC(12,2),\
    NULLIF(Tot_Bene_Day_Srvcs, '')::NUMERIC(12,2),\
    NULLIF(Avg_Sbmtd_Chrg, '')::NUMERIC(12,2),\
    NULLIF(Avg_Mdcr_Alowd_Amt, '')::NUMERIC(12,2),\
    NULLIF(Avg_Mdcr_Pymt_Amt, '')::NUMERIC(12,2),\
    NULLIF(Avg_Mdcr_Stdzd_Amt, '')::NUMERIC(12,2)\
FROM staging_raw\
WHERE Rndrng_Prvdr_State_Abrvtn = 'IL';\
\
\
-- ============================================================\
-- SECTION 3: KPI QUERIES\
-- ============================================================\
\
\
-- ------------------------------------------------------------\
-- QUERY 3.1\
-- WHICH SPECIALTIES GENERATE THE HIGHEST TOTAL MEDICARE SPENDING?\
--\
-- Logic: Total Medicare payment = avg_medicare_payment * tot_srvcs\
-- This reflects actual dollars CMS transferred to providers.\
-- We also calculate total allowed amount and submitted charges\
-- to show the full reimbursement funnel.\
-- ------------------------------------------------------------\
\
SELECT\
    p.provider_type                                         AS specialty,\
    COUNT(DISTINCT p.npi)                                   AS provider_count,\
    SUM(u.tot_srvcs)                                        AS total_services,\
    SUM(u.tot_benes)                                        AS total_beneficiaries,\
\
    -- Total dollars CMS actually paid out\
    ROUND(SUM(u.avg_medicare_payment * u.tot_srvcs), 2)     AS total_medicare_payment,\
\
    -- Total allowed (Medicare payment + beneficiary cost-sharing)\
    ROUND(SUM(u.avg_medicare_allowed * u.tot_srvcs), 2)     AS total_medicare_allowed,\
\
    -- Total billed (providers' submitted charges \'97 not a true cost figure)\
    ROUND(SUM(u.avg_submitted_charge * u.tot_srvcs), 2)     AS total_submitted_charges,\
\
    -- Payment-to-allowed ratio: how much of allowed amount CMS covered\
    -- (remainder = beneficiary deductible/coinsurance)\
    ROUND(\
        SUM(u.avg_medicare_payment * u.tot_srvcs) /\
        NULLIF(SUM(u.avg_medicare_allowed * u.tot_srvcs), 0) * 100,\
    1)                                                      AS pct_allowed_paid_by_medicare\
\
FROM utilization u\
JOIN providers p ON u.npi = p.npi\
\
GROUP BY p.provider_type\
ORDER BY total_medicare_payment DESC;\
\
\
-- ------------------------------------------------------------\
-- QUERY 3.2\
-- AVERAGE MEDICARE PAYMENT PER SERVICE BY SPECIALTY\
--\
-- Uses a CTE to pre-aggregate at the specialty level, then\
-- calculates per-service and per-beneficiary averages.\
-- Includes standardized payment for geographic comparability.\
-- ------------------------------------------------------------\
\
WITH specialty_totals AS (\
    -- Aggregate raw payment and volume by specialty\
    SELECT\
        p.provider_type                                         AS specialty,\
        COUNT(DISTINCT p.npi)                                   AS provider_count,\
        SUM(u.tot_srvcs)                                        AS total_services,\
        SUM(u.tot_benes)                                        AS total_beneficiaries,\
        SUM(u.avg_medicare_payment     * u.tot_srvcs)           AS total_payment,\
        SUM(u.avg_medicare_allowed     * u.tot_srvcs)           AS total_allowed,\
        SUM(u.avg_medicare_standardized * u.tot_srvcs)          AS total_standardized\
    FROM utilization u\
    JOIN providers p ON u.npi = p.npi\
    GROUP BY p.provider_type\
)\
\
SELECT\
    specialty,\
    provider_count,\
    total_services,\
    total_beneficiaries,\
\
    -- Average actual payment per service unit\
    ROUND(total_payment / NULLIF(total_services, 0), 2)         AS avg_payment_per_service,\
\
    -- Average allowed amount per service (includes patient cost-sharing)\
    ROUND(total_allowed / NULLIF(total_services, 0), 2)         AS avg_allowed_per_service,\
\
    -- Geography-adjusted payment per service (best for cross-region comparison)\
    ROUND(total_standardized / NULLIF(total_services, 0), 2)    AS avg_standardized_per_service,\
\
    -- Cost per beneficiary (population-level efficiency metric)\
    ROUND(total_payment / NULLIF(total_beneficiaries, 0), 2)    AS avg_payment_per_beneficiary\
\
FROM specialty_totals\
ORDER BY avg_payment_per_service DESC;\
\
\
-- ------------------------------------------------------------\
-- QUERY 3.3\
-- WHICH PROVIDERS ARE OUTLIERS IN PAYMENT PER SERVICE\
-- WITHIN THEIR SPECIALTY?\
--\
-- Uses a window function to compute specialty-level averages\
-- alongside each provider's individual metrics, then flags\
-- providers whose per-service payment deviates significantly.\
-- A subquery filters to outliers only for the final output.\
-- ------------------------------------------------------------\
\
WITH provider_metrics AS (\
    -- Individual provider-level payment per service\
    SELECT\
        p.npi,\
        p.first_name,\
        p.last_org_name,\
        p.credentials,\
        p.city,\
        p.provider_type                                                 AS specialty,\
        SUM(u.tot_srvcs)                                                AS total_services,\
        SUM(u.tot_benes)                                                AS total_beneficiaries,\
        ROUND(SUM(u.avg_medicare_payment * u.tot_srvcs), 2)             AS total_payment,\
\
        -- Provider's own payment per service\
        ROUND(\
            SUM(u.avg_medicare_payment * u.tot_srvcs) /\
            NULLIF(SUM(u.tot_srvcs), 0),\
        2)                                                              AS provider_pay_per_svc,\
\
        -- Specialty average payment per service (window function over specialty group)\
        ROUND(\
            SUM(SUM(u.avg_medicare_payment * u.tot_srvcs)) OVER (PARTITION BY p.provider_type) /\
            NULLIF(SUM(SUM(u.tot_srvcs)) OVER (PARTITION BY p.provider_type), 0),\
        2)                                                              AS specialty_avg_pay_per_svc\
\
    FROM utilization u\
    JOIN providers p ON u.npi = p.npi\
    GROUP BY p.npi, p.first_name, p.last_org_name, p.credentials, p.city, p.provider_type\
),\
\
-- Add deviation from specialty mean and rank within specialty\
ranked_providers AS (\
    SELECT\
        *,\
        -- Absolute dollar deviation from specialty average\
        ROUND(provider_pay_per_svc - specialty_avg_pay_per_svc, 2)     AS deviation_from_avg,\
\
        -- Percent deviation from specialty average\
        ROUND(\
            (provider_pay_per_svc - specialty_avg_pay_per_svc) /\
            NULLIF(specialty_avg_pay_per_svc, 0) * 100,\
        1)                                                              AS pct_deviation,\
\
        -- Rank within specialty (highest payment per service = rank 1)\
        RANK() OVER (\
            PARTITION BY specialty\
            ORDER BY provider_pay_per_svc DESC\
        )                                                               AS specialty_rank\
    FROM provider_metrics\
)\
\
-- Final output: filter to providers who deviate > 50% from specialty mean\
-- and have at least 10 services (low-volume providers can appear as outliers by chance)\
SELECT\
    specialty,\
    specialty_rank,\
    npi,\
    CONCAT(first_name, ' ', last_org_name)  AS provider_name,\
    credentials,\
    city,\
    total_services,\
    total_beneficiaries,\
    total_payment,\
    provider_pay_per_svc,\
    specialty_avg_pay_per_svc,\
    deviation_from_avg,\
    pct_deviation,\
    CASE\
        WHEN pct_deviation > 50  THEN 'HIGH OUTLIER'\
        WHEN pct_deviation < -50 THEN 'LOW OUTLIER'\
        ELSE 'Within Range'\
    END                                     AS outlier_flag\
\
FROM ranked_providers\
WHERE ABS(pct_deviation) > 50\
  AND total_services >= 10\
ORDER BY specialty, pct_deviation DESC;\
\
\
-- ------------------------------------------------------------\
-- QUERY 3.4\
-- WHICH PROCEDURES (HCPCS CODES) DRIVE THE HIGHEST\
-- AGGREGATE MEDICARE SPENDING?\
--\
-- Identifies the top cost drivers at the procedure level.\
-- Distinguishes drug codes from professional service codes,\
-- as these follow fundamentally different pricing mechanisms.\
-- Uses a subquery to pre-calculate procedure totals, then\
-- ranks them and shows concentration (top N % of spend).\
-- ------------------------------------------------------------\
\
WITH procedure_spend AS (\
    SELECT\
        h.hcpcs_cd,\
        h.hcpcs_desc,\
        h.drug_indicator,\
        COUNT(DISTINCT u.npi)                                           AS provider_count,\
        SUM(u.tot_benes)                                                AS total_beneficiaries,\
        SUM(u.tot_srvcs)                                                AS total_services,\
        ROUND(SUM(u.avg_medicare_payment  * u.tot_srvcs), 2)            AS total_payment,\
        ROUND(SUM(u.avg_medicare_allowed  * u.tot_srvcs), 2)            AS total_allowed,\
        ROUND(SUM(u.avg_submitted_charge  * u.tot_srvcs), 2)            AS total_submitted,\
\
        -- Per-service cost benchmark\
        ROUND(\
            SUM(u.avg_medicare_payment * u.tot_srvcs) /\
            NULLIF(SUM(u.tot_srvcs), 0),\
        2)                                                              AS avg_payment_per_svc\
\
    FROM utilization u\
    JOIN hcpcs_codes h ON u.hcpcs_cd = h.hcpcs_cd\
    GROUP BY h.hcpcs_cd, h.hcpcs_desc, h.drug_indicator\
)\
\
SELECT\
    RANK() OVER (ORDER BY total_payment DESC)           AS cost_rank,\
    hcpcs_cd,\
    hcpcs_desc,\
    CASE drug_indicator\
        WHEN 'Y' THEN 'Part B Drug (ASP-based)'\
        ELSE           'Professional Service'\
    END                                                 AS code_type,\
    provider_count,\
    total_beneficiaries,\
    total_services,\
    total_payment,\
    avg_payment_per_svc,\
\
    -- Running cumulative share of total spend (spending concentration)\
    ROUND(\
        SUM(total_payment) OVER (ORDER BY total_payment DESC) /\
        SUM(total_payment) OVER () * 100,\
    1)                                                  AS cumulative_pct_of_spend\
\
FROM procedure_spend\
ORDER BY total_payment DESC\
LIMIT 25;  -- Top 25 procedures by Medicare spend\
\
\
-- ------------------------------------------------------------\
-- QUERY 3.5\
-- COST EFFICIENCY VARIATION ACROSS PROVIDERS\
-- WITHIN THE SAME SPECIALTY\
--\
-- PRIMARY METRIC: avg_medicare_payment PER SERVICE (clean denominator).\
--   Service units (tot_srvcs) are fully additive across HCPCS codes.\
--\
-- \uc0\u9888  IMPORTANT \'97 SUM(tot_benes) DOUBLE-COUNTS BENEFICIARIES:\
--   The CMS data dictionary defines tot_benes as distinct beneficiaries\
--   per (NPI, HCPCS_Cd, Place_Of_Srvc) row. A patient receiving both\
--   99214 and 99232 from the same provider appears in two rows' counts.\
--   SUM(tot_benes) at provider level inflates by ~2.4x on average.\
--   True unique-beneficiary counts per provider require raw claims data.\
--   This query retains sum_benes_approx as a secondary reference column\
--   but does NOT use it as a z-score or efficiency denominator.\
--\
-- Z-SCORE FORMULA (unit-consistent):\
--   z = (provider_avg_pay_per_svc - specialty_mean_pay_per_svc)\
--       / specialty_stddev_pay_per_svc\
-- ------------------------------------------------------------\
\
WITH provider_efficiency AS (\
    SELECT\
        p.npi,\
        p.first_name,\
        p.last_org_name,\
        p.city,\
        p.provider_type                                                 AS specialty,\
        p.medicare_participates,\
        COUNT(DISTINCT u.hcpcs_cd)                                      AS distinct_procedures,\
\
        -- \uc0\u9888  Approximate only \'97 double-counts patients billed under multiple codes\
        SUM(u.tot_benes)                                                AS sum_benes_approx,\
\
        -- Clean, additive denominator \'97 use this for efficiency KPIs\
        SUM(u.tot_srvcs)                                                AS total_services,\
\
        ROUND(SUM(u.avg_medicare_payment * u.tot_srvcs), 2)             AS total_payment,\
\
        -- PRIMARY efficiency metric: payment per service unit (clean denominator)\
        ROUND(\
            SUM(u.avg_medicare_payment * u.tot_srvcs) /\
            NULLIF(SUM(u.tot_srvcs), 0),\
        2)                                                              AS avg_pay_per_service,\
\
        -- SECONDARY / APPROXIMATE: payment per beneficiary\
        -- \uc0\u9888  Denominator inflated ~2.4x \'97 reference only, do not z-score\
        ROUND(\
            SUM(u.avg_medicare_payment * u.tot_srvcs) /\
            NULLIF(SUM(u.tot_benes), 0),\
        2)                                                              AS avg_pay_per_bene_approx,\
\
        -- Services per beneficiary (approximate \'97 inherits double-counting)\
        ROUND(\
            SUM(u.tot_srvcs) /\
            NULLIF(SUM(u.tot_benes), 0),\
        2)                                                              AS srvcs_per_bene_approx,\
\
        -- Charge-to-payment ratio: indicates billing markup\
        ROUND(\
            SUM(u.avg_submitted_charge * u.tot_srvcs) /\
            NULLIF(SUM(u.avg_medicare_payment * u.tot_srvcs), 0),\
        2)                                                              AS charge_to_payment_ratio\
\
    FROM utilization u\
    JOIN providers p ON u.npi = p.npi\
    GROUP BY p.npi, p.first_name, p.last_org_name, p.city, p.provider_type, p.medicare_participates\
),\
\
-- Specialty-level distribution \'97 ALL stats on avg_pay_per_service (clean units)\
specialty_stats AS (\
    SELECT\
        specialty,\
        COUNT(*)                                                        AS provider_count,\
        ROUND(AVG(avg_pay_per_service), 2)                              AS mean_pay_per_svc,\
        ROUND(STDDEV(avg_pay_per_service), 2)                           AS stddev_pay_per_svc,\
        ROUND(MIN(avg_pay_per_service), 2)                              AS min_pay_per_svc,\
        ROUND(MAX(avg_pay_per_service), 2)                              AS max_pay_per_svc,\
        ROUND(\
            PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY avg_pay_per_service)::NUMERIC,\
        2)                                                              AS median_pay_per_svc,\
        ROUND(\
            PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY avg_pay_per_service)::NUMERIC,\
        2)                                                              AS p25_pay_per_svc,\
        ROUND(\
            PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY avg_pay_per_service)::NUMERIC,\
        2)                                                              AS p75_pay_per_svc\
    FROM provider_efficiency\
    WHERE total_services >= 10   -- Minimum volume for reliability\
    GROUP BY specialty\
)\
\
SELECT\
    pe.specialty,\
    pe.npi,\
    CONCAT(pe.first_name, ' ', pe.last_org_name)        AS provider_name,\
    pe.city,\
    pe.medicare_participates,\
    pe.distinct_procedures,\
    pe.sum_benes_approx,        -- \uc0\u9888  reference only \'97 inflated denominator\
    pe.total_services,          -- \uc0\u10003  clean, additive\
    pe.total_payment,\
    pe.avg_pay_per_service,     -- \uc0\u10003  primary efficiency metric\
    pe.avg_pay_per_bene_approx, -- \uc0\u9888  approximate\
    pe.srvcs_per_bene_approx,   -- \uc0\u9888  approximate\
    pe.charge_to_payment_ratio,\
    ss.mean_pay_per_svc                                 AS specialty_mean_pay_per_svc,\
    ss.median_pay_per_svc                               AS specialty_median_pay_per_svc,\
    ss.stddev_pay_per_svc                               AS specialty_stddev_pay_per_svc,\
    ss.p25_pay_per_svc                                  AS specialty_p25,\
    ss.p75_pay_per_svc                                  AS specialty_p75,\
\
    -- CORRECT z-score: all terms in payment_per_service units \'97 no mixing\
    ROUND(\
        (pe.avg_pay_per_service - ss.mean_pay_per_svc) /\
        NULLIF(ss.stddev_pay_per_svc, 0),\
    2)                                                  AS z_score,\
\
    -- Efficiency tier relative to specialty IQR (on pay/service)\
    CASE\
        WHEN pe.avg_pay_per_service > ss.p75_pay_per_svc THEN 'Above IQR (Higher Cost)'\
        WHEN pe.avg_pay_per_service < ss.p25_pay_per_svc THEN 'Below IQR (Lower Cost)'\
        ELSE 'Within IQR (Typical)'\
    END                                                 AS efficiency_tier\
\
FROM provider_efficiency pe\
JOIN specialty_stats ss ON pe.specialty = ss.specialty\
WHERE pe.total_services >= 10\
ORDER BY pe.specialty, pe.avg_pay_per_service DESC;\
\
\
-- ============================================================\
-- SECTION 4: EXPORT-READY SUMMARY VIEWS\
-- (Use these to drive Excel pivot tables and dashboards)\
-- ============================================================\
\
-- ------------------------------------------------------------\
-- 4A. SPECIALTY SUMMARY VIEW\
--     Export this for Specialty Pivot Table in Excel\
-- ------------------------------------------------------------\
CREATE OR REPLACE VIEW vw_specialty_summary AS\
WITH base AS (\
    SELECT\
        p.provider_type                                             AS specialty,\
        COUNT(DISTINCT p.npi)                                       AS provider_count,\
        COUNT(DISTINCT u.hcpcs_cd)                                  AS distinct_procedures,\
        SUM(u.tot_benes)                                            AS total_beneficiaries,\
        SUM(u.tot_srvcs)                                            AS total_services,\
        SUM(u.avg_submitted_charge   * u.tot_srvcs)                 AS total_submitted,\
        SUM(u.avg_medicare_allowed   * u.tot_srvcs)                 AS total_allowed,\
        SUM(u.avg_medicare_payment   * u.tot_srvcs)                 AS total_payment,\
        SUM(u.avg_medicare_standardized * u.tot_srvcs)              AS total_standardized\
    FROM utilization u\
    JOIN providers p ON u.npi = p.npi\
    GROUP BY p.provider_type\
)\
SELECT\
    specialty,\
    provider_count,\
    distinct_procedures,\
    total_beneficiaries,\
    total_services,\
    ROUND(total_submitted,    2)                                    AS total_submitted,\
    ROUND(total_allowed,      2)                                    AS total_allowed,\
    ROUND(total_payment,      2)                                    AS total_payment,\
    ROUND(total_standardized, 2)                                    AS total_standardized,\
    ROUND(total_payment / NULLIF(total_services,      0), 2)        AS avg_payment_per_svc,\
    ROUND(total_payment / NULLIF(total_beneficiaries, 0), 2)        AS avg_payment_per_bene,\
    ROUND(total_submitted / NULLIF(total_payment,     0), 2)        AS charge_to_payment_ratio\
FROM base\
ORDER BY total_payment DESC;\
\
SELECT * FROM vw_specialty_summary;\
\
\
-- ------------------------------------------------------------\
-- 4B. PROCEDURE SUMMARY VIEW\
--     Export this for HCPCS Code Pivot Table in Excel\
-- ------------------------------------------------------------\
CREATE OR REPLACE VIEW vw_procedure_summary AS\
SELECT\
    h.hcpcs_cd,\
    h.hcpcs_desc,\
    CASE h.drug_indicator\
        WHEN 'Y' THEN 'Part B Drug'\
        ELSE           'Professional Service'\
    END                                                             AS code_type,\
    COUNT(DISTINCT u.npi)                                           AS provider_count,\
    SUM(u.tot_benes)                                                AS total_beneficiaries,\
    SUM(u.tot_srvcs)                                                AS total_services,\
    ROUND(SUM(u.avg_medicare_payment  * u.tot_srvcs), 2)            AS total_payment,\
    ROUND(SUM(u.avg_medicare_allowed  * u.tot_srvcs), 2)            AS total_allowed,\
    ROUND(\
        SUM(u.avg_medicare_payment * u.tot_srvcs) /\
        NULLIF(SUM(u.tot_srvcs), 0),\
    2)                                                              AS avg_payment_per_svc,\
    ROUND(\
        SUM(u.avg_medicare_payment * u.tot_srvcs) /\
        NULLIF(SUM(u.tot_benes), 0),\
    2)                                                              AS avg_payment_per_bene\
FROM utilization u\
JOIN hcpcs_codes h ON u.hcpcs_cd = h.hcpcs_cd\
GROUP BY h.hcpcs_cd, h.hcpcs_desc, h.drug_indicator\
ORDER BY total_payment DESC;\
\
SELECT * FROM vw_procedure_summary;\
\
\
-- ------------------------------------------------------------\
-- 4C. PROVIDER KPI VIEW\
--     Export this for Provider-Level Analysis in Excel\
-- ------------------------------------------------------------\
CREATE OR REPLACE VIEW vw_provider_kpi AS\
SELECT\
    p.npi,\
    CASE p.entity_type\
        WHEN 'I' THEN CONCAT(p.first_name, ' ', p.last_org_name)\
        ELSE p.last_org_name\
    END                                                             AS provider_name,\
    p.credentials,\
    p.entity_type,\
    p.city,\
    p.zip5,\
    p.provider_type                                                 AS specialty,\
    p.medicare_participates,\
    COUNT(DISTINCT u.hcpcs_cd)                                      AS distinct_procedures,\
    SUM(u.tot_benes)                                                AS total_beneficiaries,\
    SUM(u.tot_srvcs)                                                AS total_services,\
    ROUND(SUM(u.avg_medicare_payment  * u.tot_srvcs), 2)            AS total_payment,\
    ROUND(SUM(u.avg_medicare_allowed  * u.tot_srvcs), 2)            AS total_allowed,\
    ROUND(SUM(u.avg_submitted_charge  * u.tot_srvcs), 2)            AS total_submitted,\
    ROUND(\
        SUM(u.avg_medicare_payment * u.tot_srvcs) /\
        NULLIF(SUM(u.tot_srvcs), 0),\
    2)                                                              AS avg_payment_per_svc,\
    ROUND(\
        SUM(u.avg_medicare_payment * u.tot_srvcs) /\
        NULLIF(SUM(u.tot_benes), 0),\
    2)                                                              AS avg_payment_per_bene,\
    ROUND(\
        SUM(u.tot_srvcs) /\
        NULLIF(SUM(u.tot_benes), 0),\
    2)                                                              AS srvcs_per_beneficiary,\
    ROUND(\
        SUM(u.avg_submitted_charge * u.tot_srvcs) /\
        NULLIF(SUM(u.avg_medicare_payment * u.tot_srvcs), 0),\
    2)                                                              AS charge_to_payment_ratio\
FROM utilization u\
JOIN providers p ON u.npi = p.npi\
GROUP BY\
    p.npi, p.first_name, p.last_org_name, p.credentials,\
    p.entity_type, p.city, p.zip5, p.provider_type,\
    p.medicare_participates\
ORDER BY total_payment DESC;\
\
SELECT * FROM vw_provider_kpi;\
\
-- ----------------------------------------------------------------------------------\
-- Query combining 1) Telephone visit rows - specific HCPCS codes in 'utilization' \
-- &&\
--                 2) City names - stored in 'providers,' linked by 'npi'\
-- ----------------------------------------------------------------------------------\
\
WITH city_totals AS (\
    -- total services per city, ALL codes, no filter\
    SELECT\
        p.city,\
        SUM(u.tot_srvcs) AS all_services\
    FROM utilization u\
    JOIN providers p ON u.npi = p.npi\
    GROUP BY p.city\
),\
\
telephone_by_city AS (\
    -- telephone services per city only\
    SELECT\
        p.city,\
        COUNT(DISTINCT u.npi)                              AS provider_count,\
        SUM(u.tot_srvcs)                                   AS total_telephone_services,\
        ROUND(SUM(u.avg_medicare_payment * u.tot_srvcs),2) AS total_medicare_payment\
    FROM utilization u\
    JOIN providers p ON u.npi = p.npi\
    WHERE u.hcpcs_cd IN ('99441','99442','99443')\
    GROUP BY p.city\
)\
\
SELECT\
    t.city,\
    t.provider_count,\
    t.total_telephone_services,\
    t.total_medicare_payment,\
    ROUND(t.total_telephone_services / NULLIF(c.all_services, 0) * 100, 1)\
        AS telephone_pct_of_total_services\
FROM telephone_by_city t\
JOIN city_totals c ON t.city = c.city\
ORDER BY t.total_telephone_services DESC;}