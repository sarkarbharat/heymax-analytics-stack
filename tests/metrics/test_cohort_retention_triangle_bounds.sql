select
    cohort_grain,
    cohort_start,
    activity_period_start,
    period_index,
    country,
    platform,
    utm_source,
    cohort_users,
    retained_users,
    retention_rate
from {{ ref('fct_cohort_retention_triangle') }}
where
    period_index < 0
    or cohort_users <= 0
    or retained_users < 0
    or retained_users > cohort_users
    or retention_rate < 0
    or retention_rate > 1
