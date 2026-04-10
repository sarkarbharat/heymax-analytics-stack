select
    period_grain,
    period_start,
    user_id,
    is_new,
    is_retained,
    is_resurrected
from {{ ref('int_user_period_activity') }}
where (
    cast(is_new as int64)
    + cast(is_retained as int64)
    + cast(is_resurrected as int64)
) > 1
