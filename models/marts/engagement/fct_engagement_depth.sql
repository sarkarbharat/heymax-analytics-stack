{{
    config(
        materialized='incremental',
        incremental_strategy='insert_overwrite',
        partition_by={"field": "period_start", "data_type": "date"},
        cluster_by=['country', 'platform', 'utm_source', 'period_grain']
    )
}}

{% set execution_date = var('execution_date', '') %}
{% set period_lookback_days = var('period_lookback_days', 62) | int %}

with period_user_events_detail as (
    select
        'daily' as period_grain,
        event_date_utc as period_start,
        user_id,
        coalesce(country, 'UNKNOWN') as country,
        coalesce(platform, 'unknown') as platform,
        coalesce(utm_source, 'unknown') as utm_source,
        count(*) as event_count,
        coalesce(sum(miles_amount), 0) as miles_sum
    from {{ ref('fct_events') }}
    group by 1, 2, 3, 4, 5, 6

    union all

    select
        'weekly' as period_grain,
        date_trunc(event_date_utc, week(monday)) as period_start,
        user_id,
        coalesce(country, 'UNKNOWN') as country,
        coalesce(platform, 'unknown') as platform,
        coalesce(utm_source, 'unknown') as utm_source,
        count(*) as event_count,
        coalesce(sum(miles_amount), 0) as miles_sum
    from {{ ref('fct_events') }}
    group by 1, 2, 3, 4, 5, 6

    union all

    select
        'monthly' as period_grain,
        date_trunc(event_date_utc, month) as period_start,
        user_id,
        coalesce(country, 'UNKNOWN') as country,
        coalesce(platform, 'unknown') as platform,
        coalesce(utm_source, 'unknown') as utm_source,
        count(*) as event_count,
        coalesce(sum(miles_amount), 0) as miles_sum
    from {{ ref('fct_events') }}
    group by 1, 2, 3, 4, 5, 6
),
period_user_events as (
    select
        period_grain,
        period_start,
        user_id,
        country,
        platform,
        utm_source,
        event_count,
        miles_sum
    from period_user_events_detail

    union all

    select
        period_grain,
        period_start,
        user_id,
        'all' as country,
        'all' as platform,
        'all' as utm_source,
        sum(event_count) as event_count,
        sum(miles_sum) as miles_sum
    from period_user_events_detail
    group by 1, 2, 3, 4, 5, 6
),
aggregated as (
    select
        period_grain,
        period_start,
        country,
        platform,
        utm_source,
        sum(event_count) as total_events,
        count(distinct user_id) as active_users,
        sum(miles_sum) as total_miles,
        count(distinct case when event_count >= 3 then user_id end) as power_users
    from period_user_events
    group by 1, 2, 3, 4, 5
)
select
    period_grain,
    period_start,
    country,
    platform,
    utm_source,
    total_events,
    active_users,
    safe_divide(total_events, active_users) as events_per_active_user,
    safe_divide(total_miles, active_users) as avg_miles_per_active_user,
    power_users,
    safe_divide(power_users, active_users) as power_user_share
from aggregated
where 1 = 1
{% if is_incremental() %}
and period_start > (
    select date_sub(
        coalesce(max(period_start), date('1970-01-01')),
        interval {{ period_lookback_days }} day
    )
    from {{ this }}
)
{% endif %}
{% if execution_date | trim | length > 0 %}
and period_start <= date('{{ execution_date }}')
{% endif %}
