{{ config(materialized='table') }}

-- One row per sensitivity scenario x reported specialty, main comparison only, Scenario D bounds.
-- Scenarios:
--   primary                 the primary analysis (must equal fct_specialty_bounds; see tests)
--   incl_99211              99211 counted in eligibility and in the denominator
--   cap_11_7                11.7 services per suppressed new-patient slot instead of 16
--   potential_eligibility   eligibility on visible E/M + G* >= 100

with providers as (

    select *
    from {{ ref('int_provider_eligible') }}
    where scope_group = 'main'

),

provider_scenarios as (

    select 'primary' as scenario, provider_type,
        analysis_new_services                         as n,
        analysis_new_services + analysis_est_services as d,
        least(16 * (2 * codes_per_family - analysis_new_rows), gap_services) as u_n,
        gap_services                                  as u_e
    from providers
    where is_eligible

    union all

    select 'incl_99211', provider_type,
        analysis_new_services,
        analysis_new_services + analysis_est_services + em_99211_services,
        least(16 * (2 * codes_per_family - analysis_new_rows), gap_services),
        gap_services
    from providers
    where is_eligible_incl_99211

    union all

    select 'cap_11_7', provider_type,
        analysis_new_services,
        analysis_new_services + analysis_est_services,
        least(11.7 * (2 * codes_per_family - analysis_new_rows), gap_services),
        gap_services
    from providers
    where is_eligible

    union all

    select 'potential_eligibility', provider_type,
        analysis_new_services,
        analysis_new_services + analysis_est_services,
        least(16 * (2 * codes_per_family - analysis_new_rows), gap_services),
        gap_services
    from providers
    where is_eligible_potential

),

specialty as (

    select
        scenario,
        provider_type,
        count(*)  as eligible_providers,
        sum(n)    as sum_n,
        sum(d)    as sum_d,
        sum(u_n)  as sum_u_n,
        sum(u_e)  as sum_u_e
    from provider_scenarios
    group by scenario, provider_type
    having count(*) >= 30

)

select
    *,
    sum_n / sum_d                         as observed_share,
    sum_n / (sum_d + sum_u_e)             as lower_d,
    (sum_n + sum_u_n) / (sum_d + sum_u_n) as upper_d
from specialty
