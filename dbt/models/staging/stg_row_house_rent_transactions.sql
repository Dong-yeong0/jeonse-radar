WITH raw_rows AS (
    SELECT * FROM {{ source('raw', 'row_house_rent_transactions') }}
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
        {{ payload_text('floor') }}::INT AS floor,
        make_date(
            {{ payload_text('dealYear') }}::INT,
            {{ payload_text('dealMonth') }}::INT,
            {{ payload_text('dealDay') }}::INT
        ) AS contract_date,
        {{ ten_thousand_won_to_won('deposit') }} AS deposit_won,
        {{ ten_thousand_won_to_won('monthlyRent') }} AS monthly_rent_won,
        {{ payload_text('contractType') }} AS contract_type,
        to_date(nullif(split_part({{ payload_text('contractTerm') }}, '~', 1), ''), 'YY.MM') AS contract_start_month,
        to_date(nullif(split_part({{ payload_text('contractTerm') }}, '~', 2), ''), 'YY.MM') AS contract_end_month,
        {{ ten_thousand_won_to_won('preDeposit') }} AS previous_deposit_won,
        {{ ten_thousand_won_to_won('preMonthlyRent') }} AS previous_monthly_rent_won,
        {{ payload_text('useRRRight') }} IS NOT DISTINCT FROM '사용' AS used_renewal_right,
        loaded_at
    FROM source
)

SELECT
    *,
    monthly_rent_won = 0 AS is_jeonse
FROM renamed
