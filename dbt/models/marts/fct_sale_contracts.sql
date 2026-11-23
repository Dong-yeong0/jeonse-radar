SELECT
    *,
    round(sale_price_won / nullif(exclusive_area_m2, 0)) AS sale_price_won_per_m2
FROM {{ ref('int_row_house_sale_transactions') }}
