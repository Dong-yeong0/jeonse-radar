WITH rent_transactions AS (
    SELECT * FROM {{ ref('stg_row_house_rent_transactions') }}
),

legal_dong_codes AS (
    SELECT legal_dong_code, left(legal_dong_code, 5) AS sigungu_code, eupmyeondong_name
    FROM {{ ref('legal_dong_codes') }}
    WHERE eupmyeondong_name IS NOT NULL
      AND ri_name IS NULL
),

unit_prices AS (
    SELECT
        legal_dong_code,
        main_lot_number,
        sub_lot_number,
        round(exclusive_area_m2, 1) AS exclusive_area_m2,
        CASE WHEN unit_name ~ '^[0-9]{3,4}$' THEN unit_name::INT / 100 END AS floor,
        public_price_won,
        base_date
    FROM {{ ref('stg_housing_public_prices') }}
),

floor_area_prices AS (
    SELECT
        legal_dong_code,
        main_lot_number,
        sub_lot_number,
        floor,
        exclusive_area_m2,
        count(*) AS unit_count,
        percentile_cont(0.5) WITHIN GROUP (ORDER BY public_price_won) AS public_price_won
    FROM unit_prices
    WHERE floor IS NOT NULL
    GROUP BY legal_dong_code, main_lot_number, sub_lot_number, floor, exclusive_area_m2
),

area_prices AS (
    SELECT
        legal_dong_code,
        main_lot_number,
        sub_lot_number,
        exclusive_area_m2,
        percentile_cont(0.5) WITHIN GROUP (ORDER BY public_price_won) AS public_price_won
    FROM unit_prices
    GROUP BY legal_dong_code, main_lot_number, sub_lot_number, exclusive_area_m2
),

building_prices AS (
    SELECT
        legal_dong_code,
        main_lot_number,
        sub_lot_number,
        max(base_date) AS base_date,
        percentile_cont(0.5) WITHIN GROUP (
            ORDER BY public_price_won / nullif(exclusive_area_m2, 0)
        ) AS public_price_won_per_m2
    FROM unit_prices
    GROUP BY legal_dong_code, main_lot_number, sub_lot_number
),

with_legal_dong AS (
    SELECT
        rent_transactions.*,
        legal_dong_codes.legal_dong_code
    FROM rent_transactions
    LEFT JOIN legal_dong_codes
        ON rent_transactions.sigungu_code = legal_dong_codes.sigungu_code
        AND rent_transactions.eupmyeondong_name = legal_dong_codes.eupmyeondong_name
)

SELECT
    with_legal_dong.*,
    round(coalesce(
        floor_area_prices.public_price_won,
        area_prices.public_price_won,
        building_prices.public_price_won_per_m2 * with_legal_dong.exclusive_area_m2
    ))::BIGINT AS public_price_won,
    CASE
        WHEN floor_area_prices.unit_count = 1 THEN 'exact'
        WHEN floor_area_prices.unit_count > 1 THEN 'floor_area_median'
        WHEN area_prices.public_price_won IS NOT NULL THEN 'area_median'
        WHEN building_prices.public_price_won_per_m2 IS NOT NULL THEN 'building_median'
    END AS public_price_match_method,
    building_prices.base_date AS public_price_base_date
FROM with_legal_dong
LEFT JOIN building_prices
    USING (legal_dong_code, main_lot_number, sub_lot_number)
LEFT JOIN area_prices
    ON area_prices.legal_dong_code = with_legal_dong.legal_dong_code
    AND area_prices.main_lot_number = with_legal_dong.main_lot_number
    AND area_prices.sub_lot_number = with_legal_dong.sub_lot_number
    AND area_prices.exclusive_area_m2 = round(with_legal_dong.exclusive_area_m2, 1)
LEFT JOIN floor_area_prices
    ON floor_area_prices.legal_dong_code = with_legal_dong.legal_dong_code
    AND floor_area_prices.main_lot_number = with_legal_dong.main_lot_number
    AND floor_area_prices.sub_lot_number = with_legal_dong.sub_lot_number
    AND floor_area_prices.exclusive_area_m2 = round(with_legal_dong.exclusive_area_m2, 1)
    AND floor_area_prices.floor = with_legal_dong.floor
