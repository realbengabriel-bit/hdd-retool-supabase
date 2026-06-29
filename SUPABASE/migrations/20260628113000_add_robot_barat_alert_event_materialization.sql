-- HDD / UAHUN Robot Barat alert event materialization
-- Safe write RPCs for alert center only.
-- No cron, no external notification sending, no workflow/document/business table writes.

create extension if not exists pgcrypto;

create or replace function public.agent_v2_materialize_alert_events(
  p_limit int default 100,
  p_requested_by text default null
)
returns table (
  alert_key text,
  category text,
  severity text,
  entity_type text,
  entity_id text,
  title text,
  status text,
  action text,
  first_seen_at timestamptz,
  last_seen_at timestamptz,
  dedupe_hash text
)
language plpgsql
security invoker
set search_path = public
as $function$
declare
  v_limit int := least(greatest(coalesce(p_limit, 100), 1), 1000);
  v_now timestamptz;
  v_preview record;
  v_alert_key text;
  v_category text;
  v_severity text;
  v_entity_type text;
  v_entity_id text;
  v_title text;
  v_message text;
  v_payload jsonb;
  v_event_payload jsonb;
  v_dedupe_hash text;
  v_requested_by text := nullif(btrim(p_requested_by), '');
  v_rule_id uuid;
  v_previous_hash text;
  v_suppress_until timestamptz;
  v_open_event_id uuid;
  v_closed_event_id uuid;
  v_return_status text;
  v_return_action text;
  v_return_first_seen_at timestamptz;
  v_return_last_seen_at timestamptz;
