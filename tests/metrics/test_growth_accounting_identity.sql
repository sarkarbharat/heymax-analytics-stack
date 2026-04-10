select
    period_grain,
    period_start,
    active_users,
    new_users,
    retained_users,
    resurrected_users
from {{ ref('fct_growth_accounting') }}
where country = 'all'
  and platform = 'all'
  and utm_source = 'all'
  and active_users != (new_users + retained_users + resurrected_users)
