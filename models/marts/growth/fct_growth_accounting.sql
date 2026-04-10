{{
    config(
        materialized='incremental',
        incremental_strategy='insert_overwrite',
        partition_by={"field": "period_start", "data_type": "date"},
        cluster_by=['period_grain']
    )
}}

{% set execution_date = var('execution_date', '') %}
{% set period_lookback_days = var('period_lookback_days', 62) | int %}

with period_activity as (
    select * from {{ ref('int_user_period_activity') }}
),
periods as (
    select distinct
        period_grain,
        period_start,
        case
            when period_grain = 'daily' then date_sub(period_start, interval 1 day)
            when period_grain = 'weekly' then date_sub(period_start, interval 1 week)
            when period_grain = 'monthly' then date_sub(period_start, interval 1 month)
        end as prior_period_start
    from period_activity
),
active_counts as (
    select
        period_grain,
        period_start,
        count(distinct user_id) as active_users,
        count(distinct case when is_new then user_id end) as new_users,
        count(distinct case when is_retained then user_id end) as retained_users,
        count(distinct case when is_resurrected then user_id end) as resurrected_users
    from period_activity
    group by 1, 2
),
churn_counts as (
    select
        p.period_grain,
        p.period_start,
        count(distinct prev.user_id) as churned_users
    from periods p
    left join period_activity prev
        on prev.period_grain = p.period_grain
       and prev.period_start = p.prior_period_start
    left join period_activity curr
        on curr.period_grain = p.period_grain
       and curr.period_start = p.period_start
       and curr.user_id = prev.user_id
    where curr.user_id is null
    group by 1, 2
)
select
    a.period_grain,
    a.period_start,
    a.active_users,
    a.new_users,
    a.retained_users,
    a.resurrected_users,
    coalesce(c.churned_users, 0) as churned_users
from active_counts a
left join churn_counts c
    on a.period_grain = c.period_grain
   and a.period_start = c.period_start
where 1 = 1
{% if is_incremental() %}
and a.period_start > (
    select date_sub(
        coalesce(max(period_start), date('1970-01-01')),
        interval {{ period_lookback_days }} day
    )
    from {{ this }}
)
{% endif %}
{% if execution_date | trim | length > 0 %}
and a.period_start <= date('{{ execution_date }}')
{% endif %}
