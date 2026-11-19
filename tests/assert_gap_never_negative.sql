-- The README claims provider totals include all suppressed services, so visible
-- services can never exceed them. Fails if any NPI breaks that by more than rounding.
select npi, gap_basis, gap_services_raw
from {{ ref('int_provider_gap') }}
where gap_services_raw < -0.5
