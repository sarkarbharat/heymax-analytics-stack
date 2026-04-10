select
    period_grain,
    period_start,
    country,
    platform,
    utm_source,
    total_events,
    active_users,
    events_per_active_user,
    avg_miles_per_active_user,
    power_users,
    power_user_share
from {{ ref('fct_engagement_depth') }}
where
    total_events < 0
    or active_users < 0
    or power_users < 0
    or power_users > active_users
    or events_per_active_user < 0
    or avg_miles_per_active_user < 0
    or power_user_share < 0
    or power_user_share > 1
