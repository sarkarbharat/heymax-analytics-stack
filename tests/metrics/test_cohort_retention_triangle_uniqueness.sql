select
    cohort_grain,
    cohort_start,
    activity_period_start,
    period_index,
    country,
    platform,
    utm_source,
    count(*) as row_count
from {{ ref('fct_cohort_retention_triangle') }}
group by 1, 2, 3, 4, 5, 6, 7
having count(*) > 1
