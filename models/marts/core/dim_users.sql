{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='user_id',
        cluster_by=['user_id']
    )
}}

{% set late_arrival_lookback_days = var('late_arrival_lookback_days', 1) | int %}
{% set execution_date = var('execution_date', '') %}

with input_events as (
    select
        user_id,
        event_time_utc,
        gender,
        platform,
        country,
        utm_source
    from {{ ref('stg_events') }}
    where 1 = 1
    {% if is_incremental() %}
    and event_time_utc > (
        select timestamp_sub(
            coalesce(max(latest_event_time_utc), timestamp('1970-01-01')),
            interval {{ late_arrival_lookback_days }} day
        )
        from {{ this }}
    )
    {% endif %}
    {% if execution_date | trim | length > 0 %}
    and event_time_utc <= timestamp('{{ execution_date }}')
    {% endif %}
),
incoming_base as (
    select
        user_id,
        min(event_time_utc) as incoming_first_event_time_utc,
        max(event_time_utc) as incoming_latest_event_time_utc
    from input_events
    group by 1
),
incoming_latest_attrs as (
    select
        user_id,
        array_agg(gender ignore nulls order by event_time_utc desc limit 1)[safe_offset(0)] as incoming_latest_gender,
        array_agg(platform ignore nulls order by event_time_utc desc limit 1)[safe_offset(0)] as incoming_latest_platform,
        array_agg(country ignore nulls order by event_time_utc desc limit 1)[safe_offset(0)] as incoming_latest_country,
        array_agg(utm_source ignore nulls order by event_time_utc desc limit 1)[safe_offset(0)] as incoming_latest_utm_source
    from input_events
    group by 1
)
{% if is_incremental() %}
, merged_updates as (
    select
        coalesce(d.user_id, b.user_id) as user_id,
        least(
            coalesce(d.first_event_time_utc, timestamp('9999-12-31')),
            coalesce(b.incoming_first_event_time_utc, timestamp('9999-12-31'))
        ) as first_event_time_utc,
        greatest(
            coalesce(d.latest_event_time_utc, timestamp('1970-01-01')),
            coalesce(b.incoming_latest_event_time_utc, timestamp('1970-01-01'))
        ) as latest_event_time_utc,
        coalesce(a.incoming_latest_gender, d.latest_gender) as latest_gender,
        coalesce(a.incoming_latest_platform, d.latest_platform) as latest_platform,
        coalesce(a.incoming_latest_country, d.latest_country) as latest_country,
        coalesce(a.incoming_latest_utm_source, d.latest_utm_source) as latest_utm_source
    from incoming_base b
    left join incoming_latest_attrs a
        on b.user_id = a.user_id
    left join {{ this }} d
        on b.user_id = d.user_id
)
select
    {{ generate_surrogate_key(['user_id']) }} as user_sk,
    user_id,
    first_event_time_utc,
    date(first_event_time_utc) as first_event_date_utc,
    latest_event_time_utc,
    date(latest_event_time_utc) as latest_event_date_utc,
    latest_gender,
    latest_platform,
    latest_country,
    latest_utm_source
from merged_updates
{% else %}
select
    {{ generate_surrogate_key(['b.user_id']) }} as user_sk,
    b.user_id,
    b.incoming_first_event_time_utc as first_event_time_utc,
    date(b.incoming_first_event_time_utc) as first_event_date_utc,
    b.incoming_latest_event_time_utc as latest_event_time_utc,
    date(b.incoming_latest_event_time_utc) as latest_event_date_utc,
    a.incoming_latest_gender as latest_gender,
    a.incoming_latest_platform as latest_platform,
    a.incoming_latest_country as latest_country,
    a.incoming_latest_utm_source as latest_utm_source
from incoming_base b
left join incoming_latest_attrs a
    on b.user_id = a.user_id
{% endif %}