begin
  for v_preview in
    select *
    from public.agent_v2_alerts_preview(v_limit)
  loop
    v_now := now();

    v_alert_key := nullif(btrim(v_preview.alert_key), '');
    if v_alert_key is null then
      continue;
    end if;

    v_rule_id := null;
    v_previous_hash := null;
    v_suppress_until := null;
    v_open_event_id := null;
    v_closed_event_id := null;
    v_return_status := null;
    v_return_action := null;
    v_return_first_seen_at := null;
    v_return_last_seen_at := null;

    v_category := coalesce(nullif(btrim(v_preview.category), ''), 'system');
    v_severity := coalesce(nullif(btrim(v_preview.severity), ''), 'info');
    v_entity_type := nullif(btrim(v_preview.entity_type), '');
    v_entity_id := nullif(btrim(v_preview.entity_id), '');
    v_title := coalesce(nullif(btrim(v_preview.title), ''), 'Robot Barat alert');
    v_message := nullif(btrim(v_preview.message), '');
    v_payload := coalesce(v_preview.payload, '{}'::jsonb);
    v_dedupe_hash := coalesce(
      nullif(btrim(v_preview.dedupe_hash), ''),
      md5(
        coalesce(v_alert_key, '') || '|' ||
        coalesce(v_category, '') || '|' ||
        coalesce(v_severity, '') || '|' ||
        coalesce(v_entity_type, '') || '|' ||
        coalesce(v_entity_id, '') || '|' ||
        coalesce(v_title, '') || '|' ||
        coalesce(v_message, '') || '|' ||
        coalesce(v_payload::text, '')
      )
    );

    if v_category not in (
      'workflow_blocker',
      'missing_document',
      'oif_readiness',
      'action_request',
      'napi_drive',
      'expiry',
      'stage_aging',
      'daily_briefing',
      'system'
    ) then
      v_category := 'system';
    end if;

    if v_severity not in ('info', 'warning', 'urgent', 'blocker') then
      v_severity := 'info';
    end if;

    select s.last_seen_hash,
           s.suppress_until
      into v_previous_hash,
           v_suppress_until
    from public.agent_alert_state s
    where s.alert_key = v_alert_key
    for update;

    update public.agent_alert_state st
       set last_seen_hash = v_dedupe_hash,
           last_seen_at = v_now,
           state_json = coalesce(st.state_json, '{}'::jsonb) || jsonb_build_object(
             'latest_preview_payload', v_payload,
             'latest_preview_row', jsonb_build_object(
               'alert_key', v_alert_key,
               'category', v_category,
               'severity', v_severity,
               'entity_type', v_entity_type,
               'entity_id', v_entity_id,
               'title', v_title,
               'message', v_message,
               'dedupe_hash', v_dedupe_hash
             ),
             'requested_by', v_requested_by,
             'materialized_at', v_now
           ),
           updated_at = v_now
     where st.alert_key = v_alert_key;

    if not found then
      begin
        insert into public.agent_alert_state (
          alert_key,
          last_seen_hash,
          last_seen_at,
          state_json,
          updated_at
        )
        values (
          v_alert_key,
          v_dedupe_hash,
          v_now,
          jsonb_build_object(
            'latest_preview_payload', v_payload,
            'latest_preview_row', jsonb_build_object(
              'alert_key', v_alert_key,
              'category', v_category,
              'severity', v_severity,
              'entity_type', v_entity_type,
              'entity_id', v_entity_id,
              'title', v_title,
              'message', v_message,
              'dedupe_hash', v_dedupe_hash
            ),
            'requested_by', v_requested_by,
            'materialized_at', v_now
          ),
          v_now
        );
      exception
        when unique_violation then
          update public.agent_alert_state st
             set last_seen_hash = v_dedupe_hash,
                 last_seen_at = v_now,
                 state_json = coalesce(st.state_json, '{}'::jsonb) || jsonb_build_object(
                   'latest_preview_payload', v_payload,
                   'latest_preview_row', jsonb_build_object(
                     'alert_key', v_alert_key,
                     'category', v_category,
                     'severity', v_severity,
                     'entity_type', v_entity_type,
                     'entity_id', v_entity_id,
                     'title', v_title,
                     'message', v_message,
                     'dedupe_hash', v_dedupe_hash
                   ),
                   'requested_by', v_requested_by,
                   'materialized_at', v_now
                 ),
                 updated_at = v_now
           where st.alert_key = v_alert_key;
      end;
    end if;

    v_event_payload := (
      case
        when jsonb_typeof(v_payload) = 'object' then v_payload
        else jsonb_build_object('preview_payload', v_payload)
      end
    ) || jsonb_build_object(
      '_materialization', jsonb_build_object(
        'dedupe_hash', v_dedupe_hash,
        'requested_by', v_requested_by,
        'materialized_at', v_now,
        'source_function', 'public.agent_v2_materialize_alert_events'
      )
    );

    select r.id
      into v_rule_id
    from public.agent_alert_rules r
    where r.category = v_category
      and r.is_enabled is true
    order by
      case r.rule_key
        when 'workflow_blockers_daily' then 1
        when 'missing_documents_daily' then 2
        when 'oif_readiness_changes' then 3
        when 'action_requests_waiting' then 4
        when 'failed_action_requests' then 5
        when 'napi_drive_incomplete_daily' then 6
        when 'document_expiry_30d' then 7
        when 'bmh_nav_oep_stage_aging' then 8
        else 100
      end,
      r.rule_key
    limit 1;

    select e.id
      into v_open_event_id
    from public.agent_alert_events e
    where e.alert_key = v_alert_key
      and e.status in ('open', 'active')
    order by e.first_seen_at asc nulls last,
             e.created_at asc nulls last,
             e.id
    limit 1
    for update;

    if v_suppress_until is not null and v_suppress_until > v_now then
      if v_open_event_id is not null then
        select e.status,
               e.first_seen_at,
               e.last_seen_at
          into v_return_status,
               v_return_first_seen_at,
               v_return_last_seen_at
        from public.agent_alert_events e
        where e.id = v_open_event_id;
      else
        v_return_status := 'suppressed';
        v_return_first_seen_at := null;
        v_return_last_seen_at := null;
      end if;

      v_return_action := 'suppressed_until';

      return query
      select
        v_alert_key::text,
        v_category::text,
        v_severity::text,
        v_entity_type::text,
        v_entity_id::text,
        v_title::text,
        v_return_status::text,
        v_return_action::text,
        v_return_first_seen_at::timestamptz,
        v_return_last_seen_at::timestamptz,
        v_dedupe_hash::text;
      continue;
    end if;

    if v_open_event_id is not null then
      update public.agent_alert_events e
         set rule_id = coalesce(v_rule_id, e.rule_id),
             category = v_category,
             severity = v_severity,
             entity_type = v_entity_type,
             entity_id = v_entity_id,
             title = v_title,
             message = v_message,
             payload = v_event_payload,
             last_seen_at = v_now
       where e.id = v_open_event_id
       returning e.status,
                 e.first_seen_at,
                 e.last_seen_at
          into v_return_status,
               v_return_first_seen_at,
               v_return_last_seen_at;

      v_return_action := 'updated';
    else
      select e.id
        into v_closed_event_id
      from public.agent_alert_events e
      where e.alert_key = v_alert_key
        and e.status in ('resolved', 'acknowledged', 'suppressed')
      order by coalesce(e.resolved_at, e.last_seen_at, e.created_at) desc nulls last,
               e.created_at desc nulls last,
               e.id
      limit 1;

      if v_closed_event_id is not null
         and v_previous_hash is not distinct from v_dedupe_hash
      then
        select e.status,
               e.first_seen_at,
               e.last_seen_at
          into v_return_status,
               v_return_first_seen_at,
               v_return_last_seen_at
        from public.agent_alert_events e
        where e.id = v_closed_event_id;

        v_return_action := 'suppressed_existing_state';
      else
        begin
          insert into public.agent_alert_events (
            rule_id,
            alert_key,
            category,
            severity,
            entity_type,
            entity_id,
            title,
            message,
            payload,
            status,
            first_seen_at,
            last_seen_at,
            created_at
          )
          values (
            v_rule_id,
            v_alert_key,
            v_category,
            v_severity,
            v_entity_type,
            v_entity_id,
            v_title,
            v_message,
            v_event_payload,
            'open',
            v_now,
            v_now,
            v_now
          )
          returning public.agent_alert_events.status,
                    public.agent_alert_events.first_seen_at,
                    public.agent_alert_events.last_seen_at
             into v_return_status,
                  v_return_first_seen_at,
                  v_return_last_seen_at;

          v_return_action := 'inserted';
        exception
          when unique_violation then
            select e.id
              into v_open_event_id
            from public.agent_alert_events e
            where e.alert_key = v_alert_key
              and e.status in ('open', 'active')
            order by e.first_seen_at asc nulls last,
                     e.created_at asc nulls last,
                     e.id
            limit 1
            for update;

            if v_open_event_id is null then
              raise;
            end if;

            update public.agent_alert_events e
               set rule_id = coalesce(v_rule_id, e.rule_id),
                   category = v_category,
                   severity = v_severity,
                   entity_type = v_entity_type,
                   entity_id = v_entity_id,
                   title = v_title,
                   message = v_message,
                   payload = v_event_payload,
                   last_seen_at = v_now
             where e.id = v_open_event_id
             returning e.status,
                       e.first_seen_at,
                       e.last_seen_at
                into v_return_status,
                     v_return_first_seen_at,
                     v_return_last_seen_at;

            v_return_action := 'updated';
        end;
      end if;
    end if;

    return query
    select
      v_alert_key::text,
      v_category::text,
      v_severity::text,
      v_entity_type::text,
      v_entity_id::text,
      v_title::text,
      v_return_status::text,
      v_return_action::text,
      v_return_first_seen_at::timestamptz,
      v_return_last_seen_at::timestamptz,
      v_dedupe_hash::text;
  end loop;
