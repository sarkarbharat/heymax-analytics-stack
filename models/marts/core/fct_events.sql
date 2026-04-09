select
    e.event_id,
    u.user_sk,
    e.user_id,
    e.event_time_utc,
    e.event_date_utc,
    e.event_week_utc,
    e.event_month_utc,
    e.event_type,
    e.transaction_category,
    e.miles_amount,
    e.gender,
    e.platform,
    e.utm_source,
    e.country,
    e.loaded_at
from {{ ref('stg_events') }} e
left join {{ ref('dim_users') }} u
    on e.user_id = u.user_id
