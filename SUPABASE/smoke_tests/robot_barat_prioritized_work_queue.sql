select *
from public.agent_v2_get_prioritized_work_queue(25);

with q as (
  select *
  from public.agent_v2_get_prioritized_work_queue(25)
)
select count(*) as returned_rows
from q;

with q as (
  select *
  from public.agent_v2_get_prioritized_work_queue(25)
)
select count(*) as rows_with_null_priority_rank
from q
where priority_rank is null;

with q as (
  select *
  from public.agent_v2_get_prioritized_work_queue(25)
)
select count(*) as rows_with_null_priority_score
from q
where priority_score is null;

with q as (
  select *
  from public.agent_v2_get_prioritized_work_queue(25)
)
select count(*) as rows_with_null_item_title
from q
where item_title is null;

with q as (
  select *
  from public.agent_v2_get_prioritized_work_queue(25)
)
select count(*) as rows_with_invalid_priority_bucket
from q
where priority_bucket not in ('Azonnali', 'Ma intézendő', 'Következő', 'Figyelés');

with q as (
  select *
  from public.agent_v2_get_prioritized_work_queue(25)
)
select priority_rank, count(*) as duplicate_count
from q
group by priority_rank
having count(*) > 1;
