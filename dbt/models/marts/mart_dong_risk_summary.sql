SELECT
    legal_dong_code,
    left(legal_dong_code, 8) AS eupmyeondong_code_8,
    max(sigungu_code) AS sigungu_code,
    max(eupmyeondong_name) AS eupmyeondong_name,
    count(*) AS building_count,
    count(*) FILTER (WHERE risk_grade = '고위험') AS high_risk_building_count,
    count(*) FILTER (WHERE risk_grade = '주의') AS caution_building_count,
    round(
        count(*) FILTER (WHERE risk_grade = '고위험')::NUMERIC / count(*), 4
    ) AS high_risk_building_share,
    percentile_cont(0.5) WITHIN GROUP (ORDER BY median_deposit_to_public_price_ratio)
        AS median_deposit_to_public_price_ratio,
    percentile_cont(0.5) WITHIN GROUP (ORDER BY median_jeonse_rate) AS median_jeonse_rate,
    sum(expected_shortfall_count) AS expected_shortfall_count,
    sum(expected_shortfall_won) AS expected_shortfall_won,
    max(as_of_date) AS as_of_date
FROM {{ ref('mart_building_risk') }}
GROUP BY legal_dong_code
