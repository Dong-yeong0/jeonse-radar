-- 최근 1년 전월세 중 공시가격이 매칭된 비율이 90% 아래면 실패
WITH recent AS (
    SELECT public_price_won
    FROM {{ ref('int_row_house_rent_transactions') }}
    WHERE contract_date >= current_date - INTERVAL '1 year'
)

SELECT count(public_price_won)::NUMERIC / count(*) AS match_rate
FROM recent
HAVING count(public_price_won)::NUMERIC / count(*) < 0.9
