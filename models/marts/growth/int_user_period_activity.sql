with user_periods as (
    select
        'daily' as period_grain,
        event_date_utc as period_start,
        user_id
    from {{ ref('fct_events') }}
    group by 1, 2, 3

    union all

    select
        'weekly' as period_grain,
        date_trunc(event_date_utc, week(monday)) as period_start,
        user_id
    from {{ ref('fct_events') }}
    group by 1, 2, 3

    union all

    select
        'monthly' as period_grain,
        date_trunc(event_date_utc, month) as period_start,
        user_id
    from {{ ref('fct_events') }}
    group by 1, 2, 3
),
first_active as (
    select
        period_grain,
        user_id,
        min(period_start) as first_active_period
    from user_periods
    group by 1, 2
),
period_enriched as (
    select
        up.period_grain,
        up.period_start,
        up.user_id,
        fa.first_active_period,
        case
            when up.period_grain = 'daily' then date_sub(up.period_start, interval 1 day)
            when up.period_grain = 'weekly' then date_sub(up.period_start, interval 1 week)
            when up.period_grain = 'monthly' then date_sub(up.period_start, interval 1 month)
        end as prior_period_start
    from user_periods up
    inner join first_active fa
        on up.period_grain = fa.period_grain
       and up.user_id = fa.user_id
),
final as (
    select
        pe.period_grain,
        pe.period_start,
        pe.user_id,
        pe.first_active_period,
        pe.prior_period_start,
        pe.period_start = pe.first_active_period as is_new,
        exists (
            select 1
            from user_periods p
            where p.period_grain = pe.period_grain
              and p.user_id = pe.user_id
              and p.period_start = pe.prior_period_start
        ) as was_active_prior_period,
        exists (
            select 1
            from user_periods h
            where h.period_grain = pe.period_grain
              and h.user_id = pe.user_id
              and h.period_start < pe.prior_period_start
        ) as was_seen_before_prior_period
    from period_enriched pe
)
select
    period_grain,
    period_start,
    user_id,
    first_active_period,
    prior_period_start,
    is_new,
    was_active_prior_period,
    was_seen_before_prior_period,
    (not is_new and not was_active_prior_period and was_seen_before_prior_period) as is_resurrected,
    (not is_new and was_active_prior_period) as is_retained
from final
