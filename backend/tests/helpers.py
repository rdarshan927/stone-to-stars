"""Helpers for building synthetic monthly records."""

from collections.abc import Callable

from app.schemas import MonthlyRecord


def make_records(
    value_fn: Callable[[int, int], float | None],
    start_year: int = 1981,
    end_year: int = 2025,
) -> list[MonthlyRecord]:
    """Build MonthlyRecords from value_fn(year, month); None values are skipped."""
    records = []
    for year in range(start_year, end_year + 1):
        for month in range(1, 13):
            value = value_fn(year, month)
            if value is not None:
                records.append(MonthlyRecord(year=year, month=month, value=value))
    return records
