select
    period_grain,
    period_start,
    country,
    platform,
    utm_source,
    active_users,
    new_users,
    retained_users,
    resurrected_users,
    churned_users
from {{ ref('fct_growth_accounting') }}
where
    active_users < 0
    or new_users < 0
    or retained_users < 0
    or resurrected_users < 0
    or churned_users < 0
    or active_users != cast(active_users as int64)
    or new_users != cast(new_users as int64)
    or retained_users != cast(retained_users as int64)
    or resurrected_users != cast(resurrected_users as int64)
    or churned_users != cast(churned_users as int64)
