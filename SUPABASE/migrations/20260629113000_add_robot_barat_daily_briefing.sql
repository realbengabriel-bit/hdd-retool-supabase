-- HDD / UAHUN Robot Barat daily briefing backend foundation

create extension if not exists pgcrypto;

create table if not exists public.agent_daily_briefings (
  id uuid primary key default gen_random_uuid(),
  briefing_date date not null default current_date,
  briefing_key text not null,
  status text not null default 'draft',
  title text not null,
  summary_text text not null,
  urgent_count integer not null default 0,
  blocker_count integer not null default 0,
  open_count integer not null default 0,
  action_required_count integer not null default 0,
  payload jsonb not null default '{}'::jsonb,
  generated_by text,
  generated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.agent_daily_briefings add column if not exists id uuid default gen_random_uuid();
alter table public.agent_daily_briefings add column if not exists briefing_date date not null default current_date;
alter table public.agent_daily_briefings add column if not exists briefing_key text;
alter table public.agent_daily_briefings add column if not exists status text not null default 'draft';
alter table public.agent_daily_briefings add column if not exists title text;
alter table public.agent_daily_briefings add column if not exists summary_text text;
alter table public.agent_daily_briefings add column if not exists urgent_count integer not null default 0;
alter table public.agent_daily_briefings add column if not exists blocker_count integer not null default 0;
alter table public.agent_daily_briefings add column if not exists open_count integer not null default 0;
alter table public.agent_daily_briefings add column if not exists action_required_count integer not null default 0;
alter table public.agent_daily_briefings add column if not exists payload jsonb not null default '{}'::jsonb;
alter table public.agent_daily_briefings add column if not exists generated_by text;
alter table public.agent_daily_briefings add column if not exists generated_at timestamptz not null default now();
alter table public.agent_daily_briefings add column if not exists created_at timestamptz not null default now();
alter table public.agent_daily_briefings add column if not exists updated_at timestamptz not null default now();

alter table public.agent_daily_briefings alter column id set default gen_random_uuid();
alter table public.agent_daily_briefings alter column briefing_date set default current_date;
alter table public.agent_daily_briefings alter column status set default 'draft';
alter table public.agent_daily_briefings alter column urgent_count set default 0;
alter table public.agent_daily_briefings alter column blocker_count set default 0;
alter table public.agent_daily_briefings alter column open_count set default 0;
alter table public.agent_daily_briefings alter column action_required_count set default 0;
alter table public.agent_daily_briefings alter column payload set default '{}'::jsonb;
alter table public.agent_daily_briefings alter column generated_at set default now();
alter table public.agent_daily_briefings alter column created_at set default now();
alter table public.agent_daily_briefings alter column updated_at set default now();

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.agent_daily_briefings'::regclass
      and conname = 'agent_daily_briefings_status_check'
  ) then
    alter table public.agent_daily_briefings
      add constraint agent_daily_briefings_status_check
      check (status in ('draft', 'ready', 'sent', 'archived', 'failed')) not valid;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.agent_daily_briefings'::regclass
      and conname = 'agent_daily_briefings_briefing_key_key'
  ) then
    alter table public.agent_daily_briefings
      add constraint agent_daily_briefings_briefing_key_key
      unique (briefing_key);
  end if;
end $$;

create index if not exists agent_daily_briefings_briefing_date_desc_idx
  on public.agent_daily_briefings (briefing_date desc);

create index if not exists agent_daily_briefings_status_idx
  on public.agent_daily_briefings (status);

create index if not exists agent_daily_briefings_generated_at_desc_idx
  on public.agent_daily_briefings (generated_at desc);

create index if not exists agent_daily_briefings_payload_gin_idx
  on public.agent_daily_briefings using gin (payload);

do $$
begin
  if to_regprocedure('public.fn_agent_alerts_set_updated_at()') is null
     and to_regprocedure('public.fn_agent_daily_briefings_set_updated_at()') is null
  then
    execute $sql$
      create function public.fn_agent_daily_briefings_set_updated_at()
      returns trigger
      language plpgsql
      security invoker
      set search_path = public
      as $function$
      begin
        new.updated_at := now();
        return new;
      end;
      $function$
    $sql$;
  end if;

  if not exists (
    select 1
    from pg_trigger
    where tgrelid = 'public.agent_daily_briefings'::regclass
      and tgname = 'trg_agent_daily_briefings_set_updated_at'
  ) then
    if to_regprocedure('public.fn_agent_alerts_set_updated_at()') is not null then
      execute 'create trigger trg_agent_daily_briefings_set_updated_at before update on public.agent_daily_briefings for each row execute function public.fn_agent_alerts_set_updated_at()';
    else
      execute 'create trigger trg_agent_daily_briefings_set_updated_at before update on public.agent_daily_briefings for each row execute function public.fn_agent_daily_briefings_set_updated_at()';
    end if;
  end if;
