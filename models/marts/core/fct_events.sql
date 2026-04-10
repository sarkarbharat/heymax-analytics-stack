{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='event_id',
        partition_by={"field": "event_date_utc", "data_type": "date"},
        cluster_by=['user_id', 'event_type']
    )
}}

{% set execution_date = var('execution_date', '') %}
{% set late_arrival_lookback_days = var('late_arrival_lookback_days', 1) | int %}

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
where 1 = 1
{% if is_incremental() %}
and e.event_time_utc > (
    select timestamp_sub(
        coalesce(max(event_time_utc), timestamp('1970-01-01')),
        interval {{ late_arrival_lookback_days }} day
    )
    from {{ this }}
)
{% endif %}
{% if execution_date | trim | length > 0 %}
and e.event_time_utc <= timestamp('{{ execution_date }}')
{% endif %}
