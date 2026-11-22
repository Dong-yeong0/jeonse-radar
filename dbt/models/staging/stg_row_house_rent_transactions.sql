with source as (
    select * from {{ source('raw', 'row_house_rent_transactions') }}
),

renamed as (
    select
        sigungu_code,
        deal_year_month,
        {{ payload_text('umdNm') }} as eupmyeondong_name,
        {{ payload_text('jibun') }} as jibun,
        {{ lot_number('jibun', 1) }} as main_lot_number,
        {{ lot_number('jibun', 2) }} as sub_lot_number,
        {{ payload_text('mhouseNm') }} as building_name,
        {{ payload_text('houseType') }} as house_type,
        {{ payload_text('buildYear') }}::int as build_year,
        {{ payload_text('excluUseAr') }}::numeric as exclusive_area_m2,
        {{ payload_text('floor') }}::int as floor,
        make_date(
            {{ payload_text('dealYear') }}::int,
            {{ payload_text('dealMonth') }}::int,
            {{ payload_text('dealDay') }}::int
        ) as contract_date,
        {{ ten_thousand_won_to_won('deposit') }} as deposit_won,
        {{ ten_thousand_won_to_won('monthlyRent') }} as monthly_rent_won,
        {{ payload_text('contractType') }} as contract_type,
        to_date(nullif(split_part({{ payload_text('contractTerm') }}, '~', 1), ''), 'YY.MM') as contract_start_month,
        to_date(nullif(split_part({{ payload_text('contractTerm') }}, '~', 2), ''), 'YY.MM') as contract_end_month,
        {{ ten_thousand_won_to_won('preDeposit') }} as previous_deposit_won,
        {{ ten_thousand_won_to_won('preMonthlyRent') }} as previous_monthly_rent_won,
        {{ payload_text('useRRRight') }} is not distinct from '사용' as used_renewal_right,
        loaded_at
    from source
)

select
    *,
    monthly_rent_won = 0 as is_jeonse
from renamed
