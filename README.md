# Medicare New Patient Visit Share

How much of each provider's office visit volume is new patient visits, and how does that vary within specialty, in fee-for-service Medicare?

Status: in progress. Data load is complete; dbt models are next.

## Data

**Source:** CMS, [Medicare Physician & Other Practitioners - by Provider and Service](https://data.cms.gov/provider-summary-by-type-of-service/medicare-physician-other-practitioners/medicare-physician-other-practitioners-by-provider-and-service), data year 2024.
File used: `PHY_R26_P05_V10_D24_Prov_Svc.csv` (about 3 GB, 9,781,673 rows). One row per provider (NPI), HCPCS code, and place of service.

**Why 2024:** It is the most recent data year CMS has published, which is the main reason. It is also well past the 2021 office visit coding changes (99201 was deleted, which is why new patient visits are 99202-99205) and the COVID-era disruption to visit patterns in 2020-2021.

**Caveats:**
- Fee-for-service Medicare only. Medicare Advantage claims are not included.
- "New patient" is a billing definition: no professional services in the past 3 years from the same physician, or from another physician of the same specialty in the same group. It does not mean new to Medicare.
- CMS suppresses rows with fewer than 11 beneficiaries, so low-volume provider and code combinations are missing.

## Reproduce

Requires conda and about 4 GB of free disk space.

1. Download the 2024 "by Provider and Service" CSV from the CMS link above and save it as `data/raw/PHY_R26_P05_V10_D24_Prov_Svc.csv`.

2. Create the environment:
   ```
   conda create -n medicare-dbt python=3.11
   conda activate medicare-dbt
   pip install -r requirements.txt
   ```

3. Load the CSV into DuckDB (all columns as text; types are set in dbt staging):
   ```
   python scripts/load_raw.py
   ```
   Expected: `Loaded 9,781,673 rows into raw_phys_2024`.

The raw CSV and the DuckDB file are gitignored and never committed.
