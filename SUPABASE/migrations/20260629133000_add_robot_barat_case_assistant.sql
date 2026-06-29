-- HDD / UAHUN Robot Barat Case Assistant
-- Read-only selected P02 workflow case assistant for Retool.

create or replace function public.agent_v2_get_case_assistant(
  p_workflow_case_id uuid
)
returns table (
  workflow_case_id uuid,
  case_title text,
  case_status text,
  readiness_status text,
  severity text,
  summary_text text,
  blockers jsonb,
  missing_requirements jsonb,
  recommended_actions jsonb,
  retool_targets jsonb,
  next_best_action text,
  source_signals jsonb,
  updated_at timestamptz
)
language plpgsql
security invoker
stable
set search_path = public
as $function$
declare
  v_core jsonb;
  v_core_source text;
  v_stage record;
  v_stage_json jsonb;
  v_package jsonb;
  v_bmh jsonb;
  v_nav jsonb;
  v_oep jsonb;
  v_accommodation jsonb;
  v_missing jsonb := '[]'::jsonb;
  v_blockers jsonb := '[]'::jsonb;
  v_actions jsonb := '[]'::jsonb;
  v_targets jsonb := '[]'::jsonb;
  v_documents jsonb := jsonb_build_object(
    'documents_total_count', 0,
    'documents_required_count', 0,
    'documents_expired_count', 0,
    'documents_expiring_30d_count', 0
  );
  v_missing_count integer := 0;
  v_blocker_count integer := 0;
  v_documents_required_count integer := 0;
  v_documents_missing_count integer := 0;
  v_documents_total_count integer := 0;
  v_documents_expired_count integer := 0;
  v_documents_expiring_30d_count integer := 0;
  v_case_title text;
  v_person_name text;
  v_case_code text;
  v_core_status text;
  v_current_stage text;
  v_package_status text;
  v_bmh_status text;
  v_nav_status text;
  v_oep_status text;
  v_accommodation_status text;
  v_case_status text;
  v_readiness_status text;
  v_severity text;
  v_next_best_action text;
  v_summary_text text;
  v_has_detail_signal boolean := false;
  v_status_signal text;
