{{ config(materialized='table') }}

-- One row per NPI that billed any office/outpatient E/M or eye exam code.
-- Visible services only: rows CMS suppressed are not in the source.

with coded as (

    select
        npi,
        provider_type,
        entity_code,
        place_of_service,
        total_services,
        case
            when hcpcs_code in ('99202', '99203', '99204', '99205') then 'em_new'
            when hcpcs_code in ('99212', '99213', '99214', '99215') then 'em_est'
            when hcpcs_code = '99211'                               then 'em_99211'
            when hcpcs_code in ('92002', '92004')                   then 'eye_new'
            when hcpcs_code in ('92012', '92014')                   then 'eye_est'
        end as code_group
    from {{ ref('stg_cms__phys_2024') }}
    where hcpcs_code in (
        '99202', '99203', '99204', '99205',
        '99211', '99212', '99213', '99214', '99215',
        '92002', '92004', '92012', '92014'
    )

)

select
    npi,
    max(provider_type) as provider_type,  -- one type per NPI (verified in step 4)
    max(entity_code)   as entity_code,

    -- visible services
    coalesce(sum(total_services) filter (where code_group = 'em_new'),   0) as em_new_services,
    coalesce(sum(total_services) filter (where code_group = 'em_est'),   0) as em_est_services,
    coalesce(sum(total_services) filter (where code_group = 'em_99211'), 0) as em_99211_services,
    coalesce(sum(total_services) filter (where code_group = 'eye_new'),  0) as eye_new_services,
    coalesce(sum(total_services) filter (where code_group = 'eye_est'),  0) as eye_est_services,

    -- visible rows (code x place of service): the R terms in the bounds
    count(*) filter (where code_group = 'em_new')  as em_new_rows,
    count(*) filter (where code_group = 'em_est')  as em_est_rows,
    count(*) filter (where code_group = 'eye_new') as eye_new_rows,
    count(*) filter (where code_group = 'eye_est') as eye_est_rows,

    -- places of service with visible activity: P in Scenario A
    count(distinct place_of_service)
        filter (where code_group in ('em_new', 'em_est'))                         as em_places_of_service,
    count(distinct place_of_service)
        filter (where code_group in ('em_new', 'em_est', 'eye_new', 'eye_est'))   as em_eye_places_of_service

from coded
group by npi
