-- Two guarantees that follow from the math, so any row here is a bug:
-- 1. A robust ordering agrees with the observed difference (observed shares sit inside the bounds).
-- 2. A pair robust under Scenario D is robust under A in the same direction (A sits inside D).
select *
from {{ ref('fct_specialty_pairs') }}
where (ordering_d = 'a_higher' and observed_difference <= 0)
   or (ordering_d = 'b_higher' and observed_difference >= 0)
   or (ordering_d <> 'not_robust' and ordering_a <> ordering_d)