begin
  if p_workflow_case_id is null then
    -- Retool-friendly behavior: no selected case means no assistant row.
    return;
  end if;

  if to_regclass('public.v_retool_workflow_detail_core') is not null then
    execute $sql$
      select to_jsonb(v)
      from public.v_retool_workflow_detail_core v
      where nullif(btrim(coalesce(
        to_jsonb(v)->>'workflow_case_id',
        to_jsonb(v)->>'workflow_case_uuid',
        to_jsonb(v)->>'case_id',
        to_jsonb(v)->>'workflow_id'
      )), '') = $1::text
      limit 1
    $sql$
    into v_core
    using p_workflow_case_id;

    if v_core is not null then
      v_core_source := 'public.v_retool_workflow_detail_core';
    end if;
  end if;

  if v_core is null and to_regclass('public.v_retool_uahun_workflow_control_with_partner_validation') is not null then
    execute $sql$
      select to_jsonb(v)
      from public.v_retool_uahun_workflow_control_with_partner_validation v
      where nullif(btrim(coalesce(
        to_jsonb(v)->>'workflow_case_id',
        to_jsonb(v)->>'workflow_case_uuid',
        to_jsonb(v)->>'case_id',
        to_jsonb(v)->>'workflow_id'
      )), '') = $1::text
      limit 1
    $sql$
    into v_core
    using p_workflow_case_id;

    if v_core is not null then
      v_core_source := 'public.v_retool_uahun_workflow_control_with_partner_validation';
    end if;
  end if;

  if v_core is null and to_regclass('public.mv_retool_uahun_workflow_control_with_partner_validation') is not null then
    execute $sql$
      select to_jsonb(v)
      from public.mv_retool_uahun_workflow_control_with_partner_validation v
      where nullif(btrim(coalesce(
        to_jsonb(v)->>'workflow_case_id',
        to_jsonb(v)->>'workflow_case_uuid',
        to_jsonb(v)->>'case_id',
        to_jsonb(v)->>'workflow_id'
      )), '') = $1::text
      limit 1
    $sql$
    into v_core
    using p_workflow_case_id;

    if v_core is not null then
      v_core_source := 'public.mv_retool_uahun_workflow_control_with_partner_validation';
    end if;
  end if;

  if v_core is null and to_regclass('public.v_retool_uahun_workflow_new_system_with_partner_validation') is not null then
    execute $sql$
      select to_jsonb(v)
      from public.v_retool_uahun_workflow_new_system_with_partner_validation v
      where nullif(btrim(coalesce(
        to_jsonb(v)->>'workflow_case_id',
        to_jsonb(v)->>'workflow_case_uuid',
        to_jsonb(v)->>'case_id',
        to_jsonb(v)->>'workflow_id'
      )), '') = $1::text
      limit 1
    $sql$
    into v_core
    using p_workflow_case_id;

    if v_core is not null then
      v_core_source := 'public.v_retool_uahun_workflow_new_system_with_partner_validation';
    end if;
  end if;

  if v_core is null then
    -- Unknown case id is represented as zero rows so the UI can show its no-data message.
    return;
  end if;

  for v_stage in
    select *
    from (
      values
        ('package', 'public.v_retool_package_detail'),
        ('bmh', 'public.v_retool_bmh_detail'),
        ('nav', 'public.v_retool_nav_detail'),
        ('oep', 'public.v_retool_oep_detail'),
        ('accommodation', 'public.v_retool_accommodation_detail')
    ) as s(stage_key, view_name)
  loop
    v_stage_json := null;

    if to_regclass(v_stage.view_name) is not null then
      execute format(
        $sql$
          select to_jsonb(v)
          from %s v
          where nullif(btrim(coalesce(
            to_jsonb(v)->>'workflow_case_id',
            to_jsonb(v)->>'workflow_case_uuid',
            to_jsonb(v)->>'case_id',
            to_jsonb(v)->>'workflow_id'
          )), '') = $1::text
          limit 1
        $sql$,
        v_stage.view_name
      )
      into v_stage_json
      using p_workflow_case_id;
    end if;

    if v_stage.stage_key = 'package' then
      v_package := v_stage_json;
    elsif v_stage.stage_key = 'bmh' then
      v_bmh := v_stage_json;
    elsif v_stage.stage_key = 'nav' then
      v_nav := v_stage_json;
    elsif v_stage.stage_key = 'oep' then
      v_oep := v_stage_json;
    elsif v_stage.stage_key = 'accommodation' then
      v_accommodation := v_stage_json;
    end if;
  end loop;

  if to_regclass('public.v_retool_workflow_missing_requirements') is not null then
    execute $sql$
      with source_rows as (
        select to_jsonb(m) as row_json
        from public.v_retool_workflow_missing_requirements m
      ),
      normalized as (
        select
          row_json,
          nullif(btrim(coalesce(
            row_json->>'workflow_case_id',
            row_json->>'workflow_case_uuid',
            row_json->>'case_id',
            row_json->>'workflow_id'
          )), '') as normalized_workflow_case_id,
          nullif(btrim(coalesce(
            row_json->>'csoport',
            row_json->>'group',
            row_json->>'requirement_group',
            row_json->>'stage',
            row_json->>'workflow_stage'
          )), '') as requirement_group,
          nullif(btrim(coalesce(
            row_json->>'hianyzo_tetel',
            row_json->>'missing_item',
            row_json->>'missing_requirement',
            row_json->>'requirement_name',
            row_json->>'title',
            row_json->>'label'
          )), '') as missing_label,
          nullif(btrim(coalesce(
            row_json->>'sulyossag',
            row_json->>'severity',
            row_json->>'priority',
            row_json->>'risk_level'
          )), '') as missing_severity,
          nullif(btrim(coalesce(
            row_json->>'statusz',
            row_json->>'status',
            row_json->>'requirement_status',
            row_json->>'state'
          )), '') as missing_status,
          nullif(btrim(coalesce(
            row_json->>'reszletek',
            row_json->>'details',
            row_json->>'description',
            row_json->>'message',
            row_json->>'reason'
          )), '') as missing_details,
          lower(concat_ws(
            ' ',
            row_json->>'potlas_tipus',
            row_json->>'replacement_type',
            row_json->>'remediation_type',
            row_json->>'missing_type',
            row_json->>'type',
            row_json->>'csoport',
            row_json->>'group',
            row_json->>'requirement_group',
            row_json->>'stage',
            row_json->>'workflow_stage',
            row_json->>'hianyzo_tetel',
            row_json->>'missing_item',
            row_json->>'missing_requirement',
            row_json->>'requirement_name',
            row_json->>'title',
            row_json->>'label',
            row_json->>'suggested_document_type_code',
            row_json->>'document_type_code',
            row_json->>'required_document_type_code',
            row_json->>'document_code'
          )) as search_text
        from source_rows
      ),
      filtered as (
        select
          n.*,
          lower(coalesce(n.missing_severity, '')) as severity_text,
          lower(coalesce(n.missing_status, '')) as status_text,
          case
            when n.search_text like '%dokument%' or n.search_text like '%document%' then 'Dokumentumok'
            when n.search_text like '%bmh%' then 'BMH'
            when n.search_text like '%nav%' or n.search_text like '%adó%' or n.search_text like '%tax%' then 'NAV'
            when n.search_text like '%oep%' or n.search_text like '%taj%' then 'OEP'
            when n.search_text like '%szállás%' or n.search_text like '%szallas%' or n.search_text like '%accommodation%' then 'Szálláshely'
            when n.search_text like '%határid%' or n.search_text like '%hatarid%' or n.search_text like '%deadline%' or n.search_text like '%expiry%' then 'Határidők'
            else 'Alapadatok'
          end as retool_target
        from normalized n
        where n.normalized_workflow_case_id = $1::text
          and lower(coalesce(n.missing_status, '')) not in ('resolved', 'closed', 'complete', 'completed', 'ok', 'ready', 'done')
      )
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'label', coalesce(f.missing_label, f.missing_details, 'Hiányzó tétel'),
            'group', coalesce(f.requirement_group, ''),
            'severity', coalesce(f.missing_severity, 'warning'),
            'status', coalesce(f.missing_status, ''),
            'retool_target', f.retool_target,
            'details', coalesce(f.missing_details, ''),
            'source', 'public.v_retool_workflow_missing_requirements'
          )
          order by
            case
              when f.severity_text in ('blocker', 'blocking', 'hard_missing', 'critical') or f.status_text like '%block%' then 1
              when f.severity_text in ('urgent', 'high') then 2
              when f.severity_text in ('warning', 'soft_warning') then 3
              else 4
            end,
            f.requirement_group nulls last,
            f.missing_label nulls last
        ),
        '[]'::jsonb
      )
      from filtered f
    $sql$
    into v_missing
    using p_workflow_case_id;
  end if;

  if to_regclass('public.v_retool_workflow_documents_central') is not null then
    execute $sql$
      with source_rows as (
        select to_jsonb(d) as row_json
        from public.v_retool_workflow_documents_central d
        where nullif(btrim(coalesce(
          to_jsonb(d)->>'workflow_case_id',
          to_jsonb(d)->>'workflow_case_uuid',
          to_jsonb(d)->>'case_id',
          to_jsonb(d)->>'workflow_id'
        )), '') = $1::text
      ),
      shaped as (
        select
          row_json,
          lower(coalesce(row_json->>'is_required', 'false')) as is_required_text,
          case
            when coalesce(row_json->>'expiry_date', '') ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}'
            then substring(row_json->>'expiry_date' from 1 for 10)::date
          end as expiry_date
        from source_rows
      )
      select jsonb_build_object(
        'documents_total_count', count(*)::integer,
        'documents_required_count', (count(*) filter (
          where is_required_text in ('true', 't', '1', 'yes', 'igen')
        ))::integer,
        'documents_expired_count', (count(*) filter (
          where expiry_date is not null and expiry_date < current_date
        ))::integer,
        'documents_expiring_30d_count', (count(*) filter (
          where expiry_date is not null
            and expiry_date >= current_date
            and expiry_date <= current_date + 30
        ))::integer
      )
      from shaped
    $sql$
    into v_documents
    using p_workflow_case_id;
  end if;

  v_missing_count := jsonb_array_length(coalesce(v_missing, '[]'::jsonb));

  select count(*)::integer
  into v_documents_missing_count
  from jsonb_array_elements(coalesce(v_missing, '[]'::jsonb)) as mr(item)
  where mr.item->>'retool_target' = 'Dokumentumok';

  v_documents_total_count := coalesce((v_documents->>'documents_total_count')::integer, 0);
  v_documents_required_count := coalesce((v_documents->>'documents_required_count')::integer, 0);
  v_documents_expired_count := coalesce((v_documents->>'documents_expired_count')::integer, 0);
  v_documents_expiring_30d_count := coalesce((v_documents->>'documents_expiring_30d_count')::integer, 0);

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'title', coalesce(item->>'label', 'Blokkoló tétel'),
        'reason', coalesce(nullif(item->>'details', ''), nullif(item->>'status', ''), nullif(item->>'group', ''), 'Tisztázást igényel.'),
        'source', coalesce(item->>'source', 'Robot Barát ügysegéd'),
        'retool_target', coalesce(item->>'retool_target', 'Alapadatok')
      )
      order by ord
    ),
    '[]'::jsonb
  )
  into v_blockers
  from jsonb_array_elements(coalesce(v_missing, '[]'::jsonb)) with ordinality as b(item, ord)
  where lower(concat_ws(' ', item->>'severity', item->>'status')) similar to '%(blocker|blocking|critical|hard_missing|blokkol|kritikus)%';

  v_blocker_count := jsonb_array_length(coalesce(v_blockers, '[]'::jsonb));

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'action',
          case coalesce(item->>'retool_target', 'Alapadatok')
            when 'Dokumentumok' then 'Ellenőrizd a Dokumentumok tabot, és kérd be vagy csatold a hiányzó tételt.'
            when 'BMH' then 'Nyisd meg a BMH tabot, és tisztázd a hiányzó BMH adatot vagy döntést.'
            when 'NAV' then 'Nyisd meg a NAV tabot, és ellenőrizd az adózási állapotot.'
            when 'OEP' then 'Nyisd meg az OEP tabot, és ellenőrizd a TAJ/OEP előkészítést.'
            when 'Szálláshely' then 'Nyisd meg a Szálláshely tabot, és pótold a szállásadatokat.'
            when 'Határidők' then 'Nyisd meg a Határidők tabot, és kezeld a lejáró vagy csúszó tételt.'
            else 'Nyisd meg az Alapadatok tabot, és tisztázd a hiányzó ügyadatot.'
          end,
        'why', coalesce(item->>'label', item->>'group', 'Hiányzó tétel'),
        'retool_target', coalesce(item->>'retool_target', 'Alapadatok')
      )
      order by ord
    ),
    '[]'::jsonb
  )
  into v_actions
  from (
    select item, ord
    from jsonb_array_elements(coalesce(v_missing, '[]'::jsonb)) with ordinality as a(item, ord)
    order by ord
    limit 8
  ) limited_missing;

  if jsonb_array_length(coalesce(v_actions, '[]'::jsonb)) = 0 then
    v_actions := jsonb_build_array(
      jsonb_build_object(
        'action', 'Ellenőrizd az ügy aktuális státuszát, majd folytasd a következő operatív lépéssel.',
        'why', 'Nem látszik nyitott hiányzó tétel a rendelkezésre álló nézetekből.',
        'retool_target', 'Alapadatok'
      )
    );
  end if;

  select coalesce(jsonb_agg(to_jsonb(target) order by target), '[]'::jsonb)
  into v_targets
  from (
    select distinct coalesce(item->>'retool_target', 'Alapadatok') as target
    from jsonb_array_elements(coalesce(v_missing, '[]'::jsonb)) as t(item)
    union
    select distinct coalesce(item->>'retool_target', 'Alapadatok') as target
    from jsonb_array_elements(coalesce(v_actions, '[]'::jsonb)) as t(item)
  ) targets
  where target is not null and btrim(target) <> '';

  v_person_name := nullif(btrim(coalesce(
    v_core->>'full_name',
    v_core->>'candidate_full_name',
    v_core->>'employee_name',
    v_core->>'person_name',
    nullif(btrim(concat_ws(' ', v_core->>'last_name', v_core->>'first_name')), '')
  )), '');

  v_case_code := nullif(btrim(coalesce(
    v_core->>'workflow_code',
    v_core->>'request_code',
    v_core->>'case_code',
    v_core->>'request_id',
    v_core->>'application_id'
  )), '');

  v_case_title := nullif(btrim(concat_ws(' - ', coalesce(v_person_name, 'P02 ügy'), v_case_code)), '');
  v_core_status := nullif(btrim(coalesce(
    v_core->>'workflow_status',
    v_core->>'case_status',
    v_core->>'status',
    v_core->>'employment_status'
  )), '');
  v_current_stage := nullif(btrim(coalesce(
    v_core->>'current_stage',
    v_core->>'next_action_area',
    v_core->>'stage',
    v_core->>'workflow_stage'
  )), '');
  v_package_status := nullif(btrim(coalesce(v_package->>'package_status', v_package->>'status', v_package->>'current_stage', v_package->>'stage')), '');
  v_bmh_status := nullif(btrim(coalesce(v_bmh->>'bmh_status', v_bmh->>'decision_status', v_bmh->>'status')), '');
  v_nav_status := nullif(btrim(coalesce(v_nav->>'nav_status', v_nav->>'status')), '');
  v_oep_status := nullif(btrim(coalesce(v_oep->>'oep_status', v_oep->>'taj_status', v_oep->>'status')), '');
  v_accommodation_status := nullif(btrim(coalesce(v_accommodation->>'accommodation_status', v_accommodation->>'status')), '');
  v_has_detail_signal := v_package is not null
    or v_bmh is not null
    or v_nav is not null
    or v_oep is not null
    or v_accommodation is not null
    or v_current_stage is not null
    or v_core_status is not null;

  v_status_signal := lower(concat_ws(
    ' ',
    v_core_status,
    v_current_stage,
    v_package_status,
    v_bmh_status,
    v_nav_status,
    v_oep_status,
    v_accommodation_status
  ));

  if v_blocker_count > 0 then
    v_case_status := 'Blokkolt';
    v_readiness_status := 'Nem kész';
    v_severity := 'critical';
    v_next_best_action := 'Először a blokkoló tételt kezeld a megjelölt Retool helyen.';
  elsif v_missing_count > 0 or v_documents_missing_count > 0 or v_documents_expired_count > 0 then
    v_case_status := 'Hiányos';
    v_readiness_status := 'Nem kész';
    v_severity := 'warning';
    v_next_best_action := 'Pótold a hiányzó tételt a megjelölt Retool tabon.';
  elsif v_has_detail_signal and v_status_signal similar to '%(pending|waiting|wait|in_progress|progress|folyamat|függ|fugg|hiány|hiany|warning|open|nyitott)%' then
    v_case_status := 'Figyelendő';
    v_readiness_status := 'Részben kész';
    v_severity := 'info';
    v_next_best_action := 'Nézd át a státuszokat, és döntsd el, kell-e emberi beavatkozás.';
  elsif v_has_detail_signal then
    v_case_status := 'Kész';
    v_readiness_status := 'Mehet előkészítésre';
    v_severity := 'ok';
    v_next_best_action := 'Nincs látható blokkoló; ellenőrzés után folytatható az előkészítés.';
  else
    v_case_status := 'Ismeretlen';
    v_readiness_status := 'Nincs elég adat';
    v_severity := 'info';
    v_next_best_action := 'Nyisd meg az Alapadatok tabot, és ellenőrizd az ügy alapstátuszát.';
  end if;

  v_summary_text := format(
    'Robot Barát ügyösszefoglaló: %s. Hiányzó tételek: %s, blokkolók: %s, dokumentumhiány: %s.',
    v_case_status,
    v_missing_count,
    v_blocker_count,
    v_documents_missing_count
  );

  workflow_case_id := p_workflow_case_id;
  case_title := coalesce(v_case_title, 'P02 ügy');
  case_status := v_case_status;
  readiness_status := v_readiness_status;
  severity := v_severity;
  summary_text := v_summary_text;
  blockers := coalesce(v_blockers, '[]'::jsonb);
  missing_requirements := coalesce(v_missing, '[]'::jsonb);
  recommended_actions := coalesce(v_actions, '[]'::jsonb);
  retool_targets := coalesce(v_targets, '[]'::jsonb);
  next_best_action := v_next_best_action;
  source_signals := jsonb_build_object(
    'core_source', v_core_source,
    'missing_requirements_count', v_missing_count,
    'blockers_count', v_blocker_count,
    'documents_total_count', v_documents_total_count,
    'documents_required_count', v_documents_required_count,
    'documents_missing_count', v_documents_missing_count,
    'documents_expired_count', v_documents_expired_count,
    'documents_expiring_30d_count', v_documents_expiring_30d_count,
    'case_status_source', v_core_status,
    'current_stage', v_current_stage,
    'package_status', v_package_status,
    'bmh_status', v_bmh_status,
    'nav_status', v_nav_status,
    'oep_status', v_oep_status,
    'accommodation_status', v_accommodation_status,
    'available_sources', jsonb_build_object(
      'workflow_core', v_core is not null,
      'missing_requirements', to_regclass('public.v_retool_workflow_missing_requirements') is not null,
      'documents', to_regclass('public.v_retool_workflow_documents_central') is not null,
      'package', v_package is not null,
      'bmh', v_bmh is not null,
      'nav', v_nav is not null,
      'oep', v_oep is not null,
      'accommodation', v_accommodation is not null
    )
  );
  updated_at := now();

  return next;
end;
$function$;

comment on function public.agent_v2_get_case_assistant(uuid)
is 'Read-only Robot Barat selected P02 workflow case assistant for Retool. Null or unknown case id returns zero rows.';

do $$
declare
  v_role text;
begin
  foreach v_role in array array['authenticated', 'service_role'] loop
    if exists (select 1 from pg_roles where rolname = v_role) then
      execute format('grant execute on function public.agent_v2_get_case_assistant(uuid) to %I', v_role);
    end if;
  end loop;
end $$;