end $$;

create or replace function public.agent_v2_generate_daily_briefing(
  p_briefing_date date default current_date,
  p_requested_by text default null,
  p_limit integer default 100
)
returns table (
  id uuid,
  briefing_date date,
  briefing_key text,
  status text,
  title text,
  summary_text text,
  urgent_count integer,
  blocker_count integer,
  open_count integer,
  action_required_count integer,
  payload jsonb,
  generated_at timestamptz
)
language plpgsql
security invoker
set search_path = public
as $function$
declare
  v_briefing_date date := coalesce(p_briefing_date, current_date);
  v_requested_by text := nullif(btrim(p_requested_by), '');
  v_limit integer := least(greatest(coalesce(p_limit, 100), 1), 1000);
  v_now timestamptz := now();
  v_briefing_key text;
  v_title text;
  v_summary_text text;
  v_payload jsonb;
  v_urgent_count integer := 0;
  v_blocker_count integer := 0;
  v_open_count integer := 0;
  v_action_required_count integer := 0;
  v_urgent_blocker_lines text;
  v_open_alert_lines text;
  v_action_required_lines text;
  v_suggested_action_lines text;
  v_materialized_count bigint := 0;
begin
  if to_regprocedure('public.agent_v2_materialize_alert_events(integer, text)') is not null then
    execute
      'select count(*) from public.agent_v2_materialize_alert_events($1, $2)'
      into v_materialized_count
      using v_limit, v_requested_by;
  end if;

  v_briefing_key := 'robot_barat_daily_briefing:' || to_char(v_briefing_date, 'YYYY-MM-DD');
  v_title := 'Robot Barát napi briefing - ' || to_char(v_briefing_date, 'YYYY-MM-DD');

  with current_events as (
    select
      e.id,
      e.alert_key,
      e.category,
      e.severity,
      e.entity_type,
      e.entity_id,
      e.title,
      e.message,
      e.status,
      e.first_seen_at,
      e.last_seen_at,
      e.resolved_at,
      e.payload
    from public.agent_alert_events e
    where e.status in ('open', 'active', 'acknowledged', 'suppressed')
  )
  select
    count(*) filter (where ce.status in ('open', 'active'))::integer,
    count(*) filter (where ce.status in ('open', 'active') and ce.severity = 'urgent')::integer,
    count(*) filter (where ce.status in ('open', 'active') and ce.severity = 'blocker')::integer,
    count(*) filter (where ce.category = 'action_request' and ce.status in ('open', 'active', 'acknowledged'))::integer
  into
    v_open_count,
    v_urgent_count,
    v_blocker_count,
    v_action_required_count
  from current_events ce;

  select string_agg(
           '- [' || ranked.severity || '] ' || ranked.title ||
           coalesce(' (' || ranked.entity_type || ': ' || ranked.entity_id || ')', ''),
           E'\n'
           order by ranked.sort_order, ranked.last_seen_at desc nulls last, ranked.id
         )
    into v_urgent_blocker_lines
  from (
    select
      ce.id,
      ce.severity,
      ce.entity_type,
      ce.entity_id,
      ce.title,
      ce.last_seen_at,
      case ce.severity when 'blocker' then 1 when 'urgent' then 2 else 3 end as sort_order
    from public.agent_alert_events ce
    where ce.status in ('open', 'active')
      and ce.severity in ('blocker', 'urgent')
    order by
      case ce.severity when 'blocker' then 1 when 'urgent' then 2 else 3 end,
      ce.last_seen_at desc nulls last,
      ce.id
    limit 10
  ) ranked;

  select string_agg(
           '- [' || ranked.severity || '] ' || ranked.title ||
           coalesce(' (' || ranked.category || ')', ''),
           E'\n'
           order by ranked.sort_order, ranked.last_seen_at desc nulls last, ranked.id
         )
    into v_open_alert_lines
  from (
    select
      ce.id,
      ce.category,
      ce.severity,
      ce.title,
      ce.last_seen_at,
      case ce.severity when 'blocker' then 1 when 'urgent' then 2 when 'warning' then 3 else 4 end as sort_order
    from public.agent_alert_events ce
    where ce.status in ('open', 'active')
    order by
      case ce.severity when 'blocker' then 1 when 'urgent' then 2 when 'warning' then 3 else 4 end,
      ce.last_seen_at desc nulls last,
      ce.id
    limit 15
  ) ranked;

  select string_agg(
           '- ' || ranked.title ||
           coalesce(': ' || nullif(ranked.message, ''), ''),
           E'\n'
           order by ranked.last_seen_at desc nulls last, ranked.id
         )
    into v_action_required_lines
  from (
    select
      ce.id,
      ce.title,
      ce.message,
      ce.last_seen_at
    from public.agent_alert_events ce
    where ce.category = 'action_request'
      and ce.status in ('open', 'active', 'acknowledged')
    order by ce.last_seen_at desc nulls last, ce.id
    limit 10
  ) ranked;

  v_suggested_action_lines := concat_ws(
    E'\n',
    case
      when v_blocker_count > 0 then '- A blokkoló jelzések elsőbbségi áttekintése és felelős kijelölése.'
      else '- Nincs nyitott blokkoló jelzés; tartsd fenn a napi kontrollt.'
    end,
    case
      when v_urgent_count > 0 then '- A sürgős jelzésekhez ma kérj visszajelzést az érintett tulajdonosoktól.'
      else '- Nincs nyitott sürgős jelzés.'
    end,
    case
      when v_action_required_count > 0 then '- Az action request jelzéseknél döntsd el, kell-e emberi jóváhagyás vagy további adat.'
      else '- Nincs figyelmet igénylő action request jelzés.'
    end,
    '- A nap végén futtasd újra a briefinget, ha jelentős státuszváltozás történt.'
  );

  v_summary_text := concat_ws(
    E'\n\n',
    v_title,
    'Összesítés: ' ||
      v_open_count::text || ' nyitott jelzés, ' ||
      v_blocker_count::text || ' blokkoló, ' ||
      v_urgent_count::text || ' sürgős, ' ||
      v_action_required_count::text || ' figyelmet igénylő action request.',
    'Sürgős blokkolók' || E'\n' ||
      coalesce(v_urgent_blocker_lines, '- Nincs nyitott sürgős blokkoló.'),
    'Nyitott jelzések' || E'\n' ||
      coalesce(v_open_alert_lines, '- Nincs nyitott jelzés.'),
    'Figyelmet igénylő action requestek' || E'\n' ||
      coalesce(v_action_required_lines, '- Nincs figyelmet igénylő action request.'),
    'Mai javasolt teendők' || E'\n' ||
      v_suggested_action_lines
  );

  with top_alerts as (
    select jsonb_agg(row_to_json(alert_row)::jsonb order by alert_row.sort_order, alert_row.last_seen_at desc nulls last, alert_row.id) as items
    from (
      select
        e.id,
        e.alert_key,
        e.category,
        e.severity,
        e.entity_type,
        e.entity_id,
        e.title,
        e.message,
        e.status,
        e.first_seen_at,
        e.last_seen_at,
        case e.severity when 'blocker' then 1 when 'urgent' then 2 when 'warning' then 3 else 4 end as sort_order
      from public.agent_alert_events e
      where e.status in ('open', 'active')
      order by
        case e.severity when 'blocker' then 1 when 'urgent' then 2 when 'warning' then 3 else 4 end,
        e.last_seen_at desc nulls last,
        e.id
      limit 20
    ) alert_row
  ),
  urgent_blockers as (
    select jsonb_agg(row_to_json(alert_row)::jsonb order by alert_row.sort_order, alert_row.last_seen_at desc nulls last, alert_row.id) as items
    from (
      select
        e.id,
        e.alert_key,
        e.category,
        e.severity,
        e.entity_type,
        e.entity_id,
        e.title,
        e.message,
        e.status,
        e.first_seen_at,
        e.last_seen_at,
        case e.severity when 'blocker' then 1 when 'urgent' then 2 else 3 end as sort_order
      from public.agent_alert_events e
      where e.status in ('open', 'active')
        and e.severity in ('blocker', 'urgent')
      order by
        case e.severity when 'blocker' then 1 when 'urgent' then 2 else 3 end,
        e.last_seen_at desc nulls last,
        e.id
      limit 20
    ) alert_row
  ),
  action_required as (
    select jsonb_agg(row_to_json(alert_row)::jsonb order by alert_row.last_seen_at desc nulls last, alert_row.id) as items
    from (
      select
        e.id,
        e.alert_key,
        e.category,
        e.severity,
        e.entity_type,
        e.entity_id,
        e.title,
        e.message,
        e.status,
        e.first_seen_at,
        e.last_seen_at
      from public.agent_alert_events e
      where e.category = 'action_request'
        and e.status in ('open', 'active', 'acknowledged')
      order by e.last_seen_at desc nulls last, e.id
      limit 20
    ) alert_row
  )
  select jsonb_build_object(
           'briefing_date', v_briefing_date,
           'counts', jsonb_build_object(
             'urgent', v_urgent_count,
             'blocker', v_blocker_count,
             'open', v_open_count,
             'action_required', v_action_required_count
           ),
           'top_alerts', coalesce(ta.items, '[]'::jsonb),
           'urgent_blockers', coalesce(ub.items, '[]'::jsonb),
           'action_required', coalesce(ar.items, '[]'::jsonb),
           'generated_by', v_requested_by,
           'source', 'agent_alert_events',
           'materialized_count', v_materialized_count,
           'generated_at', v_now
         )
    into v_payload
  from top_alerts ta
  cross join urgent_blockers ub
  cross join action_required ar;

  insert into public.agent_daily_briefings as b (
    briefing_date,
    briefing_key,
    status,
    title,
    summary_text,
    urgent_count,
    blocker_count,
    open_count,
    action_required_count,
    payload,
    generated_by,
    generated_at,
    created_at,
    updated_at
  )
  values (
    v_briefing_date,
    v_briefing_key,
    'ready',
    v_title,
    v_summary_text,
    v_urgent_count,
    v_blocker_count,
    v_open_count,
    v_action_required_count,
    v_payload,
    v_requested_by,
    v_now,
    v_now,
    v_now
  )
  on conflict on constraint agent_daily_briefings_briefing_key_key do update
     set briefing_date = excluded.briefing_date,
         status = 'ready',
         title = excluded.title,
         summary_text = excluded.summary_text,
         urgent_count = excluded.urgent_count,
         blocker_count = excluded.blocker_count,
         open_count = excluded.open_count,
         action_required_count = excluded.action_required_count,
         payload = excluded.payload,
         generated_by = excluded.generated_by,
         generated_at = excluded.generated_at,
         updated_at = excluded.updated_at
  returning b.id,
            b.briefing_date,
            b.briefing_key,
            b.status,
            b.title,
            b.summary_text,
            b.urgent_count,
            b.blocker_count,
            b.open_count,
            b.action_required_count,
            b.payload,
            b.generated_at
  into id,
       briefing_date,
       briefing_key,
       status,
       title,
       summary_text,
       urgent_count,
       blocker_count,
       open_count,
       action_required_count,
       payload,
       generated_at;

  return next;
