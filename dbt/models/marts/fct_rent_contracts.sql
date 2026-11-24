WITH sigungu_names AS (
    SELECT left(legal_dong_code, 5) AS sigungu_code, sigungu_name
    FROM {{ ref('legal_dong_codes') }}
    WHERE legal_dong_code LIKE '%00000' AND eupmyeondong_name IS NULL
)

SELECT
    rent.*,
    sigungu_names.sigungu_name,
    CASE
        WHEN rent.is_jeonse AND rent.public_price_won > 0
            THEN round(rent.deposit_won::NUMERIC / rent.public_price_won, 4)
    END AS deposit_to_public_price_ratio
FROM {{ ref('int_row_house_rent_transactions') }} AS rent
LEFT JOIN sigungu_names USING (sigungu_code)
