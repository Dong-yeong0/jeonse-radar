WITH source AS (
    SELECT * FROM {{ source('raw', 'housing_public_prices') }}
),

renamed AS (
    SELECT
        make_date(base_year::INT, base_month::INT, 1) AS base_date,
        legal_dong_code,
        left(legal_dong_code, 5) AS sigungu_code,
        nullif(trim(dong_ri_name), '') AS eupmyeondong_name,
        nullif(trim(special_lot_type_code), '') AS special_lot_type_code,
        nullif(trim(main_lot_number), '')::INT AS main_lot_number,
        coalesce(nullif(trim(sub_lot_number), ''), '0')::INT AS sub_lot_number,
        nullif(trim(road_address), '') AS road_address,
        nullif(trim(complex_name), '') AS complex_name,
        nullif(trim(building_dong_name), '') AS building_dong_name,
        nullif(trim(unit_name), '') AS unit_name,
        exclusive_area::NUMERIC AS exclusive_area_m2,
        public_price::BIGINT AS public_price_won,
        complex_code,
        building_dong_code,
        unit_code,
        nullif(trim(building_register_pk), '') AS building_register_pk,
        source_file,
        loaded_at
    FROM source
)

SELECT * FROM renamed
