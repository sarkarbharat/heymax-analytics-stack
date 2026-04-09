with base as (
    select
        user_id,
        min(event_time_utc) as first_event_time_utc,
        max(event_time_utc) as latest_event_time_utc
    from {{ ref('stg_events') }}
    group by 1
),
latest_attrs as (
    select
        user_id,
        array_agg(gender ignore nulls order by event_time_utc desc limit 1)[safe_offset(0)] as latest_gender,
        array_agg(platform ignore nulls order by event_time_utc desc limit 1)[safe_offset(0)] as latest_platform,
        array_agg(country ignore nulls order by event_time_utc desc limit 1)[safe_offset(0)] as latest_country,
        array_agg(utm_source ignore nulls order by event_time_utc desc limit 1)[safe_offset(0)] as latest_utm_source
    from {{ ref('stg_events') }}
    group by 1
)
select
    to_hex(md5(user_id)) as user_sk,
    b.user_id,
    b.first_event_time_utc,
    date(b.first_event_time_utc) as first_event_date_utc,
    b.latest_event_time_utc,
    date(b.latest_event_time_utc) as latest_event_date_utc,
    l.latest_gender,
    l.latest_platform,
    l.latest_country,
    l.latest_utm_source
from base b
left join latest_attrs l
    on b.user_id = l.user_id
