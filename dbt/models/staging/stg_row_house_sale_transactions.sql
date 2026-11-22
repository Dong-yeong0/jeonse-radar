with source as (
    select * from {{ source('raw', 'row_house_sale_transactions') }}
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
        {{ payload_text('landAr') }}::numeric as land_area_m2,
        {{ payload_text('floor') }}::int as floor,
        make_date(
            {{ payload_text('dealYear') }}::int,
            {{ payload_text('dealMonth') }}::int,
            {{ payload_text('dealDay') }}::int
        ) as contract_date,
        {{ ten_thousand_won_to_won('dealAmount') }} as sale_price_won,
        {{ payload_text('dealingGbn') }} as dealing_type,
        {{ payload_text('buyerGbn') }} as buyer_type,
        {{ payload_text('slerGbn') }} as seller_type,
        {{ payload_text('estateAgentSggNm') }} as agent_sigungu_name,
        to_date({{ payload_text('rgstDate') }}, 'YY.MM.DD') as registration_date,
        {{ payload_text('cdealType') }} is not distinct from 'O' as is_cancelled,
        to_date({{ payload_text('cdealDay') }}, 'YY.MM.DD') as cancelled_date,
        loaded_at
    from source
)

select * from renamed
