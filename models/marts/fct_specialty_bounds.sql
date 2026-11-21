{{ config(materialized='table') }}

-- One row per reported specialty (main comparison and eye care).
-- Observed share and suppression bounds under Scenario D (primary) and Scenario A (sensitivity).
-- Bounds are ratios of sums over the specialty's eligible providers, never averages of rates.
-- The component sums are kept so an overall share can be computed the same way.

with eligible as (

    select *
    from {{ ref('int_provider_eligible') }}
    where is_eligible

),

provider_caps as (

    select
        npi,
        provider_type,
        scope_group,
        analysis_new_services                           as n,
        analysis_new_services + analysis_est_services   as d,

        -- Scenario D: every new-patient slot (codes x 2 places) can be hidden, 16 services each
        least(16 * (2 * codes_per_family - analysis_new_rows), gap_services)  as u_n_d,
        gap_services                                                          as u_e_d,

        -- Scenario A: only places in use, 10 per new slot, 100 per established slot
        least(10  * (codes_per_family * analysis_places_of_service - analysis_new_rows), gap_services) as u_n_a,
        least(100 * (codes_per_family * analysis_places_of_service - analysis_est_rows), gap_services) as u_e_a

    from eligible

),

hospital as (

    -- initial hospital (99221-99223) and initial nursing facility (99304-99306) services,
    -- both places of service, for eligible providers: the hospital-predominant flag
    select
        s.npi,
        sum(s.total_services) as initial_facility_services
    from {{ ref('stg_cms__phys_2024') }} as s
    inner join eligible as e
        on s.npi = e.npi
    where s.hcpcs_code in ('99221', '99222', '99223', '99304', '99305', '99306')
    group by s.npi

),

specialty as (

    select
        c.provider_type,
        c.scope_group,
        count(*)                as eligible_providers,
        sum(c.n)                as sum_n,
        sum(c.d)                as sum_d,
        sum(c.u_n_d)            as sum_u_n_d,
        sum(c.u_e_d)            as sum_u_e_d,
        sum(c.u_n_a)            as sum_u_n_a,
        sum(c.u_e_a)            as sum_u_e_a,
        coalesce(sum(h.initial_facility_services), 0)  as sum_initial_facility,
        sum(e.em_new_services)  as sum_em_new
    from provider_caps as c
    inner join eligible as e
        on c.npi = e.npi
    left join hospital as h
        on c.npi = h.npi
    group by c.provider_type, c.scope_group

),

individuals as (

    -- denominator of the eligible-share flag: all individual NPIs with the specialty
    select
        provider_type,
        count(*) as individual_providers
    from {{ ref('int_provider_eligible') }}
    where entity_code = 'I'
    group by provider_type

)

select
    s.provider_type,
    s.scope_group,
    s.eligible_providers,
    i.individual_providers,
    s.eligible_providers / i.individual_providers                  as eligible_share,
    s.sum_initial_facility > s.sum_em_new                           as is_hospital_predominant,

    s.sum_n / s.sum_d                                               as observed_share,
    s.sum_n / (s.sum_d + s.sum_u_e_d)                               as lower_d,
    (s.sum_n + s.sum_u_n_d) / (s.sum_d + s.sum_u_n_d)               as upper_d,
    s.sum_n / (s.sum_d + s.sum_u_e_a)                               as lower_a,
    (s.sum_n + s.sum_u_n_a) / (s.sum_d + s.sum_u_n_a)               as upper_a,

    s.sum_n, s.sum_d,
    s.sum_u_n_d, s.sum_u_e_d,
    s.sum_u_n_a, s.sum_u_e_a,
    s.sum_initial_facility, s.sum_em_new

from specialty as s
inner join individuals as i
    on s.provider_type = i.provider_type
where s.eligible_providers >= 30
