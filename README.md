# Medicare New-Patient E/M Service Share

What share of each provider's reported office/outpatient E/M services are billed using new-patient codes, and how does that share vary across specialties in fee-for-service Medicare?

The share is a proxy for a provider's new-patient visit mix. It is computed from CMS-reported service counts, which are not counts of unique visits or unique patients.

Status: analysis complete for data year 2024. Every number in [Results](#results) is built by dbt and checked against the reproduction targets by `dbt build`.

## Data

**Sources:** CMS Medicare Physician & Other Practitioners, data year 2024, release `R26_P05_V10_D24`. Two files from the same release:

| File | Grain | Rows | Used for |
|---|---|---|---|
| [by Provider and Service](https://data.cms.gov/provider-summary-by-type-of-service/medicare-physician-other-practitioners/medicare-physician-other-practitioners-by-provider-and-service): `PHY_R26_P05_V10_D24_Prov_Svc.csv` (about 3 GB) | NPI x HCPCS code x place of service | 9,781,673 | Service counts |
| [by Provider](https://data.cms.gov/provider-summary-by-type-of-service/medicare-physician-other-practitioners/medicare-physician-other-practitioners-by-provider): `MUP_PHY_R26_P05_V10_D24_Prov.csv` (about 485 MB) | NPI | 1,296,739 | Suppression bounds |

**Why 2024:** It is the most recent data year CMS has published. It also comes after the 2021 office E/M coding changes (99201 was deleted, which is why new-patient codes are 99202-99205), so the code set is consistent with current billing. This is one year of fee-for-service data, not a trend analysis, and no claim is made that 2024 is representative of other years.

## Results

All numbers below are produced by `dbt build` and checked by tests against the [reproduction targets](#reproduction-targets). Ranges are suppression bounds (see [Suppression bounds](#suppression-bounds)): they show how far the share could move if hidden rows were filled in under the stated assumptions. They do not cover sampling variation or confounding.

### Overall

| Group | Specialties | Providers | Observed share | Scenario D range (primary) | Scenario A range |
|---|--:|--:|--:|---|---|
| Main comparison | 66 | 400,495 | 10.38% | 7.74% to 22.50% | 8.78% to 15.68% |
| Eye care | 2 | 35,378 | 11.83% | 10.10% to 19.00% | 10.69% to 16.15% |

About 1 in 10 visible level 2-5 office/outpatient E/M services in the main comparison is billed with a new-patient code. The range extends further above the observed value than below it: hidden services added to the small numerator move the share more than hidden services added to the large denominator.

### Specialty comparisons

- **259 of 2,145 specialty pairs (12%) are suppression-robust under Scenario D.** 51 of the 66 specialties appear in at least one robust pair.
- **The robust comparisons identify two non-overlapping groups.** 22 specialties are robustly higher than at least one other specialty, 29 are robustly lower than at least one, and no specialty is in both groups. This holds in every Scenario D sensitivity check.
  - **Higher group** (observed 18.2% to 37.7%): mostly surgical and procedural specialties, such as Colorectal, Thoracic, Hand, Cardiac, Neurosurgery, General Surgery, Otolaryngology, and Orthopedic Surgery, plus Sports Medicine, Sleep Medicine, and Podiatry.
  - **Lower group** (observed 3.0% to 13.0%): primary care (Family Practice 3.0%, Internal Medicine 3.1%, General Practice 4.8%, Nurse Practitioner 7.2%) and medical specialties that follow patients over many visits (Hematology-Oncology, Medical Oncology, Hematology, Endocrinology, Rheumatology, Cardiology).
  - **The separation is directional, not complete.** Of the 638 possible pairs between the two groups, 259 (41%) are robust. Only one specialty is robustly higher than every member of the lower group (Hand Surgery), and only one is robustly lower than every member of the higher group (Certified Clinical Nurse Specialist). No pair within a group is robust, so the data does not order specialties within either group.
  - **15 specialties are in no robust pair.** Their observed shares (9.6% to 24.6%) overlap both groups, for example Gastroenterology (24.6%, range 11.1% to 38.8%) and Neurology (17.5%, range 8.8% to 28.1%).
- **The smallest observed difference among robust pairs is 11.6 percentage points** (Rheumatology 9.2% vs. Sleep Medicine 20.9%). Smaller observed differences are never robust to suppression in this data.
- **Eye care:** Optometry 12.7% (9.9% to 21.9%) and Ophthalmology 11.4% (10.2% to 17.4%). The ranges overlap, so the two are not distinguishable. Eye care is not compared with the main group because its code family is different.

### Sensitivity checks

All Scenario D, main comparison.

| Check | Specialties | Providers | Share and range | Robust pairs | Change vs. primary |
|---|--:|--:|---|---|---|
| Primary | 66 | 400,495 | 10.38% (7.74% to 22.50%) | 259 of 2,145 | |
| 99211 included | 66 | 400,742 | 10.33% (7.71% to 22.41%) | 264 of 2,145 | 5 gained, 0 lost, 0 reversed |
| Cap of 11.7 per hidden new-patient slot | 66 | 400,495 | 10.38% (7.74% to 20.70%) | 342 of 2,145 | 83 gained, 0 lost, 0 reversed |
| Eligibility on visible E/M + G* >= 100 | 74 | 567,223 | 10.58% (6.90% to 27.93%) | 134 of 2,701 | 0 gained, 125 lost, 0 reversed |

- **No robust ordering reverses in any check.** Checks only widen or narrow the ranges.
- **99211:** the largest change in any specialty's share is 0.40 points. The exclusion does not drive the results.
- **Cap of 11.7:** only upper bounds move. The primary analysis uses the more cautious cap of 16, so 259 is the conservative count.
- **Eligibility on potential volume** has the largest effect. It adds 166,728 providers and 8 specialties, mostly therapy and chiropractic providers (Physical Therapist, Occupational Therapist, Chiropractic, Speech Language Pathologist) that reach 100 only because G* includes their hidden non-E/M services. It also raises surgical shares (Cardiac Surgery from 31.9% to 40.1%, as eligible providers grow from 294 to 773). The visible-volume rule therefore likely understates shares in the higher group; it does not create the separation between groups.

### Interpretation

These results describe billing. They do not show why the groups differ, and they do not measure access to care.

- **A plausible explanation, not tested here:** specialties in the higher group mostly see referred patients for a defined problem, and specialties in the lower group follow the same patients over many visits.
- **Hospital-predominant specialties (†) are all in the lower half** (observed 12.0% or less). Under the CMS rule, qualifying professional services received in the hospital from the same physician, or a same-specialty physician in the same group practice, can establish a patient before their first office visit. This may contribute to lower office new-patient shares in these specialties, although the aggregate data cannot show whether the hospital and office services occurred within the same group practice.
- **Same-specialty group billing** pushes shares down more in larger groups (see [Limitations](#limitations)). Group size differs by specialty, so part of the difference between groups could reflect practice structure.
- **Specialties marked ‡ have eligible shares below 10%.** Diagnostic Radiology, Pathology, and Emergency Medicine appear in robust pairs, but their eligible providers are under 6% of the specialty, so those results describe an unusual subset of it.
- **What would make this wrong:** a suppressed new-patient row holding more than 16 services would understate upper bounds and could make some robust pairs not robust. Nurse Practitioner and Physician Assistant results assume they are treated as the same specialty as the physicians they work with, which is not verified in the CMS manual.

<details>
<summary>All 66 main-comparison specialties</summary>

"Robustly above" and "Robustly below" count the specialties this one is robustly higher or lower than under Scenario D. † hospital-predominant. ‡ very low eligible coverage: fewer than 10% of individual NPIs in the specialty met the eligibility threshold. This is a descriptive flag for reading the table, not a statistical cutoff.

| Specialty | Eligible providers | Eligible share | Observed | Scenario D range | Robustly above | Robustly below |
|---|--:|--:|--:|---|--:|--:|
| Colorectal Surgery (Proctology) | 1,012 | 60.1% | 37.7% | 22.0% to 55.0% | 21 | 0 |
| Thoracic Surgery | 738 | 28.4% | 35.6% | 22.3% to 54.2% | 22 | 0 |
| Hand Surgery | 1,488 | 89.7% | 32.8% | 24.8% to 42.7% | 29 | 0 |
| Cardiac Surgery | 294 | 26.9% | 31.9% | 21.2% to 48.1% | 18 | 0 |
| Plastic and Reconstructive Surgery | 1,066 | 27.3% | 31.5% | 16.9% to 48.7% | 9 | 0 |
| Neurosurgery | 2,902 | 56.4% | 31.1% | 19.9% to 49.0% | 17 | 0 |
| Radiation Oncology | 2,845 | 56.4% | 30.5% | 15.4% to 47.9% | 6 | 0 |
| Oral Surgery (Dentist only) | 145 | 16.2% | 30.0% | 23.7% to 39.3% | 27 | 0 |
| Maxillofacial Surgery | 96 | 16.0% | 29.8% | 18.3% to 45.7% | 12 | 0 |
| General Surgery | 6,954 | 33.0% | 29.7% | 18.4% to 47.8% | 14 | 0 |
| Otolaryngology | 7,399 | 82.7% | 27.4% | 19.2% to 37.0% | 17 | 0 |
| Surgical Oncology | 644 | 52.2% | 26.0% | 16.9% to 44.0% | 9 | 0 |
| Dentist | 52 | 25.6% | 25.5% | 17.9% to 34.9% | 11 | 0 |
| Sports Medicine | 1,588 | 81.4% | 25.0% | 20.6% to 35.4% | 17 | 0 |
| Gastroenterology | 8,747 | 59.1% | 24.6% | 11.1% to 38.8% | 0 | 0 |
| Diagnostic Radiology ‡ | 205 | 0.6% | 24.4% | 13.7% to 39.6% | 1 | 0 |
| Vascular Surgery | 2,779 | 71.2% | 23.8% | 14.2% to 39.4% | 2 | 0 |
| Interventional Radiology ‡ | 192 | 7.5% | 22.5% | 12.4% to 38.4% | 0 | 0 |
| Peripheral Vascular Disease | 42 | 82.4% | 21.3% | 15.5% to 33.7% | 6 | 0 |
| Sleep Medicine | 644 | 73.7% | 20.9% | 18.1% to 26.5% | 11 | 0 |
| Orthopedic Surgery | 17,170 | 79.2% | 20.0% | 15.3% to 32.2% | 6 | 0 |
| Emergency Medicine ‡ | 2,640 | 5.3% | 18.7% | 14.4% to 31.9% | 2 | 0 |
| Allergy/ Immunology | 2,144 | 65.5% | 18.5% | 6.1% to 37.6% | 0 | 0 |
| Pathology ‡ | 52 | 0.4% | 18.5% | 13.4% to 27.9% | 1 | 0 |
| Podiatry | 12,349 | 79.5% | 18.2% | 13.9% to 28.5% | 1 | 0 |
| Neurology | 9,020 | 54.4% | 17.5% | 8.8% to 28.1% | 0 | 0 |
| Physical Medicine and Rehabilitation | 4,161 | 49.0% | 16.0% | 12.0% to 26.9% | 0 | 0 |
| Micrographic Dermatologic Surgery | 295 | 77.0% | 16.0% | 12.1% to 27.3% | 0 | 0 |
| Clinical Cardiac Electrophysiology | 2,240 | 87.5% | 15.4% | 11.7% to 28.2% | 0 | 0 |
| Critical Care (Intensivists) | 825 | 16.4% | 15.1% | 11.7% to 28.9% | 0 | 0 |
| Gynecological Oncology | 760 | 72.7% | 14.8% | 7.3% to 36.4% | 0 | 0 |
| Certified Registered Nurse Anesthetist (CRNA) ‡ | 48 | 0.1% | 14.6% | 8.3% to 33.8% | 0 | 0 |
| Obstetrics & Gynecology | 4,083 | 17.9% | 14.0% | 8.6% to 32.0% | 0 | 0 |
| Hospice and Palliative Care | 329 | 18.3% | 13.4% | 10.7% to 26.9% | 0 | 0 |
| Urology | 8,011 | 84.6% | 13.0% | 9.1% to 23.1% | 0 | 2 |
| Pulmonary Disease | 6,647 | 61.7% | 12.8% | 10.2% to 23.5% | 0 | 2 |
| Hospitalist † ‡ | 700 | 3.4% | 12.0% | 9.3% to 25.0% | 0 | 0 |
| Preventive Medicine | 98 | 37.3% | 11.9% | 9.7% to 23.6% | 0 | 2 |
| Pain Management | 2,301 | 81.1% | 11.8% | 9.5% to 21.6% | 0 | 4 |
| Physician Assistant | 45,577 | 40.5% | 11.4% | 8.8% to 25.0% | 0 | 0 |
| Anesthesiology ‡ | 1,977 | 4.8% | 11.1% | 8.7% to 21.9% | 0 | 4 |
| Dermatology | 11,001 | 87.2% | 10.9% | 9.0% to 18.6% | 0 | 8 |
| Interventional Cardiology † | 3,919 | 84.3% | 10.4% | 8.0% to 22.2% | 0 | 3 |
| Advanced Heart Failure and Transplant Cardiology † | 613 | 74.0% | 9.6% | 7.4% to 26.4% | 0 | 0 |
| Interventional Pain Management | 1,238 | 84.6% | 9.5% | 7.8% to 18.1% | 0 | 10 |
| Rheumatology | 4,315 | 84.1% | 9.2% | 7.4% to 17.7% | 0 | 12 |
| Undersea and Hyperbaric Medicine | 86 | 75.4% | 9.1% | 6.6% to 23.5% | 0 | 2 |
| Endocrinology | 5,190 | 80.7% | 9.1% | 6.7% to 16.0% | 0 | 14 |
| Infectious Disease † | 1,637 | 25.4% | 9.0% | 4.0% to 24.0% | 0 | 1 |
| Cardiology † | 15,506 | 78.5% | 8.6% | 7.2% to 18.3% | 0 | 9 |
| Pediatric Medicine | 452 | 25.5% | 8.5% | 5.8% to 24.1% | 0 | 1 |
| Nuclear Medicine † ‡ | 38 | 7.0% | 8.2% | 4.9% to 18.8% | 0 | 8 |
| Nephrology † | 6,662 | 70.1% | 8.2% | 5.4% to 23.0% | 0 | 2 |
| Hematology | 615 | 66.6% | 7.6% | 3.0% to 16.6% | 0 | 14 |
| Nurse Practitioner | 79,539 | 39.1% | 7.2% | 5.5% to 20.7% | 0 | 5 |
| Hematology-Oncology | 7,744 | 84.6% | 7.0% | 4.6% to 14.1% | 0 | 19 |
| Medical Oncology | 3,097 | 81.4% | 6.9% | 5.1% to 15.0% | 0 | 17 |
| Certified Nurse Midwife ‡ | 33 | 3.5% | 6.8% | 4.7% to 21.3% | 0 | 4 |
| Geriatric Medicine † | 898 | 47.6% | 6.7% | 5.6% to 18.3% | 0 | 9 |
| Osteopathic Manipulative Medicine | 397 | 59.5% | 6.0% | 4.9% to 16.1% | 0 | 14 |
| Hematopoietic Cell Transplantation and Cellular Therapy | 105 | 73.4% | 5.5% | 3.1% to 18.9% | 0 | 8 |
| General Practice | 1,551 | 43.6% | 4.8% | 4.0% to 15.1% | 0 | 17 |
| Addiction Medicine | 81 | 28.9% | 4.4% | 3.8% to 15.0% | 0 | 17 |
| Certified Clinical Nurse Specialist | 591 | 41.4% | 3.5% | 2.9% to 13.1% | 0 | 22 |
| Internal Medicine † | 42,071 | 44.9% | 3.1% | 2.6% to 14.4% | 0 | 17 |
| Family Practice | 51,857 | 62.0% | 3.0% | 2.4% to 17.7% | 0 | 12 |


</details>

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

**Further sensitivity checks:** a cap of 11.7 per new-patient slot in Scenario D; eligibility defined as visible E/M + G* >= 100 (567,223 providers, 74 specialties); 99211 included.

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

Primary Scenario D, main comparison (model `fct_sensitivity_summary`):

| | 99211 excluded | 99211 included |
|---|---|---|
| Providers | 400,495 | 400,742 |
| Overall share | 10.38% [7.74%, 22.50%] | 10.33% [7.71%, 22.41%] |
| Suppression-robust specialty pairs | 259 of 2,145 | 264 of 2,145 |
| Largest change in any specialty's share | | 0.40 points |

No robust pair is lost or reversed by including 99211. The 5 pairs gained were borderline.

### Reproduction targets

Results from the exploratory analysis that the dbt models must reproduce. `tests/assert_reproduction_targets.sql` checks each one, and `dbt build` fails if any no longer matches. The potential-eligibility target was corrected from 567,410 when the dbt build exposed an error in the exploratory query (187 providers without visible E/M rows had used the wrong gap).

| Check | Expected |
|---|---|
| Main comparison | 400,495 providers, 66 specialties |
| Eye care | 35,378 providers, 2 specialties |
| Scenario D, main comparison | 10.38% [7.74%, 22.50%], 259 robust pairs of 2,145 |
| Scenario D with 99211 included | 400,742 providers, 10.33% [7.71%, 22.41%], 264 robust pairs |
| Scenario D, eligibility = visible E/M + G* >= 100 | 567,223 providers, 74 specialties, 134 robust pairs of 2,701 |

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
- Results are descriptive. A suppression-robust difference shows the data supports the difference, not why it exists. For example, a higher share in surgical specialties may reflect referral-based practice; this is not tested here, and the share does not measure access.
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

3. Load both CSVs into DuckDB (all columns as text; types are set in dbt staging):
   ```
   python scripts/load_raw.py
   ```
   Expected: `Loaded 9,781,673 rows into raw_phys_2024` and `Loaded 1,296,739 rows into raw_phys_prov_2024`, each followed by `Columns not stored as text: 0`.

4. Build and test all models:
   ```
   cp profiles.example.yml profiles.yml
   dbt build
   ```
   Expected: `Done. PASS=38 WARN=0 ERROR=0`. Results are in `fct_specialty_bounds`, `fct_specialty_pairs`, and `fct_sensitivity_summary` in `data/medicare.duckdb`.

The raw CSVs and the DuckDB file are gitignored and never committed.

## References

- CMS, [Medicare Claims Processing Manual, Chapter 12](https://www.cms.gov/regulations-and-guidance/guidance/manuals/downloads/clm104c12.pdf), §30.6.7
- CMS, [Physician & Other Practitioners Methodology, RY25](https://data.cms.gov/sites/default/files/2025-04/MUP_PHY_RY25_202350312_Methodology_508.pdf)
- CMS, [by Provider and Service Data Dictionary, RY25](https://data.cms.gov/sites/default/files/2025-03/bbb1e50e-5ba8-42ed-b072-18368b6f37f9/MUP_PHY_RY25_20250312_DD_PRV_SVC_508.pdf)
- CMS, [by Provider Data Dictionary, RY21](https://data.cms.gov/sites/default/files/2021-10/5d9da495-6798-4428-8260-ce362d8fc5a5/MUP_PHY_RY21_20211021_DD_PRV.pdf)
