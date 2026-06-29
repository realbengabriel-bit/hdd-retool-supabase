-- EH Agent Gateway v11 P02-first package wrapper
-- Safety: package-preview/read-only wrapper only. No EnterHungary/OIF submit,
-- no local agent execution, no notifications, and no business-data mutation.

-- Drop only the accidental six-argument overload created during manual testing.
-- Do not drop or replace the original one-argument package function.
drop function if exists public.get_oif_eh_agent_package(uuid, uuid, uuid, text, text, boolean);

create or replace function public.get_oif_eh_agent_package_v11(
  p_workflow_case_id uuid default null,
  p_candidate_id uuid default null,
  p_assignment_id uuid default null,
  p_rq_code text default null,
  p_requested_by text default null,
  p_dry_run boolean default true
)
returns jsonb
language plpgsql
security invoker
as $$
declare
  v_workflow_case_id uuid;
  v_rq_code text := nullif(btrim(p_rq_code), '');
  v_requested_by text := coalesce(nullif(btrim(p_requested_by), ''), 'eh-agent-gateway-v11');
  v_package jsonb;
begin
  v_workflow_case_id := p_workflow_case_id;

  if v_workflow_case_id is null and p_assignment_id is not null then
    select src.workflow_case_id::uuid
      into v_workflow_case_id
    from public.v_oif_eh_agent_package_source as src
    where src.workflow_case_id is not null
      and src.assignment_id::text = p_assignment_id::text
    order by src.workflow_case_id::text
    limit 1;
  end if;

  if v_workflow_case_id is null and p_candidate_id is not null then
    select src.workflow_case_id::uuid
      into v_workflow_case_id
    from public.v_oif_eh_agent_package_source as src
    where src.workflow_case_id is not null
      and src.candidate_id::text = p_candidate_id::text
    order by src.workflow_case_id::text
    limit 1;
  end if;

  if v_workflow_case_id is null and v_rq_code is not null then
    select src.workflow_case_id::uuid
      into v_workflow_case_id
    from public.v_oif_eh_agent_package_source as src
    where src.workflow_case_id is not null
      and (
        lower(src.request_code::text) = lower(v_rq_code)
        or lower(src.workflow_code::text) = lower(v_rq_code)
      )
    order by src.workflow_case_id::text
    limit 1;
  end if;

  if v_workflow_case_id is null then
    return jsonb_build_object(
      'ok', false,
      'status', 'not_found',
      'source_mode', 'v11_compat_wrapper',
      'resolved_workflow_case_id', null,
      'requested_by', v_requested_by,
      'dry_run', true,
      'package', null,
      'execution_allowed_now', false,
      'live_fill_allowed', false,
      'submit_allowed', false
    );
  end if;

  begin
    select to_jsonb(public.get_oif_eh_agent_package(v_workflow_case_id::uuid))
      into v_package;
  exception
    when others then
      return jsonb_build_object(
        'ok', false,
        'status', 'source_error',
        'source_mode', 'v11_compat_wrapper',
        'resolved_workflow_case_id', v_workflow_case_id,
        'requested_by', v_requested_by,
        'dry_run', true,
        'package', null,
        'error', sqlerrm,
        'execution_allowed_now', false,
        'live_fill_allowed', false,
        'submit_allowed', false
      );
  end;

  return jsonb_build_object(
    'ok', v_package is not null,
    'status', case when v_package is null then 'empty' else 'ready' end,
    'source_mode', 'v11_compat_wrapper',
    'resolved_workflow_case_id', v_workflow_case_id,
    'requested_by', v_requested_by,
    'dry_run', true,
    'package', v_package,
    'execution_allowed_now', false,
    'live_fill_allowed', false,
    'submit_allowed', false
  );
end;
$$;

comment on function public.get_oif_eh_agent_package_v11(uuid, uuid, uuid, text, text, boolean)
is 'EH Agent Gateway v11 P02-first compatibility wrapper. Resolves workflow_case_id and delegates to public.get_oif_eh_agent_package(uuid). Preview/dry-run only; execution_allowed_now is always false.';