end;
$function$;

comment on function public.agent_v2_generate_daily_briefing(date, text, integer)
is 'Generates one idempotent Robot Barat daily briefing from current agent alert events.';

create or replace function public.agent_v2_get_latest_daily_briefing()
returns table (
  id uuid,
  briefing_date date,
  briefing_key text,
  status text,
  title text,
  summary_text text,
  urgent_count integer,
  blocker_count integer,
  open_count integer,
  action_required_count integer,
  payload jsonb,
  generated_at timestamptz
)
language sql
security invoker
stable
set search_path = public
as $function$
  select
    b.id,
    b.briefing_date,
    b.briefing_key,
    b.status,
    b.title,
    b.summary_text,
    b.urgent_count,
    b.blocker_count,
    b.open_count,
    b.action_required_count,
    b.payload,
    b.generated_at
  from public.agent_daily_briefings b
  where b.status <> 'archived'
  order by b.generated_at desc nulls last,
           b.created_at desc nulls last,
           b.id
  limit 1;
$function$;

comment on function public.agent_v2_get_latest_daily_briefing()
is 'Returns the latest non-archived Robot Barat daily briefing.';

do $$
declare
  v_role text;
begin
  foreach v_role in array array['authenticated', 'service_role'] loop
    if exists (select 1 from pg_roles where rolname = v_role) then
      execute format('grant select, insert, update on table public.agent_daily_briefings to %I', v_role);
      execute format('grant execute on function public.agent_v2_generate_daily_briefing(date, text, integer) to %I', v_role);
      execute format('grant execute on function public.agent_v2_get_latest_daily_briefing() to %I', v_role);
    end if;
  end loop;
end $$;

-- select * from public.agent_v2_generate_daily_briefing(current_date, 'manual-smoke-test', 100);
-- select * from public.agent_v2_get_latest_daily_briefing();
