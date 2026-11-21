{{ config(materialized='table') }}

-- One row per NPI in the by-Provider file.
-- Assigns the specialty scope group and the eligibility flags from the README spec.
-- The analysis_* columns hold whichever code family applies to the provider's scope
-- group, so downstream models use one formula for main and eye care.
-- The 30-providers-per-specialty rule is a specialty-level rule and lives in the fct models.

with joined as (

    select
        g.npi,
        g.provider_type,
        g.entity_code,
        g.in_code_level_file,
        g.gap_services,
        g.gap_basis,

        case
            when g.provider_type in ('Ophthalmology', 'Optometry') then 'eye_care'
            when g.provider_type in (
                'Psychiatry', 'Geriatric Psychiatry', 'Neuropsychiatry',
                'Psychologist, Clinical', 'Licensed Clinical Social Worker',
                'Licensed Professional Counselor'
            )                                                       then 'excluded_behavioral_health'
            when g.provider_type = 'Undefined Physician type'       then 'excluded_undefined'
            else 'main'
        end as scope_group,

        coalesce(e.em_new_services, 0)          as em_new_services,
        coalesce(e.em_est_services, 0)          as em_est_services,
        coalesce(e.em_99211_services, 0)        as em_99211_services,
        coalesce(e.eye_new_services, 0)         as eye_new_services,
        coalesce(e.eye_est_services, 0)         as eye_est_services,
        coalesce(e.em_new_rows, 0)              as em_new_rows,
        coalesce(e.em_est_rows, 0)              as em_est_rows,
        coalesce(e.eye_new_rows, 0)             as eye_new_rows,
        coalesce(e.eye_est_rows, 0)             as eye_est_rows,
        coalesce(e.em_places_of_service, 0)     as em_places_of_service,
        coalesce(e.em_eye_places_of_service, 0) as em_eye_places_of_service

    from {{ ref('int_provider_gap') }} as g
    left join {{ ref('int_provider_em') }} as e
        on g.npi = e.npi

),

analysis as (

    select
        *,
        -- N, D inputs: eye care adds the eye exam code family
        case when scope_group = 'eye_care' then em_new_services + eye_new_services
             else em_new_services end                                    as analysis_new_services,
        case when scope_group = 'eye_care' then em_est_services + eye_est_services
             else em_est_services end                                    as analysis_est_services,

        -- R terms: visible rows (code x place of service)
        case when scope_group = 'eye_care' then em_new_rows + eye_new_rows
             else em_new_rows end                                        as analysis_new_rows,
        case when scope_group = 'eye_care' then em_est_rows + eye_est_rows
             else em_est_rows end                                        as analysis_est_rows,

        -- codes per family: 4 E/M codes, plus 2 eye codes for eye care
        case when scope_group = 'eye_care' then 6 else 4 end             as codes_per_family,

        -- P for Scenario A
        case when scope_group = 'eye_care' then em_eye_places_of_service
             else em_places_of_service end                               as analysis_places_of_service

    from joined

)

select
    *,
    entity_code = 'I'
        and scope_group in ('main', 'eye_care')
        and analysis_new_services + analysis_est_services >= 100                    as is_eligible,

    -- sensitivity: eligibility on potential volume (visible + G*)
    entity_code = 'I'
        and scope_group in ('main', 'eye_care')
        and analysis_new_services + analysis_est_services + gap_services >= 100     as is_eligible_potential,

    -- sensitivity: 99211 counted toward the threshold
    entity_code = 'I'
        and scope_group in ('main', 'eye_care')
        and analysis_new_services + analysis_est_services + em_99211_services >= 100 as is_eligible_incl_99211

from analysis
