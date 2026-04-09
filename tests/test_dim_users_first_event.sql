with expected as (
    select
        user_id,
        min(event_time_utc) as min_event_time_utc
    from {{ ref('fct_events') }}
    group by 1
)
select
    d.user_id,
    d.first_event_time_utc,
    e.min_event_time_utc
from {{ ref('dim_users') }} d
inner join expected e
    on d.user_id = e.user_id
where d.first_event_time_utc != e.min_event_time_utc
