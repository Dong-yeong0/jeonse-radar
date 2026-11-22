WITH raw_rows AS (
    SELECT * FROM {{ source('raw', 'row_house_sale_transactions') }}
),

latest_batches AS (
    SELECT sigungu_code, deal_year_month, max(loaded_at) AS loaded_at
    FROM raw_rows
    GROUP BY sigungu_code, deal_year_month
),

source AS (
    SELECT raw_rows.*
    FROM raw_rows
    INNER JOIN latest_batches USING (sigungu_code, deal_year_month, loaded_at)
),

renamed AS (
    SELECT
        sigungu_code,
        deal_year_month,
        {{ payload_text('umdNm') }} AS eupmyeondong_name,
        {{ payload_text('jibun') }} AS jibun,
        {{ lot_number('jibun', 1) }} AS main_lot_number,
        {{ lot_number('jibun', 2) }} AS sub_lot_number,
        {{ payload_text('mhouseNm') }} AS building_name,
        {{ payload_text('houseType') }} AS house_type,
        {{ payload_text('buildYear') }}::INT AS build_year,
        {{ payload_text('excluUseAr') }}::NUMERIC AS exclusive_area_m2,
        {{ payload_text('landAr') }}::NUMERIC AS land_area_m2,
        {{ payload_text('floor') }}::INT AS floor,
        make_date(
            {{ payload_text('dealYear') }}::INT,
            {{ payload_text('dealMonth') }}::INT,
            {{ payload_text('dealDay') }}::INT
        ) AS contract_date,
        {{ ten_thousand_won_to_won('dealAmount') }} AS sale_price_won,
        {{ payload_text('dealingGbn') }} AS dealing_type,
        {{ payload_text('buyerGbn') }} AS buyer_type,
        {{ payload_text('slerGbn') }} AS seller_type,
        {{ payload_text('estateAgentSggNm') }} AS agent_sigungu_name,
        to_date({{ payload_text('rgstDate') }}, 'YY.MM.DD') AS registration_date,
        {{ payload_text('cdealType') }} IS NOT DISTINCT FROM 'O' AS is_cancelled,
        to_date({{ payload_text('cdealDay') }}, 'YY.MM.DD') AS cancelled_date,
        loaded_at
    FROM source
)

SELECT * FROM renamed
