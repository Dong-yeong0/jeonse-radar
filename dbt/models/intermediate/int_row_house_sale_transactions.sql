WITH sale_transactions AS (
    SELECT * FROM {{ ref('stg_row_house_sale_transactions') }}
    WHERE NOT is_cancelled
),

legal_dong_codes AS (
    SELECT legal_dong_code, left(legal_dong_code, 5) AS sigungu_code, eupmyeondong_name
    FROM {{ ref('legal_dong_codes') }}
    WHERE eupmyeondong_name IS NOT NULL
      AND ri_name IS NULL
)

SELECT
    sale_transactions.*,
    legal_dong_codes.legal_dong_code
FROM sale_transactions
LEFT JOIN legal_dong_codes
    ON sale_transactions.sigungu_code = legal_dong_codes.sigungu_code
    AND sale_transactions.eupmyeondong_name = legal_dong_codes.eupmyeondong_name
