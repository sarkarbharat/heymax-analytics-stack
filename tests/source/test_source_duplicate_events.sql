with normalized as (
    select
        cast(event_time as timestamp) as event_time_utc,
        cast(user_id as string) as user_id,
        lower(nullif(trim(cast(event_type as string)), '')) as event_type,
        cast(miles_amount as numeric) as miles_amount,
        lower(nullif(trim(cast(platform as string)), '')) as platform
    from {{ source('raw', 'events') }}
),
event_signatures as (
    select
        {{ generate_surrogate_key([
            'event_time_utc',
            'user_id',
            'event_type',
            'miles_amount',
            'platform'
        ]) }} as event_signature,
        count(*) as duplicate_count
    from normalized
    group by 1
)
select *
from event_signatures
where duplicate_count > 1
