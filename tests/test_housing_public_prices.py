import csv

import pytest

from ingestion.housing_public_prices import COLUMNS, iter_rows


def write_csv(path, rows):
    with open(path, "w", encoding="utf-8-sig", newline="") as csv_file:
        csv.writer(csv_file).writerows(rows)


def make_row(sido_name):
    row = [""] * len(COLUMNS)
    row[COLUMNS.index("sido_name")] = sido_name
    return row


def test_iter_rows_keeps_only_requested_sido(tmp_path):
    csv_path = tmp_path / "prices.csv"
    write_csv(
        csv_path,
        [["header"] * len(COLUMNS), make_row("서울특별시"), make_row("부산광역시")],
    )

    rows = list(iter_rows(csv_path, {"서울특별시"}))

    assert [row[COLUMNS.index("sido_name")] for row in rows] == ["서울특별시"]


def test_iter_rows_rejects_unexpected_layout(tmp_path):
    csv_path = tmp_path / "prices.csv"
    write_csv(csv_path, [["only", "three", "columns"]])

    with pytest.raises(ValueError):
        list(iter_rows(csv_path, {"서울특별시"}))
