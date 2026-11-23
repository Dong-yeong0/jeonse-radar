{#- 기준값과 근거: docs/adr/0002-building-risk-grade.md -#}
{%- set hug_limit_ratio = 1.26 -%}
{%- set hug_band_lower_ratio = 1.20 -%}
{%- set min_building_sale_count = 2 -%}
{%- set min_exclusive_area_m2 = 14 -%}

WITH rent AS (
    SELECT * FROM {{ ref('fct_rent_contracts') }}
),

sale AS (
    SELECT * FROM {{ ref('fct_sale_contracts') }}
    WHERE dealing_type IS DISTINCT FROM '직거래'
      AND exclusive_area_m2 >= {{ min_exclusive_area_m2 }}
),

as_of AS (
    SELECT max(contract_date) AS as_of_date FROM rent
),

jeonse AS (
    SELECT
        rent.*,
        (build_year / 10) * 10 AS build_decade
    FROM rent
    WHERE is_jeonse
      AND legal_dong_code IS NOT NULL
      AND main_lot_number IS NOT NULL
      AND exclusive_area_m2 >= {{ min_exclusive_area_m2 }}
),

building_sale_prices AS (
    SELECT
        legal_dong_code,
        main_lot_number,
        sub_lot_number,
        percentile_cont(0.5) WITHIN GROUP (ORDER BY sale_price_won_per_m2) AS sale_price_won_per_m2
    FROM sale
    CROSS JOIN as_of
    WHERE contract_date > as_of_date - INTERVAL '24 months'
    GROUP BY legal_dong_code, main_lot_number, sub_lot_number
    HAVING count(*) >= {{ min_building_sale_count }}
),

dong_decade_sale_prices AS (
    SELECT
        legal_dong_code,
        (build_year / 10) * 10 AS build_decade,
        percentile_cont(0.5) WITHIN GROUP (ORDER BY sale_price_won_per_m2) AS sale_price_won_per_m2
    FROM sale
    CROSS JOIN as_of
    WHERE contract_date > as_of_date - INTERVAL '24 months'
    GROUP BY legal_dong_code, (build_year / 10) * 10
),

building_jeonse_prices AS (
    SELECT
        legal_dong_code,
        main_lot_number,
        sub_lot_number,
        percentile_cont(0.5) WITHIN GROUP (ORDER BY deposit_won / exclusive_area_m2) AS deposit_won_per_m2
    FROM jeonse
    CROSS JOIN as_of
    WHERE contract_date > as_of_date - INTERVAL '6 months'
    GROUP BY legal_dong_code, main_lot_number, sub_lot_number
),

dong_decade_jeonse_prices AS (
    SELECT
        legal_dong_code,
        build_decade,
        percentile_cont(0.5) WITHIN GROUP (ORDER BY deposit_won / exclusive_area_m2) AS deposit_won_per_m2
    FROM jeonse
    CROSS JOIN as_of
    WHERE contract_date > as_of_date - INTERVAL '6 months'
    GROUP BY legal_dong_code, build_decade
),

recent_jeonse AS (
    SELECT
        jeonse.*,
        jeonse.deposit_won / nullif(
            jeonse.exclusive_area_m2 * coalesce(
                building_sale_prices.sale_price_won_per_m2,
                dong_decade_sale_prices.sale_price_won_per_m2
            ),
            0
        ) AS jeonse_rate,
        building_sale_prices.sale_price_won_per_m2 IS NOT NULL AS is_building_sale_price
    FROM jeonse
    CROSS JOIN as_of
    LEFT JOIN building_sale_prices
        USING (legal_dong_code, main_lot_number, sub_lot_number)
    LEFT JOIN dong_decade_sale_prices
        USING (legal_dong_code, build_decade)
    WHERE jeonse.contract_date > as_of.as_of_date - INTERVAL '12 months'
),

expiring_jeonse AS (
    SELECT
        jeonse.legal_dong_code,
        jeonse.main_lot_number,
        jeonse.sub_lot_number,
        jeonse.deposit_won - jeonse.exclusive_area_m2 * coalesce(
            building_jeonse_prices.deposit_won_per_m2,
            dong_decade_jeonse_prices.deposit_won_per_m2
        ) AS expected_shortfall_won
    FROM jeonse
    CROSS JOIN as_of
    LEFT JOIN building_jeonse_prices
        USING (legal_dong_code, main_lot_number, sub_lot_number)
    LEFT JOIN dong_decade_jeonse_prices
        USING (legal_dong_code, build_decade)
    WHERE jeonse.contract_end_month > as_of.as_of_date
      AND jeonse.contract_end_month <= as_of.as_of_date + INTERVAL '6 months'
),

recent_metrics AS (
    SELECT
        legal_dong_code,
        main_lot_number,
        sub_lot_number,
        max(sigungu_code) AS sigungu_code,
        max(eupmyeondong_name) AS eupmyeondong_name,
        mode() WITHIN GROUP (ORDER BY building_name) AS building_name,
        max(build_year) AS build_year,
        count(*) AS recent_jeonse_count,
        percentile_cont(0.5) WITHIN GROUP (ORDER BY deposit_to_public_price_ratio)
            AS median_deposit_to_public_price_ratio,
        avg(
            CASE
                WHEN deposit_to_public_price_ratio IS NULL THEN NULL
                WHEN deposit_to_public_price_ratio > {{ hug_band_lower_ratio }}
                    AND deposit_to_public_price_ratio <= {{ hug_limit_ratio }} THEN 1.0
                ELSE 0.0
            END
        ) AS hug_limit_band_share,
        avg(
            CASE
                WHEN deposit_to_public_price_ratio IS NULL THEN NULL
                WHEN deposit_to_public_price_ratio > {{ hug_limit_ratio }} THEN 1.0
                ELSE 0.0
            END
        ) AS over_hug_limit_share,
        percentile_cont(0.5) WITHIN GROUP (ORDER BY jeonse_rate) AS median_jeonse_rate,
        bool_or(is_building_sale_price) AS has_building_sale_price
    FROM recent_jeonse
    GROUP BY legal_dong_code, main_lot_number, sub_lot_number
),

expiring_metrics AS (
    SELECT
        legal_dong_code,
        main_lot_number,
        sub_lot_number,
        count(*) AS expiring_jeonse_count,
        count(*) FILTER (WHERE expected_shortfall_won > 0) AS expected_shortfall_count,
        round(sum(greatest(expected_shortfall_won, 0)))::BIGINT AS expected_shortfall_won
    FROM expiring_jeonse
    GROUP BY legal_dong_code, main_lot_number, sub_lot_number
),

combined AS (
    SELECT
        recent_metrics.*,
        coalesce(expiring_metrics.expiring_jeonse_count, 0) AS expiring_jeonse_count,
        coalesce(expiring_metrics.expected_shortfall_count, 0) AS expected_shortfall_count,
        coalesce(expiring_metrics.expected_shortfall_won, 0) AS expected_shortfall_won
    FROM recent_metrics
    LEFT JOIN expiring_metrics
        USING (legal_dong_code, main_lot_number, sub_lot_number)
)

SELECT
    legal_dong_code || '-' || main_lot_number || '-' || sub_lot_number AS building_key,
    combined.*,
    extract(YEAR FROM as_of.as_of_date)::INT - build_year AS building_age,
    CASE WHEN combined.median_jeonse_rate IS NULL THEN NULL
        WHEN has_building_sale_price THEN 'building'
        ELSE 'dong_build_decade'
    END AS sale_price_basis,
    CASE
        WHEN median_deposit_to_public_price_ratio > {{ hug_limit_ratio }}
            OR median_jeonse_rate >= 0.9 THEN '고위험'
        WHEN hug_limit_band_share >= 0.5
            OR median_jeonse_rate >= 0.8
            OR expected_shortfall_count > 0 THEN '주의'
        WHEN median_deposit_to_public_price_ratio IS NULL
            AND median_jeonse_rate IS NULL THEN '판단불가'
        ELSE '관찰'
    END AS risk_grade,
    concat_ws(
        ', ',
        CASE WHEN median_deposit_to_public_price_ratio > {{ hug_limit_ratio }}
            THEN 'HUG 보증 한도 초과' END,
        CASE WHEN median_jeonse_rate >= 0.9 THEN '전세가율 90% 이상'
            WHEN median_jeonse_rate >= 0.8 THEN '전세가율 80% 이상' END,
        CASE WHEN hug_limit_band_share >= 0.5 THEN 'HUG 한도 맞춤 전세' END,
        CASE WHEN expected_shortfall_count > 0 THEN '역전세 예상' END
    ) AS risk_reasons,
    as_of.as_of_date
FROM combined
CROSS JOIN as_of
