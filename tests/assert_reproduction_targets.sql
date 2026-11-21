-- README reproduction targets (primary analysis). Each row returned is a target that no longer reproduces.
-- Shares are compared in percent, rounded to 2 decimals, as published in the README.

with providers as (

    select * from {{ ref('int_provider_eligible') }}

),

bounds as (

    select * from {{ ref('fct_specialty_bounds') }}

),

pairs as (

    select * from {{ ref('fct_specialty_pairs') }}

),

-- population reconciliation: E/M-only volume rule, before scope exclusions
em_only as (

    select scope_group
    from providers
    where entity_code = 'I'
      and em_new_services + em_est_services >= 100

),

main_overall as (

    select
        count(*)                                                                  as specialties,
        sum(eligible_providers)                                                   as providers,
        round(100 * sum(sum_n) / sum(sum_d), 2)                                   as observed,
        round(100 * sum(sum_n) / (sum(sum_d) + sum(sum_u_e_d)), 2)                as lower_d,
        round(100 * (sum(sum_n) + sum(sum_u_n_d)) / (sum(sum_d) + sum(sum_u_n_d)), 2) as upper_d
    from bounds
    where scope_group = 'main'

),

checks as (

    select 'NPIs in by-Provider file'    as check_name, 1296739 as expected, (select count(*) from providers) as actual
    union all
    select 'individuals',                  1235757, (select count(*) from providers where entity_code = 'I')
    union all
    select 'eligible, all specialties',    430118,  (select count(*) from em_only)
    union all
    select 'eye care, E/M codes only',     21967,   (select count(*) from em_only where scope_group = 'eye_care')
    union all
    select 'behavioral health',            7536,    (select count(*) from em_only where scope_group = 'excluded_behavioral_health')
    union all
    select 'undefined physician type',     90,      (select count(*) from em_only where scope_group = 'excluded_undefined')
    union all
    select 'main scope, eligible',         400525,  (select count(*) from providers where is_eligible and scope_group = 'main')
    union all
    select 'main comparison providers',    400495,  (select providers from main_overall)
    union all
    select 'main comparison specialties',  66,      (select specialties from main_overall)
    union all
    select 'eye care providers',           35378,   (select sum(eligible_providers) from bounds where scope_group = 'eye_care')
    union all
    select 'eye care specialties',         2,       (select count(*) from bounds where scope_group = 'eye_care')
    union all
    select 'scenario D observed %',        10.38,   (select observed from main_overall)
    union all
    select 'scenario D lower %',           7.74,    (select lower_d from main_overall)
    union all
    select 'scenario D upper %',           22.50,   (select upper_d from main_overall)
    union all
    select 'scenario D robust pairs',      259,     (select count(*) from pairs where ordering_d <> 'not_robust')
    union all
    select 'specialty pairs',              2145,    (select count(*) from pairs)

)

select *
from checks
where actual is distinct from expected
