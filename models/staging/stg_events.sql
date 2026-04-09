with src as (
    select
        event_time,
        user_id,
        gender,
        event_type,
        transaction_category,
        miles_amount,
        platform,
        utm_source,
        country,
        loaded_at
    from {{ source('raw', 'events') }}
),
typed as (
    select
        cast(event_time as timestamp) as event_time_utc,
        cast(user_id as string) as user_id,
        nullif(trim(cast(gender as string)), '') as gender,
        lower(nullif(trim(cast(event_type as string)), '')) as event_type,
        lower(nullif(trim(cast(transaction_category as string)), '')) as transaction_category,
        cast(miles_amount as numeric) as miles_amount,
        lower(nullif(trim(cast(platform as string)), '')) as platform,
        lower(nullif(trim(cast(utm_source as string)), '')) as utm_source,
        upper(nullif(trim(cast(country as string)), '')) as country,
        cast(loaded_at as timestamp) as loaded_at
    from src
),
final as (
    select
        to_hex(md5(concat(
            coalesce(cast(event_time_utc as string), ''),
            '|',
            coalesce(user_id, ''),
            '|',
            coalesce(event_type, ''),
            '|',
            coalesce(cast(miles_amount as string), ''),
            '|',
            coalesce(platform, '')
        ))) as event_id,
        event_time_utc,
        user_id,
        gender,
        event_type,
        transaction_category,
        miles_amount,
        platform,
        utm_source,
        country,
        date(event_time_utc) as event_date_utc,
        timestamp_trunc(event_time_utc, week(monday)) as event_week_utc,
        timestamp_trunc(event_time_utc, month) as event_month_utc,
        loaded_at
    from typed
    where user_id is not null
      and event_time_utc is not null
)
select * from final
