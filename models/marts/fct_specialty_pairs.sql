{{ config(materialized='table') }}

-- One row per unordered pair of main-comparison specialties (66 choose 2 = 2,145).
-- A pair is suppression-robust when one specialty's lower bound exceeds the other's upper bound.
-- Eye care is reported separately and is not paired with the main comparison.

with main as (

    select provider_type, observed_share, lower_d, upper_d, lower_a, upper_a
    from {{ ref('fct_specialty_bounds') }}
    where scope_group = 'main'

)

select
    a.provider_type                     as specialty_a,
    b.provider_type                     as specialty_b,
    a.observed_share - b.observed_share as observed_difference,

    -- Scenario D (primary)
    case
        when a.lower_d > b.upper_d then 'a_higher'
        when b.lower_d > a.upper_d then 'b_higher'
        else 'not_robust'
    end                                 as ordering_d,

    -- Scenario A (sensitivity)
    case
        when a.lower_a > b.upper_a then 'a_higher'
        when b.lower_a > a.upper_a then 'b_higher'
        else 'not_robust'
    end                                 as ordering_a

from main as a
inner join main as b
    on a.provider_type < b.provider_type
