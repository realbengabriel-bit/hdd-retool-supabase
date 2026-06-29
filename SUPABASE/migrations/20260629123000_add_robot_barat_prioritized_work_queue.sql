-- HDD / UAHUN Robot Barat prioritized work queue
-- Read-only operational queue for Retool / Robot Barat. No writes, no cron, no notifications.

create or replace function public.agent_v2_get_prioritized_work_queue(
  p_limit integer default 50
)
returns table (
  priority_rank integer,
  priority_score integer,
  priority_bucket text,
  severity text,
  category text,
  item_title text,
  item_summary text,
  recommended_action text,
  retool_target text,
  workflow_case_id uuid,
  candidate_id uuid,
  assignment_id uuid,
  alert_event_id uuid,
  alert_key text,
  source_table text,
  source_id text,
  created_at timestamptz,
  updated_at timestamptz,
  metadata jsonb
)
language sql
security invoker
stable
set search_path = public
as $function$
  with params as (
    select least(greatest(coalesce(p_limit, 50), 1), 200)::integer as row_limit
  ),
  latest_briefing as (
    select b.briefing_date, b.generated_at
    from public.agent_daily_briefings b
    where b.status <> 'archived'
    order by b.generated_at desc nulls last,
             b.created_at desc nulls last,
             b.id
    limit 1
  ),
  base_events as (
    select
      e.id,
      e.rule_id,
      e.alert_key,
      e.category,
      e.severity,
      e.entity_type,
      e.entity_id,
      e.title,
      e.message,
      e.payload,
      e.status,
      e.first_seen_at,
      e.last_seen_at,
      e.created_at,
      st.suppress_until,
      st.state_json,
      r.rule_key,
      r.rule_name,
      r.is_enabled
    from public.agent_alert_events e
    left join public.agent_alert_state st
      on st.alert_key = e.alert_key
    left join public.agent_alert_rules r
      on r.id = e.rule_id
    where e.status in ('open', 'active')
      and coalesce(r.is_enabled, true) is true
      and (st.suppress_until is null or st.suppress_until <= now())
      and lower(coalesce(st.state_json ->> 'status', '')) not in ('resolved', 'dismissed', 'suppressed')
  ),
  normalized as (
    select
      be.*,
      coalesce(
        nullif(be.payload ->> 'workflow_case_id', ''),
        nullif(be.payload #>> '{workflow,case_id}', ''),
        nullif(be.payload #>> '{workflow_case,id}', ''),
        case when be.entity_type = 'workflow_case' then nullif(be.entity_id, '') end
      ) as workflow_case_id_text,
      coalesce(
        nullif(be.payload ->> 'candidate_id', ''),
        nullif(be.payload #>> '{candidate,id}', ''),
        case when be.entity_type = 'candidate' then nullif(be.entity_id, '') end
      ) as candidate_id_text,
      coalesce(
        nullif(be.payload ->> 'assignment_id', ''),
        nullif(be.payload #>> '{assignment,id}', ''),
        case when be.entity_type = 'assignment' then nullif(be.entity_id, '') end
      ) as assignment_id_text,
      lower(coalesce(be.severity, 'info')) as severity_norm,
      lower(coalesce(be.category, 'system')) as category_norm,
      greatest(0, floor(extract(epoch from (now() - coalesce(be.first_seen_at, be.created_at, now()))) / 86400.0))::integer as age_days
    from base_events be
  ),
  scored as (
    select
      n.*,
      (
        case n.severity_norm
          when 'critical' then 1100
          when 'blocker' then 1000
          when 'urgent' then 850
          when 'warning' then 600
          else 300
        end
        +
        case n.category_norm
          when 'action_request' then 250
          when 'failed_action_request' then 260
          when 'workflow_blocker' then 240
          when 'missing_documents' then 190
          when 'missing_document' then 190
          when 'oif_readiness_changes' then 150
          when 'oif_readiness' then 150
          when 'document_expiry_30d' then 130
          when 'expiry' then 130
          when 'napi_drive_incomplete_daily' then 125
          when 'napi_drive' then 125
          when 'bmh_nav_oep_stage_aging' then 120
          when 'stage_aging' then 120
          when 'daily_briefing' then 50
          else 40
        end
        +
        case n.status
          when 'active' then 45
          when 'open' then 30
          else 0
        end
        +
        case
          when n.age_days >= 14 then 95
          when n.age_days >= 7 then 70
          when n.age_days >= 3 then 45
          when n.age_days >= 1 then 20
          else 0
        end
        +
        case
          when coalesce(n.last_seen_at, n.created_at) >= now() - interval '24 hours' then 20
          when coalesce(n.last_seen_at, n.created_at) >= now() - interval '72 hours' then 10
          else 0
        end
      )::integer as score
    from normalized n
  ),
  shaped as (
    select
      s.score as priority_score,
      case
        when s.score >= 1150 then 'Azonnali'
        when s.score >= 850 then 'Ma intézendő'
        when s.score >= 650 then 'Következő'
        else 'Figyelés'
      end as priority_bucket,
      coalesce(s.severity, 'info') as severity,
      coalesce(s.category, 'system') as category,
      coalesce(nullif(s.title, ''), 'Robot Barát jelzés') as item_title,
      concat_ws(
        ' ',
        case
          when s.severity_norm in ('critical', 'blocker') then 'Blokkoló vagy kritikus jelzés, elsőként érdemes kezelni.'
          when s.severity_norm = 'urgent' then 'Sürgős jelzés, mai visszajelzést igényel.'
          when s.severity_norm = 'warning' then 'Figyelmeztetés, ami később blokkolóvá válhat.'
          else 'Nyitott kontroll jelzés.'
        end,
        coalesce(nullif(s.message, ''), nullif(s.payload ->> 'summary', ''), nullif(s.payload ->> 'reason', ''))
      ) as item_summary,
      case s.category_norm
        when 'action_request' then 'Nézd át az action requestet, és döntsd el, kell-e emberi jóváhagyás vagy további adat.'
        when 'failed_action_request' then 'Ellenőrizd a sikertelen action request okát, majd kézzel döntsd el a következő lépést.'
        when 'workflow_blocker' then 'Nyisd meg az érintett P02 ügyet, tisztázd a blokkoló okot, és jelölj ki felelőst.'
        when 'missing_documents' then 'Ellenőrizd a dokumentumlistát, kérd be vagy töltsd fel a hiányzó dokumentumot.'
        when 'missing_document' then 'Ellenőrizd a dokumentumlistát, kérd be vagy töltsd fel a hiányzó dokumentumot.'
        when 'oif_readiness_changes' then 'Nézd át az OIF/EH készenléti változást, mielőtt bármilyen helyi agent folyamat indulna.'
        when 'oif_readiness' then 'Nézd át az OIF/EH készenléti állapotot, mielőtt bármilyen helyi agent folyamat indulna.'
        when 'document_expiry_30d' then 'Ellenőrizd a határidőt, és indíts előkészítést vagy partneri egyeztetést.'
        when 'expiry' then 'Ellenőrizd a határidőt, és indíts előkészítést vagy partneri egyeztetést.'
        when 'napi_drive_incomplete_daily' then 'Nézd át a Napi Drive hiányos napi tételeit, és zárd le a szükséges kontrollt.'
        when 'napi_drive' then 'Nézd át a Napi Drive kontrollt, és zárd le a szükséges napi teendőt.'
        when 'bmh_nav_oep_stage_aging' then 'Ellenőrizd a BMH/NAV/OEP státuszt és a túl régóta álló lépést.'
        when 'stage_aging' then 'Ellenőrizd a BMH/NAV/OEP státuszt és a túl régóta álló lépést.'
        else 'Nyisd meg a Robot Barát Jelzések nézetet, és értékeld a jelzés részleteit.'
      end as recommended_action,
      case s.category_norm
        when 'action_request' then 'Action request jóváhagyás'
        when 'failed_action_request' then 'Action request jóváhagyás'
        when 'workflow_blocker' then 'P02 ügyek / BMH-NAV-OEP'
        when 'missing_documents' then 'P02 ügyek / Dokumentumok'
        when 'missing_document' then 'P02 ügyek / Dokumentumok'
        when 'oif_readiness_changes' then 'P02 ügyek / BMH-NAV-OEP'
        when 'oif_readiness' then 'P02 ügyek / BMH-NAV-OEP'
        when 'document_expiry_30d' then 'P02 ügyek / Határidők'
        when 'expiry' then 'P02 ügyek / Határidők'
        when 'napi_drive_incomplete_daily' then 'Napi Drive kontroll'
        when 'napi_drive' then 'Napi Drive kontroll'
        when 'bmh_nav_oep_stage_aging' then 'P02 ügyek / BMH-NAV-OEP'
        when 'stage_aging' then 'P02 ügyek / BMH-NAV-OEP'
        else 'Robot Barát Jelzések'
      end as retool_target,
      case
        when s.workflow_case_id_text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        then s.workflow_case_id_text::uuid
      end as workflow_case_id,
      case
        when s.candidate_id_text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        then s.candidate_id_text::uuid
      end as candidate_id,
      case
        when s.assignment_id_text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        then s.assignment_id_text::uuid
      end as assignment_id,
      s.id as alert_event_id,
      s.alert_key,
      'agent_alert_events'::text as source_table,
      coalesce(nullif(s.entity_id, ''), s.id::text) as source_id,
      coalesce(s.created_at, s.first_seen_at, s.last_seen_at) as created_at,
      coalesce(s.last_seen_at, s.created_at, s.first_seen_at) as updated_at,
      jsonb_build_object(
        'alert_status', s.status,
        'entity_type', s.entity_type,
        'entity_id', s.entity_id,
        'message', s.message,
        'rule_id', s.rule_id,
        'rule_key', s.rule_key,
        'rule_name', s.rule_name,
        'first_seen_at', s.first_seen_at,
        'last_seen_at', s.last_seen_at,
        'age_days', s.age_days,
        'suppress_until', s.suppress_until,
        'state_json', coalesce(s.state_json, '{}'::jsonb),
        'payload', coalesce(s.payload, '{}'::jsonb),
        'latest_briefing_date', (select lb.briefing_date from latest_briefing lb),
        'latest_briefing_generated_at', (select lb.generated_at from latest_briefing lb)
      ) as metadata
    from scored s
  ),
  ranked as (
    select
      (row_number() over (
        order by
          sh.priority_score desc,
          sh.updated_at desc nulls last,
          sh.created_at asc nulls last,
          sh.alert_event_id
      ))::integer as priority_rank,
      sh.*
    from shaped sh
  )
  select
    r.priority_rank,
    r.priority_score,
    r.priority_bucket,
    r.severity,
    r.category,
    r.item_title,
    r.item_summary,
    r.recommended_action,
    r.retool_target,
    r.workflow_case_id,
    r.candidate_id,
    r.assignment_id,
    r.alert_event_id,
    r.alert_key,
    r.source_table,
    r.source_id,
    r.created_at,
    r.updated_at,
    r.metadata
  from ranked r
  order by r.priority_rank
  limit (select p.row_limit from params p);
$function$;

comment on function public.agent_v2_get_prioritized_work_queue(integer)
is 'Read-only Robot Barat prioritized daily work queue for Retool. It ranks open/active alert events and does not execute actions, generate briefings, materialize alerts, send notifications, or write business data.';

do $$
declare
  v_role text;
begin
  foreach v_role in array array['authenticated', 'service_role'] loop
    if exists (select 1 from pg_roles where rolname = v_role) then
      execute format('grant execute on function public.agent_v2_get_prioritized_work_queue(integer) to %I', v_role);
    end if;
  end loop;
end $$;
