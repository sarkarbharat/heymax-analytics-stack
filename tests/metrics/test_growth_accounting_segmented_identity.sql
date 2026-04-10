select
    period_grain,
    period_start,
    country,
    platform,
    utm_source,
    active_users,
    new_users,
    retained_users,
    resurrected_users
from {{ ref('fct_growth_accounting_detail') }}
where active_users != (new_users + retained_users + resurrected_users)
