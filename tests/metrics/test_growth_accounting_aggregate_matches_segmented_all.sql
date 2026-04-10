with aggregate_view as (
    select
        period_grain,
        period_start,
        active_users,
        new_users,
        retained_users,
        resurrected_users,
        churned_users
    from {{ ref('fct_growth_accounting') }}
),
all_segment as (
    select
        period_grain,
        period_start,
        active_users,
        new_users,
        retained_users,
        resurrected_users,
        churned_users
    from {{ ref('fct_growth_accounting_detail') }}
    where country = 'all'
      and platform = 'all'
      and utm_source = 'all'
)
select
    coalesce(a.period_grain, s.period_grain) as period_grain,
    coalesce(a.period_start, s.period_start) as period_start,
    a.active_users as aggregate_active_users,
    s.active_users as segmented_active_users,
    a.new_users as aggregate_new_users,
    s.new_users as segmented_new_users
from aggregate_view a
full outer join all_segment s
    on a.period_grain = s.period_grain
   and a.period_start = s.period_start
where
    a.period_grain is null
    or s.period_grain is null
    or a.active_users != s.active_users
    or a.new_users != s.new_users
    or a.retained_users != s.retained_users
    or a.resurrected_users != s.resurrected_users
    or a.churned_users != s.churned_users
