"""Load the raw CMS CSV into DuckDB, unchanged.

Every column is loaded as text (all_varchar). Data types are set in the
dbt staging model, so the raw table is an exact copy of the CMS file and
every typing decision is visible in SQL.

Run from the repo root:
    python scripts/load_raw.py
"""

from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / "data" / "raw" / "PHY_R26_P05_V10_D24_Prov_Svc.csv"
DB_PATH = ROOT / "data" / "medicare.duckdb"


def main() -> None:
    if not CSV_PATH.exists():
        raise SystemExit(
            f"CSV not found: {CSV_PATH}\n"
            "Download it from CMS first (see README)."
        )

    con = duckdb.connect(str(DB_PATH))
    con.execute(f"""
        create or replace table raw_phys_2024 as
        select *
        from read_csv('{CSV_PATH}', header = true, all_varchar = true)
    """)

    rows = con.sql("select count(*) from raw_phys_2024").fetchone()[0]
    non_text = con.sql("""
        select count(*)
        from information_schema.columns
        where table_name = 'raw_phys_2024' and data_type <> 'VARCHAR'
    """).fetchone()[0]
    con.close()

    print(f"Loaded {rows:,} rows into raw_phys_2024")
    print(f"Columns not stored as text: {non_text}")


if __name__ == "__main__":
    main()
