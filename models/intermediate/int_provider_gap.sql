{{ config(materialized='table') }}

-- One row per NPI in the by-Provider file.
-- G* (gap_services) = upper limit on services CMS suppressed from the code-level file.
-- Uses the medical (non-drug) subtotal when published, because E/M codes are non-drug
-- and drug services are counted in dosage units.

with visible as (

    select
        npi,
        sum(total_services)                                           as visible_services,
        coalesce(sum(total_services) filter (where is_drug = 'N'), 0) as visible_nondrug_services
    from {{ ref('stg_cms__phys_2024') }}
    group by npi

),

joined as (

    select
        p.npi,
        p.provider_type,
        p.entity_code,
        p.total_services,
        p.medical_services,
        p.medical_suppression_flag,
        v.npi is not null                       as in_code_level_file,
        coalesce(v.visible_services, 0)         as visible_services,
        coalesce(v.visible_nondrug_services, 0) as visible_nondrug_services
    from {{ ref('stg_cms__phys_prov_2024') }} as p
    left join visible as v
        on p.npi = v.npi

)

select
    *,
    case when medical_services is not null then 'medical' else 'total' end as gap_basis,

    -- before clamping; kept so the test can check CMS's totals really cover the visible rows
    case
        when medical_services is not null then medical_services - visible_nondrug_services
        else total_services - visible_services
    end as gap_services_raw,

    -- G*: clamped at 0 to absorb floating-point noise (smallest raw value is about -0.00000000003)
    greatest(
        case
            when medical_services is not null then medical_services - visible_nondrug_services
            else total_services - visible_services
        end,
        0
    ) as gap_services

from joined
