SELECT
    *,
    CASE
        WHEN is_jeonse AND public_price_won > 0
            THEN round(deposit_won::NUMERIC / public_price_won, 4)
    END AS deposit_to_public_price_ratio
FROM {{ ref('int_row_house_rent_transactions') }}
