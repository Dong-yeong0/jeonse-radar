"""Loader for the MOLIT housing public price file (unit-level prices)."""

import csv
import os

COLUMNS = [
    "base_year",
    "base_month",
    "legal_dong_code",
    "road_address",
    "sido_name",
    "sigungu_name",
    "eup_myeon_name",
    "dong_ri_name",
    "special_lot_type_code",
    "main_lot_number",
    "sub_lot_number",
    "special_lot_name",
    "complex_name",
    "building_dong_name",
    "unit_name",
    "exclusive_area",
    "public_price",
    "complex_code",
    "building_dong_code",
    "unit_code",
    "building_register_pk",
]
SIDO_NAME_INDEX = COLUMNS.index("sido_name")
TABLE = "raw.housing_public_prices"


def iter_rows(csv_path, sido_names):
    """Yield raw CSV rows whose sido is in sido_names, without loading the file."""
    with open(csv_path, encoding="utf-8-sig", newline="") as csv_file:
        reader = csv.reader(csv_file)
        header = next(reader)
        if len(header) != len(COLUMNS):
            raise ValueError(f"expected {len(COLUMNS)} columns, got {len(header)}")

        for row in reader:
            if row[SIDO_NAME_INDEX] in sido_names:
                yield row


def load(conn, csv_path, sido_names):
    """Append rows for sidos not yet loaded from this file. Returns rows loaded.

    conn is a psycopg 3 connection (the default for PostgresHook in provider 7.x).
    """
    source_file = os.path.basename(csv_path)
    with conn, conn.cursor() as cursor:
        cursor.execute(
            f"SELECT DISTINCT sido_name FROM {TABLE}"
            " WHERE source_file = %s AND sido_name = ANY(%s)",
            (source_file, list(sido_names)),
        )
        pending = set(sido_names) - {sido_name for (sido_name,) in cursor.fetchall()}
        if not pending:
            return 0

        row_count = 0
        with cursor.copy(
            f"COPY {TABLE} ({', '.join(COLUMNS)}, source_file) FROM STDIN"
        ) as copy:
            for row in iter_rows(csv_path, pending):
                copy.write_row([*row, source_file])
                row_count += 1

    return row_count
