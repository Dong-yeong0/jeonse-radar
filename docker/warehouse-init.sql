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
