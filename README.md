# Medicare New-Patient E/M Service Share

What share of each provider's reported office/outpatient E/M services are billed using new-patient codes, and how does that share vary across specialties in fee-for-service Medicare?

The share is a proxy for a provider's new-patient visit mix. It is computed from CMS-reported service counts, which are not counts of unique visits or unique patients.

Status: in progress. Data load and staging are complete. The methodology below is the approved specification; dbt models that implement it are next.

## Data

**Sources:** CMS Medicare Physician & Other Practitioners, data year 2024, release `R26_P05_V10_D24`. Two files from the same release:

| File | Grain | Rows | Used for |
|---|---|---|---|
| [by Provider and Service](https://data.cms.gov/provider-summary-by-type-of-service/medicare-physician-other-practitioners/medicare-physician-other-practitioners-by-provider-and-service): `PHY_R26_P05_V10_D24_Prov_Svc.csv` (about 3 GB) | NPI x HCPCS code x place of service | 9,781,673 | Service counts |
| [by Provider](https://data.cms.gov/provider-summary-by-type-of-service/medicare-physician-other-practitioners/medicare-physician-other-practitioners-by-provider): `MUP_PHY_R26_P05_V10_D24_Prov.csv` (about 485 MB) | NPI | 1,296,739 | Suppression bounds |

**Why 2024:** It is the most recent data year CMS has published. It also comes after the 2021 office E/M coding changes (99201 was deleted, which is why new-patient codes are 99202-99205), so the code set is consistent with current billing. This is one year of fee-for-service data, not a trend analysis, and no claim is made that 2024 is representative of other years.

## Methodology

### Metric

```
new-patient E/M service share = sum(services billed with 99202-99205)
                                / sum(services billed with 99202-99205 + 99212-99215)
```

- Services are CMS-reported service counts (`Tot_Srvcs`). A beneficiary can have more than one service, so these are not unique visit or patient counts.
- Services are summed per provider, then per specialty. Rates are never averaged.
- Facility (F) and non-facility (O) place of service are combined.
- The denominator is practitioner-level office/outpatient E/M services at levels 2-5. It is not every office/outpatient E/M service billed under the NPI (see 99211 below).

**What "new patient" means.** This is the CMS billing classification, not a clinical or enrollment status. CMS defines a new patient as one "who has not received any professional services, i.e., E/M service or other face-to-face service (e.g., surgical procedure) from the physician or physician group practice (same physician specialty) within the previous 3 years" (Medicare Claims Processing Manual, Ch. 12, §30.6.7.A). So:

- A service billed with a new-patient code means the patient had no face-to-face service from the billing practitioner **or a same-specialty colleague in the same group** in the prior 3 years. The patient may have been seen more than 3 years ago.
- A service billed with an established-patient code does not mean this NPI saw the patient before. A same-specialty colleague's service is enough.
- The metric is not a count of patients new to the individual NPI, and not a count of patients new to Medicare.

**99211 is excluded.** 99211 is an established-patient code that "may not require presence of" the practitioner (CMS code description) and has had no new-patient counterpart since 99201 was deleted in 2021. Including it would add staff-performed services to the denominator that could never appear in the numerator. Sensitivity results are below.

### Eligibility

- Individual NPIs only (entity code `I`).
- At least **100 visible E/M services** (99202-99205 + 99212-99215) in the code-level file. "Visible" means rows CMS published; see suppression below.
- A specialty (CMS `Rndrng_Prvdr_Type`) is reported only if it has at least **30 eligible providers**.

### Specialty scope

| Group | Specialties | Treatment | Reason |
|---|---|---|---|
| Main comparison | 66 specialties | Metric as defined above | 99202-99215 are their office/outpatient E/M codes |
| Eye care | Ophthalmology, Optometry | Reported separately. Adds 92002/92004 (new-patient) and 92012/92014 (established-patient) to the numerator, denominator, and eligibility count | Eye exam codes are a parallel new/established family under the same 3-year rule |
| Behavioral health | Psychiatry, Geriatric Psychiatry, Neuropsychiatry, Psychologist (Clinical), Licensed Clinical Social Worker, Licensed Professional Counselor | Excluded | See below |
| Not a specialty | Undefined Physician type | Excluded | No meaningful specialty label |

**Why behavioral health is excluded.** Initial evaluations are mostly billed as 90791/90792. These are psychiatric diagnostic evaluation codes: they describe a type of service, have no new/established distinction, and can be billed for established patients. In the data they are billed more than once per beneficiary far more often than new-patient E/M codes (1.05 services per beneficiary vs. 1.0001 for 99204). Adding them would mix a service type with the billing definition of a new patient and break the matched new/established structure. The metric makes no claim about these specialties.

**Flags (reported, not excluded).** Both are computed per specialty:

- **Hospital-predominant:** among the specialty's eligible providers, services billed with initial hospital care codes (99221-99223) plus initial nursing facility care codes (99304-99306), both places of service, exceed services billed with 99202-99205. For these specialties the metric covers only their office/outpatient practice.
- **Eligible share:** eligible individual NPIs divided by all individual NPIs with that specialty in the by-Provider file (organizational NPIs are not in the numerator or the denominator). A low value means the eligible providers are a small, possibly unusual subset of the specialty, as in Diagnostic Radiology and Pathology.

### Population reconciliation

| Step | Providers |
|---|---|
| NPIs in the by-Provider file | 1,296,739 |
| Individuals | 1,235,757 |
| Eligible, all specialties (E/M codes only) | 430,118 |
| minus eye care | -21,967 |
| minus behavioral health | -7,536 |
| minus Undefined Physician type | -90 |
| Main scope, eligible | 400,525 |
| minus 8 specialties with fewer than 30 eligible providers | -30 |
| **Main comparison** | **400,495 providers, 66 specialties** |
| **Eye care** (eligibility includes eye codes, which adds 13,411 to the 21,967) | **35,378 providers, 2 specialties** |

### Suppression bounds

CMS excludes any code-level row derived from 10 or fewer beneficiaries, with no marker. A missing row can be a true zero or a suppressed row. The observed share can be biased in either direction, because new-patient and established-patient rows can both be hidden. Instead of imputing hidden values, each specialty gets a range that holds under the stated assumptions.

**Provider gap G\*.** The by-Provider totals are built from all claims, not the redacted rows (CMS methodology, §4.2). For each provider:

```
G* = Med_Tot_Srvcs - visible non-drug services     (when CMS publishes the medical subtotal)
G* = Tot_Srvcs - visible services                  (otherwise)
```

E/M codes are non-drug codes, so hidden E/M services cannot exceed G*. G* also includes hidden services that are not E/M, so it is an upper limit, not an estimate. The medical subtotal is used where available because drug services are counted in dosage units.

**Notation.** For each eligible provider:

- N = visible services billed with 99202-99205
- D = visible services billed with 99202-99205 + 99212-99215
- R_N = number of visible new-patient rows (code x place of service)
- R_E = number of visible established-patient rows (code x place of service)
- P = number of places of service (F, O) in which the provider has any visible E/M row (1 or 2)
- h, e = hidden new-patient and hidden established-patient services, with h >= 0, e >= 0, h + e <= G*
- U_N, U_E = caps on h and e, set by the scenario

Specialty bounds sum over the specialty's eligible providers:

```
lower bound = sum(N) / (sum(D) + sum(U_E))             h = 0,   e = U_E
upper bound = sum(N + U_N) / (sum(D) + sum(U_N))       h = U_N, e = 0
```

The share rises with h and falls with e, so these corners are the extremes. Both corners satisfy h + e <= G* because each cap is at most G*.

**Scenario D (primary).** Every new-patient code x place of service combination can be suppressed (4 codes x 2 places = 8 slots), each holding at most 16 services. Hidden established services are limited only by G*.

```
U_N = min(16 x (8 - R_N), G*)
U_E = G*
```

**Scenario A (sensitivity).** Only places of service where the provider has visible E/M activity can hold suppressed rows. Each missing new-patient slot holds at most 10 services (10 beneficiaries x 1 service each). Each missing established-patient slot holds at most 100 services (10 beneficiaries x 10 services each). Caps are applied per missing slot, summed per provider, then limited by G*.

```
U_N = min(10  x (4P - R_N), G*)
U_E = min(100 x (4P - R_E), G*)
```

4P is the number of possible slots per code family (4 codes x the provider's P places of service); subtracting the visible rows R_N or R_E leaves the missing slots.

**Further sensitivity checks:** a cap of 11.7 per new-patient slot in Scenario D; eligibility defined as visible E/M + G* >= 100 (567,410 providers, 74 specialties); 99211 included.

**Suppression-robust comparison.** Specialty comparisons are considered suppression-robust only when one specialty's lower bound exceeds the other's upper bound. This is a sufficient test under the stated assumptions. Because G* can include hidden services outside the E/M definition, the bounds may be wider than necessary, and the test may not identify every ordering that more detailed claims data could establish. In the other direction, the cap of 16 is an assumption: if a suppressed new-patient row held more than 16 services, upper bounds would be understated.

### Evidence status

| Item | Status |
|---|---|
| Rows from 10 or fewer beneficiaries are excluded, unmarked | Documented (CMS methodology, RY25) and verified in the 2024 data (minimum 11 beneficiaries) |
| Row grain is NPI x HCPCS x place of service, with place of service F or O only | Documented and verified (no duplicate keys) |
| By-Provider totals include suppressed services | Documented (CMS methodology, RY25, §4.2) and verified (visible services never exceed the provider total, for every NPI) |
| Both files have the same specialty per NPI | Verified (0 mismatches) |
| **A suppressed new-patient row has at most 16 services** | **Assumption supported by observed data, not a CMS maximum.** In visible new-patient rows with 11-20 beneficiaries, services exceed beneficiaries by at most 6 (99.9th percentile: 1). 10 beneficiaries + 6 = 16. |
| Scenario A caps (10 per new-patient slot, 100 per established-patient slot, only places of service in use) | Assumptions, used for sensitivity only |
| 2024 (RY26) methodology and dictionary | Not found; RY25 documents used |
| NPs and PAs treated as the same specialty as their physicians for the new-patient rule | Secondary sources only, not verified in the CMS manual |
| New-patient definition | Quoted from the 2026 manual revision; claims are from 2024 |

### 99211 sensitivity

From exploratory queries, to be reproduced by the dbt models (primary Scenario D, main comparison):

| | 99211 excluded | 99211 included |
|---|---|---|
| Providers | 400,495 | 400,742 |
| Overall share | 10.38% [7.74%, 22.50%] | 10.33% [7.71%, 22.41%] |
| Suppression-robust specialty pairs | 259 of 2,145 | 264 of 2,145 |
| Largest change in any specialty's share | | 0.40 points |

No robust pair is lost or reversed by including 99211. The 5 pairs gained were borderline.

### Reproduction targets

Exploratory results the dbt models must reproduce before any findings are published:

| Check | Expected |
|---|---|
| Main comparison | 400,495 providers, 66 specialties |
| Eye care | 35,378 providers, 2 specialties |
| Scenario D, main comparison | 10.38% [7.74%, 22.50%], 259 robust pairs of 2,145 |
| Scenario D with 99211 included | 400,742 providers, 10.33% [7.71%, 22.41%], 264 robust pairs |
| Scenario D, eligibility = visible E/M + G* >= 100 | 567,410 providers, 74 specialties |

### Limitations

**Dataset**
- Fee-for-service Medicare only. Medicare Advantage and non-Medicare patients are not included.
- 2024 only.
- Suppression: 89,266 NPIs have every code-level row suppressed and are absent from the code-level file. Bounds cover suppression only.

**Measurement**
- The metric counts reported services, not unique visits or patients.
- It describes billing, not appointment availability or access.
- Behavioral health and other initial encounters not billed under these codes are not measured. Home visits and inpatient or nursing facility care are out of scope.
- Hospital-predominant specialties are measured on their office/outpatient practice only.

**Provider identity and group structure**
- Individual NPIs only. Services billed under an organizational NPI are not attributed to the individuals who performed them (CMS methodology notes that some providers bill under both).
- New-patient status is defined at the same-specialty group level. A patient new to an individual NPI is billed with an established-patient code if a same-specialty colleague in the group saw them within 3 years. The share therefore understates "new to this NPI", and more so in larger same-specialty groups. Group size differs by specialty, so this can bias comparisons between specialties.
- Specialty is the CMS claims-based label (the specialty with the most services), not board certification.

**Selection and interpretation**
- Eligibility uses visible volume, which is affected by suppression. A sensitivity check uses potential volume.
- Results are descriptive. A suppression-robust difference shows the data supports the difference, not why it exists. For example, a higher share in surgical specialties likely reflects referral-based practice, not better access.
- The bounds do not cover sampling variation or confounding.

## Reproduce

Requires conda and about 4 GB of free disk space.

1. Download both 2024 CSVs from the CMS links above into `data/raw/`, keeping the file names in the table.

2. Create the environment:
   ```
   conda create -n medicare-dbt python=3.11
   conda activate medicare-dbt
   pip install -r requirements.txt
   ```

3. Load the code-level CSV into DuckDB (all columns as text; types are set in dbt staging):
   ```
   python scripts/load_raw.py
   ```
   Expected: `Loaded 9,781,673 rows into raw_phys_2024`.

   Loading the by-Provider file will be added with the dbt models.

The raw CSVs and the DuckDB file are gitignored and never committed.

## References

- CMS, [Medicare Claims Processing Manual, Chapter 12](https://www.cms.gov/regulations-and-guidance/guidance/manuals/downloads/clm104c12.pdf), §30.6.7
- CMS, [Physician & Other Practitioners Methodology, RY25](https://data.cms.gov/sites/default/files/2025-04/MUP_PHY_RY25_202350312_Methodology_508.pdf)
- CMS, [by Provider and Service Data Dictionary, RY25](https://data.cms.gov/sites/default/files/2025-03/bbb1e50e-5ba8-42ed-b072-18368b6f37f9/MUP_PHY_RY25_20250312_DD_PRV_SVC_508.pdf)
- CMS, [by Provider Data Dictionary, RY21](https://data.cms.gov/sites/default/files/2021-10/5d9da495-6798-4428-8260-ce362d8fc5a5/MUP_PHY_RY21_20211021_DD_PRV.pdf)
