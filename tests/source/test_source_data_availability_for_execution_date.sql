with params as (
    select '{{ var("execution_date", "") }}' as execution_date
)
select
    execution_date,
    'No source rows found for execution_date' as error_message
from params
where execution_date != ''
  and (
      select count(*)
      from {{ source('raw', 'events') }}
      where date(cast(event_time as timestamp)) = date(cast(execution_date as timestamp))
  ) = 0
