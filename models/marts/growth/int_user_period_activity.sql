{{
    config(
        materialized='incremental',
        incremental_strategy='insert_overwrite',
        partition_by={"field": "period_start", "data_type": "date"},
        cluster_by=['country', 'platform', 'utm_source', 'user_id']
    )
}}

{% set execution_date = var('execution_date', '') %}
{% set period_lookback_days = var('period_lookback_days', 62) | int %}

with period_user_segments_detail as (
    select
        'daily' as period_grain,
        event_date_utc as period_start,
        user_id,
        coalesce(country, 'UNKNOWN') as country,
        coalesce(platform, 'unknown') as platform,
        coalesce(utm_source, 'unknown') as utm_source
    from {{ ref('fct_events') }}
    group by 1, 2, 3, 4, 5, 6

    union all

    select
        'weekly' as period_grain,
        date_trunc(event_date_utc, week(monday)) as period_start,
        user_id,
        coalesce(country, 'UNKNOWN') as country,
        coalesce(platform, 'unknown') as platform,
        coalesce(utm_source, 'unknown') as utm_source
    from {{ ref('fct_events') }}
    group by 1, 2, 3, 4, 5, 6

    union all

    select
        'monthly' as period_grain,
        date_trunc(event_date_utc, month) as period_start,
        user_id,
        coalesce(country, 'UNKNOWN') as country,
        coalesce(platform, 'unknown') as platform,
        coalesce(utm_source, 'unknown') as utm_source
    from {{ ref('fct_events') }}
    group by 1, 2, 3, 4, 5, 6
),
period_user_segments as (
    select
        period_grain,
        period_start,
        user_id,
        country,
        platform,
        utm_source
    from period_user_segments_detail

    union all

    select
        period_grain,
        period_start,
        user_id,
        'all' as country,
        'all' as platform,
        'all' as utm_source
    from (
        select distinct
            period_grain,
            period_start,
            user_id
        from period_user_segments_detail
    )
),
first_active as (
    select
        period_grain,
        country,
        platform,
        utm_source,
        user_id,
        min(period_start) as first_active_period
    from period_user_segments
    group by 1, 2, 3, 4, 5
),
period_enriched as (
    select
        ps.period_grain,
        ps.period_start,
        ps.country,
        ps.platform,
        ps.utm_source,
        ps.user_id,
        fa.first_active_period,
        case
            when ps.period_grain = 'daily' then date_sub(ps.period_start, interval 1 day)
            when ps.period_grain = 'weekly' then date_sub(ps.period_start, interval 1 week)
            when ps.period_grain = 'monthly' then date_sub(ps.period_start, interval 1 month)
        end as prior_period_start
    from period_user_segments ps
    inner join first_active fa
        on ps.period_grain = fa.period_grain
       and ps.country = fa.country
       and ps.platform = fa.platform
       and ps.utm_source = fa.utm_source
       and ps.user_id = fa.user_id
),
final as (
    select
        pe.period_grain,
        pe.period_start,
        pe.country,
        pe.platform,
        pe.utm_source,
        pe.user_id,
        pe.first_active_period,
        pe.prior_period_start,
        pe.period_start = pe.first_active_period as is_new,
        max(case when p.period_start = pe.prior_period_start then 1 else 0 end) = 1 as was_active_prior_period,
        max(case when p.period_start < pe.prior_period_start then 1 else 0 end) = 1 as was_seen_before_prior_period
    from period_enriched pe
    left join period_user_segments p
        on pe.period_grain = p.period_grain
       and pe.country = p.country
       and pe.platform = p.platform
       and pe.utm_source = p.utm_source
       and pe.user_id = p.user_id
    group by 1, 2, 3, 4, 5, 6, 7, 8, 9
)
select
    period_grain,
    period_start,
    country,
    platform,
    utm_source,
    user_id,
    first_active_period,
    prior_period_start,
    is_new,
    (not is_new and not was_active_prior_period and was_seen_before_prior_period) as is_resurrected,
    (not is_new and was_active_prior_period) as is_retained
from final
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
