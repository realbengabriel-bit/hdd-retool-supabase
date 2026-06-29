-- EH Agent Gateway v11 package wrapper smoke test
-- Read-only validation only. Does not call local agent, EnterHungary, or OIF.

select
  'function_exists' as check_name,
  case when exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'get_oif_eh_agent_package_v11'
      and pg_get_function_identity_arguments(p.oid) = 'p_workflow_case_id uuid, p_candidate_id uuid, p_assignment_id uuid, p_rq_code text, p_requested_by text, p_dry_run boolean'
  ) then 'PASS' else 'FAIL' end as result;

with picked as (
  select src.workflow_case_id::uuid as workflow_case_id
  from public.v_oif_eh_agent_package_source as src
  where src.workflow_case_id is not null
  order by src.workflow_case_id::text
  limit 1
), seed as (
  select picked.workflow_case_id
  from (select 1) as one_row
  left join picked on true
), called as (
  select
    seed.workflow_case_id,
    case
      when seed.workflow_case_id is null then null::jsonb
      else public.get_oif_eh_agent_package_v11(
        p_workflow_case_id := seed.workflow_case_id,
        p_requested_by := 'smoke-test',
        p_dry_run := true
      )
    end as payload
  from seed
)
select
  check_name,
  case when passed then 'PASS' else 'FAIL' end as result,
  detail
from called
cross join lateral (
  values
    (
      'source_row_found',
      called.workflow_case_id is not null,
      coalesce(called.workflow_case_id::text, 'No workflow_case_id found in public.v_oif_eh_agent_package_source.')
    ),
    (
      'ok_is_true',
      called.payload ->> 'ok' = 'true',
      coalesce(called.payload ->> 'ok', 'null')
    ),
    (
      'status_is_ready',
      called.payload ->> 'status' = 'ready',
      coalesce(called.payload ->> 'status', 'null')
    ),
    (
      'execution_allowed_now_is_false',
      called.payload ->> 'execution_allowed_now' = 'false',
      coalesce(called.payload ->> 'execution_allowed_now', 'null')
    ),
    (
      'live_fill_allowed_is_false',
      called.payload ->> 'live_fill_allowed' = 'false',
      coalesce(called.payload ->> 'live_fill_allowed', 'null')
    ),
    (
      'submit_allowed_is_false',
      called.payload ->> 'submit_allowed' = 'false',
      coalesce(called.payload ->> 'submit_allowed', 'null')
    ),
    (
      'resolved_workflow_case_id_is_not_null',
      nullif(called.payload ->> 'resolved_workflow_case_id', '') is not null,
      coalesce(called.payload ->> 'resolved_workflow_case_id', 'null')
    )
) as checks(check_name, passed, detail);
