select *
from {{ ref('fct_growth_accounting') }}
where active_users < 0
   or new_users < 0
   or retained_users < 0
   or resurrected_users < 0
   or churned_users < 0
