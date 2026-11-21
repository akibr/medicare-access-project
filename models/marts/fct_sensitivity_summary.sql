{{ config(materialized='table') }}

-- One row per sensitivity scenario: providers, specialties, overall share and bounds
-- (ratios of sums), and suppression-robust specialty pairs under Scenario D.

with specialty as (

    select * from {{ ref('fct_sensitivity_specialty') }}

),

overall as (

    select
        scenario,
        count(*)                                                    as specialties,
        sum(eligible_providers)                                     as providers,
        sum(sum_n) / sum(sum_d)                                     as observed_share,
        sum(sum_n) / (sum(sum_d) + sum(sum_u_e))                    as lower_d,
        (sum(sum_n) + sum(sum_u_n)) / (sum(sum_d) + sum(sum_u_n))   as upper_d
    from specialty
    group by scenario

),

pairs as (

    select
        a.scenario,
        count(*)                                                    as pairs,
        count(*) filter (where a.lower_d > b.upper_d
                            or b.lower_d > a.upper_d)               as robust_pairs
    from specialty as a
    inner join specialty as b
        on  a.scenario = b.scenario
        and a.provider_type < b.provider_type
    group by a.scenario

)

select o.*, p.pairs, p.robust_pairs
from overall as o
inner join pairs as p
    on o.scenario = p.scenario
