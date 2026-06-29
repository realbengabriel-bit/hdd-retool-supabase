-- HDD / UAHUN Robot Barat alert event handling RPCs
-- Controlled write functions for alert event lifecycle handling only.

create or replace function public.agent_v2_acknowledge_alert_event(
  p_alert_event_id uuid,
  p_actor text default null,
  p_note text default null
)
returns table (
  id uuid,
  alert_key text,
  category text,
  severity text,
  entity_type text,
  entity_id text,
  title text,
  status text,
  first_seen_at timestamptz,
  last_seen_at timestamptz,
  resolved_at timestamptz,
  suppress_until timestamptz,
  action text
)
language plpgsql
security invoker
set search_path = public
as $function$
declare
  v_event public.agent_alert_events%rowtype;
  v_now timestamptz := now();
  v_actor text := nullif(btrim(p_actor), '');
  v_note text := nullif(btrim(p_note), '');
begin
  if p_alert_event_id is null then
    raise exception 'Robot Barat alert event id is required.'
      using errcode = '22023';
  end if;

  select e.*
    into v_event
  from public.agent_alert_events e
  where e.id = p_alert_event_id
  for update;

  if not found then
    raise exception 'Robot Barat alert event % was not found.', p_alert_event_id
      using errcode = 'P0002';
  end if;

  if coalesce(v_event.status, '') not in ('open', 'active') then
    raise exception 'Cannot acknowledge Robot Barat alert event % from status %. Allowed statuses: open, active.',
      p_alert_event_id,
      coalesce(v_event.status, '<null>')
      using errcode = '22023';
  end if;

  update public.agent_alert_events e
     set status = 'acknowledged',
         payload = (
           case
             when jsonb_typeof(coalesce(e.payload, '{}'::jsonb)) = 'object'
             then coalesce(e.payload, '{}'::jsonb)
             else jsonb_build_object('previous_payload', e.payload)
           end
         ) || jsonb_build_object(
           'acknowledged_by', v_actor,
           'acknowledged_at', v_now,
           'acknowledge_note', v_note
         )
   where e.id = p_alert_event_id;

  return query
  select
    e.id,
    e.alert_key,
    e.category,
    e.severity,
    e.entity_type,
    e.entity_id,
    e.title,
    e.status,
    e.first_seen_at,
    e.last_seen_at,
    e.resolved_at,
    st.suppress_until,
    'acknowledged'::text as action
  from public.agent_alert_events e
  left join public.agent_alert_state st
    on st.alert_key = e.alert_key
  where e.id = p_alert_event_id;
end;
$function$;

comment on function public.agent_v2_acknowledge_alert_event(uuid, text, text)
is 'Acknowledges one Robot Barat alert event when its current status is open or active.';

create or replace function public.agent_v2_resolve_alert_event(
  p_alert_event_id uuid,
  p_actor text default null,
  p_note text default null
)
returns table (
  id uuid,
  alert_key text,
  category text,
  severity text,
  entity_type text,
  entity_id text,
  title text,
  status text,
  first_seen_at timestamptz,
  last_seen_at timestamptz,
  resolved_at timestamptz,
  suppress_until timestamptz,
  action text
)
language plpgsql
security invoker
set search_path = public
as $function$
declare
  v_event public.agent_alert_events%rowtype;
  v_now timestamptz := now();
  v_actor text := nullif(btrim(p_actor), '');
  v_note text := nullif(btrim(p_note), '');
begin
  if p_alert_event_id is null then
    raise exception 'Robot Barat alert event id is required.'
      using errcode = '22023';
  end if;

  select e.*
    into v_event
  from public.agent_alert_events e
  where e.id = p_alert_event_id
  for update;

  if not found then
    raise exception 'Robot Barat alert event % was not found.', p_alert_event_id
      using errcode = 'P0002';
  end if;

  if coalesce(v_event.status, '') not in ('open', 'active', 'acknowledged', 'suppressed') then
    raise exception 'Cannot resolve Robot Barat alert event % from status %. Allowed statuses: open, active, acknowledged, suppressed.',
      p_alert_event_id,
      coalesce(v_event.status, '<null>')
      using errcode = '22023';
  end if;

  update public.agent_alert_events e
     set status = 'resolved',
         resolved_at = v_now,
         payload = (
           case
             when jsonb_typeof(coalesce(e.payload, '{}'::jsonb)) = 'object'
             then coalesce(e.payload, '{}'::jsonb)
             else jsonb_build_object('previous_payload', e.payload)
           end
         ) || jsonb_build_object(
           'resolved_by', v_actor,
           'resolved_at', v_now,
           'resolve_note', v_note
         )
   where e.id = p_alert_event_id;

  return query
  select
    e.id,
    e.alert_key,
    e.category,
    e.severity,
    e.entity_type,
    e.entity_id,
    e.title,
    e.status,
    e.first_seen_at,
    e.last_seen_at,
    e.resolved_at,
    st.suppress_until,
    'resolved'::text as action
  from public.agent_alert_events e
  left join public.agent_alert_state st
    on st.alert_key = e.alert_key
  where e.id = p_alert_event_id;
