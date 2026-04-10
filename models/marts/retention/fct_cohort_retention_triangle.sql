{{
    config(
        materialized='incremental',
        incremental_strategy='insert_overwrite',
        partition_by={"field": "cohort_start", "data_type": "date"},
        cluster_by=['country', 'platform', 'utm_source', 'cohort_grain']
    )
}}

{% set execution_date = var('execution_date', '') %}
{% set period_lookback_days = var('period_lookback_days', 62) | int %}

with activity as (
    select
        period_grain as cohort_grain,
        period_start as activity_period_start,
        country,
        platform,
        utm_source,
        user_id
    from {{ ref('int_user_period_activity') }}
    where 1 = 1
    {% if is_incremental() %}
    and period_start > (
        select date_sub(
            coalesce(max(cohort_start), date('1970-01-01')),
            interval {{ period_lookback_days }} day
        )
        from {{ this }}
    )
    {% endif %}
    {% if execution_date | trim | length > 0 %}
    and period_start <= date('{{ execution_date }}')
    {% endif %}
),
first_segment_activity as (
    select
        cohort_grain,
        country,
        platform,
        utm_source,
        user_id,
        min(activity_period_start) as cohort_start
    from activity
    group by 1, 2, 3, 4, 5
),
retention as (
    select
        a.cohort_grain,
        f.cohort_start,
        a.activity_period_start,
        a.country,
        a.platform,
        a.utm_source,
        case
            when a.cohort_grain = 'daily' then date_diff(a.activity_period_start, f.cohort_start, day)
            when a.cohort_grain = 'weekly' then date_diff(a.activity_period_start, f.cohort_start, week)
            when a.cohort_grain = 'monthly' then date_diff(a.activity_period_start, f.cohort_start, month)
        end as period_index,
        count(distinct a.user_id) as retained_users
    from activity a
    inner join first_segment_activity f
        on a.cohort_grain = f.cohort_grain
       and a.country = f.country
       and a.platform = f.platform
       and a.utm_source = f.utm_source
       and a.user_id = f.user_id
    group by 1, 2, 3, 4, 5, 6, 7
),
cohort_sizes as (
    select
        cohort_grain,
        cohort_start,
        country,
        platform,
        utm_source,
        count(distinct user_id) as cohort_users
    from first_segment_activity
    group by 1, 2, 3, 4, 5
)
select
    r.cohort_grain,
    r.cohort_start,
    r.activity_period_start,
    r.period_index,
    r.country,
    r.platform,
    r.utm_source,
    c.cohort_users,
    r.retained_users,
    safe_divide(r.retained_users, c.cohort_users) as retention_rate
from retention r
inner join cohort_sizes c
    on r.cohort_grain = c.cohort_grain
   and r.cohort_start = c.cohort_start
   and r.country = c.country
   and r.platform = c.platform
   and r.utm_source = c.utm_source
where r.period_index >= 0
