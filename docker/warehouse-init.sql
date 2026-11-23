CREATE DATABASE metabase;
CREATE SCHEMA raw;

CREATE TABLE raw.row_house_rent_transactions (
    sigungu_code TEXT NOT NULL,
    deal_year_month TEXT NOT NULL,
    payload JSONB NOT NULL,
    source_params JSONB NOT NULL,
    response_hash TEXT,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX row_house_rent_transactions_partition_idx
    ON raw.row_house_rent_transactions (sigungu_code, deal_year_month);

CREATE TABLE raw.row_house_sale_transactions (
    sigungu_code TEXT NOT NULL,
    deal_year_month TEXT NOT NULL,
    payload JSONB NOT NULL,
    source_params JSONB NOT NULL,
    response_hash TEXT,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX row_house_sale_transactions_partition_idx
    ON raw.row_house_sale_transactions (sigungu_code, deal_year_month);

CREATE TABLE raw.housing_public_prices (
    base_year TEXT,
    base_month TEXT,
    legal_dong_code TEXT,
    road_address TEXT,
    sido_name TEXT,
    sigungu_name TEXT,
    eup_myeon_name TEXT,
    dong_ri_name TEXT,
    special_lot_type_code TEXT,
    main_lot_number TEXT,
    sub_lot_number TEXT,
    special_lot_name TEXT,
    complex_name TEXT,
    building_dong_name TEXT,
    unit_name TEXT,
    exclusive_area TEXT,
    public_price TEXT,
    complex_code TEXT,
    building_dong_code TEXT,
    unit_code TEXT,
    building_register_pk TEXT,
    source_file TEXT NOT NULL,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX housing_public_prices_lot_idx
    ON raw.housing_public_prices (legal_dong_code, main_lot_number, sub_lot_number);