end;
$function$;

comment on function public.agent_v2_resolve_alert_event(uuid, text, text)
is 'Resolves one Robot Barat alert event when its current status allows resolution.';

create or replace function public.agent_v2_suppress_alert_event(
  p_alert_event_id uuid,
  p_suppress_until timestamptz,
  p_actor text default null,
  p_note text default null
)
returns table (
  id uuid,
  alert_key text,
  category text,
  severity text,
  entity_type text,
  entity_id text,
  title text,
  status text,
  first_seen_at timestamptz,
  last_seen_at timestamptz,
  resolved_at timestamptz,
  suppress_until timestamptz,
  action text
)
language plpgsql
security invoker
set search_path = public
as $function$
declare
  v_event public.agent_alert_events%rowtype;
  v_now timestamptz := now();
  v_actor text := nullif(btrim(p_actor), '');
  v_note text := nullif(btrim(p_note), '');
begin
  if p_alert_event_id is null then
    raise exception 'Robot Barat alert event id is required.'
      using errcode = '22023';
  end if;

  if p_suppress_until is null then
    raise exception 'Robot Barat alert suppress_until is required.'
      using errcode = '22023';
  end if;

  if p_suppress_until <= v_now then
    raise exception 'Robot Barat alert suppress_until must be later than now.'
      using errcode = '22023';
  end if;

  select e.*
    into v_event
  from public.agent_alert_events e
  where e.id = p_alert_event_id
  for update;

  if not found then
    raise exception 'Robot Barat alert event % was not found.', p_alert_event_id
      using errcode = 'P0002';
  end if;

  if nullif(btrim(v_event.alert_key), '') is null then
    raise exception 'Robot Barat alert event % has no alert_key, so it cannot be suppressed.', p_alert_event_id
      using errcode = '22023';
  end if;

  if coalesce(v_event.status, '') not in ('open', 'active', 'acknowledged') then
    raise exception 'Cannot suppress Robot Barat alert event % from status %. Allowed statuses: open, active, acknowledged.',
      p_alert_event_id,
      coalesce(v_event.status, '<null>')
      using errcode = '22023';
  end if;

  update public.agent_alert_events e
     set status = 'suppressed',
         payload = (
           case
             when jsonb_typeof(coalesce(e.payload, '{}'::jsonb)) = 'object'
             then coalesce(e.payload, '{}'::jsonb)
             else jsonb_build_object('previous_payload', e.payload)
           end
         ) || jsonb_build_object(
           'suppressed_by', v_actor,
           'suppressed_at', v_now,
           'suppress_until', p_suppress_until,
           'suppress_note', v_note
         )
   where e.id = p_alert_event_id;

  insert into public.agent_alert_state as st (
    alert_key,
    suppress_until,
    state_json,
    updated_at
  )
  values (
    v_event.alert_key,
    p_suppress_until,
    jsonb_build_object(
      'suppressed_by', v_actor,
      'suppressed_at', v_now,
      'suppress_until', p_suppress_until,
      'suppress_note', v_note
    ),
    v_now
  )
  on conflict on constraint agent_alert_state_alert_key_key do update
     set suppress_until = excluded.suppress_until,
         state_json = (
           case
             when jsonb_typeof(coalesce(st.state_json, '{}'::jsonb)) = 'object'
             then coalesce(st.state_json, '{}'::jsonb)
             else jsonb_build_object('previous_state_json', st.state_json)
           end
         ) || jsonb_build_object(
           'suppressed_by', v_actor,
           'suppressed_at', v_now,
           'suppress_until', p_suppress_until,
           'suppress_note', v_note
         ),
         updated_at = v_now;

  return query
  select
    e.id,
    e.alert_key,
    e.category,
    e.severity,
    e.entity_type,
    e.entity_id,
    e.title,
    e.status,
    e.first_seen_at,
    e.last_seen_at,
    e.resolved_at,
    st.suppress_until,
    'suppressed'::text as action
  from public.agent_alert_events e
  left join public.agent_alert_state st
    on st.alert_key = e.alert_key
  where e.id = p_alert_event_id;
end;
$function$;

comment on function public.agent_v2_suppress_alert_event(uuid, timestamptz, text, text)
is 'Suppresses one Robot Barat alert event and records its suppress_until state.';

do $$
declare
  v_role text;
begin
  foreach v_role in array array['authenticated', 'service_role'] loop
    if exists (select 1 from pg_roles where rolname = v_role) then
      execute format('grant execute on function public.agent_v2_acknowledge_alert_event(uuid, text, text) to %I', v_role);
      execute format('grant execute on function public.agent_v2_resolve_alert_event(uuid, text, text) to %I', v_role);
      execute format('grant execute on function public.agent_v2_suppress_alert_event(uuid, timestamptz, text, text) to %I', v_role);
    end if;
  end loop;
end $$;
