-- Fails if any NPI x HCPCS code x place of service appears more than once.
select
    npi,
    hcpcs_code,
    place_of_service,
    count(*) as n_rows
from {{ ref('stg_cms__phys_2024') }}
group by npi, hcpcs_code, place_of_service
having count(*) > 1
