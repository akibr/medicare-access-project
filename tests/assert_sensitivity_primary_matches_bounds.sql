-- The primary scenario duplicates the logic of fct_specialty_bounds (main comparison).
-- They must agree for every specialty; any row here means the two copies have drifted.
with s as (

    select * from {{ ref('fct_sensitivity_specialty') }}
    where scenario = 'primary'

),

b as (

    select * from {{ ref('fct_specialty_bounds') }}
    where scope_group = 'main'

)

select
    coalesce(s.provider_type, b.provider_type) as provider_type
from s
full outer join b
    on s.provider_type = b.provider_type
where s.provider_type is null
   or b.provider_type is null
   or s.eligible_providers <> b.eligible_providers
   or abs(s.lower_d - b.lower_d) > 1e-12
   or abs(s.upper_d - b.upper_d) > 1e-12
