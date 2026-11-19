"""Load the raw CMS CSVs into DuckDB, unchanged.

Every column is loaded as text (all_varchar). Data types are set in the
dbt staging models, so each raw table is an exact copy of the CMS file and
every typing decision is visible in SQL.

Run from the repo root:
    python scripts/load_raw.py
"""

from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = ROOT / "data" / "raw"
DB_PATH = ROOT / "data" / "medicare.duckdb"

# (CSV file name, DuckDB table name)
FILES = [
    ("PHY_R26_P05_V10_D24_Prov_Svc.csv", "raw_phys_2024"),       # by Provider and Service
    ("MUP_PHY_R26_P05_V10_D24_Prov.csv", "raw_phys_prov_2024"),  # by Provider
]


def main() -> None:
    missing = [name for name, _ in FILES if not (RAW_DIR / name).exists()]
    if missing:
        raise SystemExit(
            "CSV not found in data/raw/: " + ", ".join(missing) + "\n"
            "Download it from CMS first (see README)."
        )

    con = duckdb.connect(str(DB_PATH))
    for name, table in FILES:
        con.execute(f"""
            create or replace table {table} as
            select *
            from read_csv('{RAW_DIR / name}', header = true, all_varchar = true)
        """)

        rows = con.sql(f"select count(*) from {table}").fetchone()[0]
        non_text = con.sql(f"""
            select count(*)
            from information_schema.columns
            where table_name = '{table}' and data_type <> 'VARCHAR'
        """).fetchone()[0]

        print(f"Loaded {rows:,} rows into {table}")
        print(f"Columns not stored as text: {non_text}")

    con.close()


if __name__ == "__main__":
    main()
