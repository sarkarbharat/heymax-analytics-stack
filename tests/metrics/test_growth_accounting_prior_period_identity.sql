with current_periods as (
    select
        period_grain,
        period_start,
        retained_users,
        churned_users
    from {{ ref('fct_growth_accounting') }}
    where country = 'all'
      and platform = 'all'
      and utm_source = 'all'
),
prior_periods as (
    select
        period_grain,
        period_start,
        active_users as prior_active_users
    from {{ ref('fct_growth_accounting') }}
    where country = 'all'
      and platform = 'all'
      and utm_source = 'all'
),
joined as (
    select
        c.period_grain,
        c.period_start,
        p.prior_active_users,
        c.retained_users,
        c.churned_users
    from current_periods c
    left join prior_periods p
        on p.period_grain = c.period_grain
       and p.period_start = case
            when c.period_grain = 'daily' then date_sub(c.period_start, interval 1 day)
            when c.period_grain = 'weekly' then date_sub(c.period_start, interval 1 week)
            when c.period_grain = 'monthly' then date_sub(c.period_start, interval 1 month)
        end
)
select
    period_grain,
    period_start,
    prior_active_users,
    retained_users,
    churned_users
from joined
where prior_active_users is not null
  and prior_active_users != (retained_users + churned_users)
