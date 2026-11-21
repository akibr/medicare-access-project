-- Bounds must bracket the observed share, and Scenario A must sit inside Scenario D.
-- A holds by construction (A's caps are never larger than D's), so any row here is a bug.
select *
from {{ ref('fct_specialty_bounds') }}
where lower_d > observed_share
   or upper_d < observed_share
   or lower_a > observed_share
   or upper_a < observed_share
   or lower_d > lower_a
   or upper_a > upper_d
