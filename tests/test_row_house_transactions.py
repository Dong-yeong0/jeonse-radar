from pathlib import Path

import pytest

from ingestion.row_house_transactions import ApiError, parse

FIXTURES = Path(__file__).parent / "fixtures"


def test_parse_rent():
    items, total = parse((FIXTURES / "row_house_rent_11500_202410.xml").read_bytes())
    assert total == 875
    assert len(items) == 3
    assert items[0]["jibun"] == "346-82"
    assert items[0]["deposit"] == "21,870"


def test_parse_sale_keeps_cancellation_fields():
    items, _ = parse((FIXTURES / "row_house_sale_11500_202410.xml").read_bytes())
    assert [item["cdealType"] for item in items] == [" ", "O"]


def test_parse_error_envelope():
    with pytest.raises(ApiError) as error:
        parse((FIXTURES / "row_house_sale_error_not_registered.xml").read_bytes())
    assert error.value.code == "30"