end;
$function$;

comment on function public.agent_v2_materialize_alert_events(int, text)
is 'Materializes current Robot Barat alert preview rows into agent_alert_events and agent_alert_state only. No cron and no external notifications.';

create or replace function public.agent_v2_get_alert_center_summary()
returns table (
  open_total bigint,
  blocker_total bigint,
  urgent_total bigint,
  warning_total bigint,
  active_rules_total bigint,
  suppressed_total bigint,
  resolved_24h_total bigint,
  last_event_seen_at timestamptz
)
language sql
security invoker
stable
set search_path = public
as $function$
  with event_summary as (
    select
      count(*) filter (where e.status in ('open', 'active')) as open_total,
      count(*) filter (where e.status in ('open', 'active') and e.severity = 'blocker') as blocker_total,
      count(*) filter (where e.status in ('open', 'active') and e.severity = 'urgent') as urgent_total,
      count(*) filter (where e.status in ('open', 'active') and e.severity = 'warning') as warning_total,
      count(*) filter (where e.status = 'resolved' and e.resolved_at >= now() - interval '24 hours') as resolved_24h_total,
      max(e.last_seen_at) as last_event_seen_at
    from public.agent_alert_events e
  ),
  active_rules as (
    select count(*) as active_rules_total
    from public.agent_alert_rules r
    where r.is_enabled is true
  ),
  suppressed_alerts as (
    select count(distinct s.alert_key) as suppressed_total
    from (
      select e.alert_key
      from public.agent_alert_events e
      where e.status = 'suppressed'

      union

      select st.alert_key
      from public.agent_alert_state st
      where st.suppress_until is not null
        and st.suppress_until > now()
    ) s
  )
  select
    coalesce(es.open_total, 0)::bigint as open_total,
    coalesce(es.blocker_total, 0)::bigint as blocker_total,
    coalesce(es.urgent_total, 0)::bigint as urgent_total,
    coalesce(es.warning_total, 0)::bigint as warning_total,
    coalesce(ar.active_rules_total, 0)::bigint as active_rules_total,
    coalesce(sa.suppressed_total, 0)::bigint as suppressed_total,
    coalesce(es.resolved_24h_total, 0)::bigint as resolved_24h_total,
    es.last_event_seen_at
  from event_summary es
  cross join active_rules ar
  cross join suppressed_alerts sa;
$function$;

comment on function public.agent_v2_get_alert_center_summary()
is 'Read-only Robot Barat alert center summary for current alert event/rule/state tables.';

do $$
declare
  v_role text;
begin
  foreach v_role in array array['authenticated', 'service_role'] loop
    if exists (select 1 from pg_roles where rolname = v_role) then
      execute format('grant execute on function public.agent_v2_materialize_alert_events(integer, text) to %I', v_role);
      execute format('grant execute on function public.agent_v2_get_alert_center_summary() to %I', v_role);
    end if;
  end loop;
end $$;
