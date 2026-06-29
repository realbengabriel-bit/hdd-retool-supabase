-- HDD / UAHUN Robot Barat Case Assistant array missing item fix
-- Replaces only public.agent_v2_get_case_assistant(uuid). No writes, no external side effects.

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
  v_first_missing jsonb;
  v_first_missing_label text;
  v_first_missing_target text;
  v_first_missing_details text;
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
        where nullif(btrim(coalesce(
          to_jsonb(m)->>'workflow_case_id',
          to_jsonb(m)->>'workflow_case_uuid',
          to_jsonb(m)->>'case_id',
          to_jsonb(m)->>'workflow_id'
        )), '') = $1::text
      ),
      expanded as (
        select
          sr.row_json,
          elem.value as item_json,
          'bmh_hard_missing_items'::text as source_column,
          'BMH'::text as mapped_group,
          'critical'::text as mapped_severity,
          1::integer as source_priority
        from source_rows sr
        cross join lateral jsonb_array_elements(
          case when jsonb_typeof(sr.row_json->'bmh_hard_missing_items') = 'array'
            then sr.row_json->'bmh_hard_missing_items'
            else '[]'::jsonb
          end
        ) elem

        union all
        select
          sr.row_json,
          elem.value,
          'bmh_oep_activation_missing_items',
          'BMH',
          'critical',
          2
        from source_rows sr
        cross join lateral jsonb_array_elements(
          case when jsonb_typeof(sr.row_json->'bmh_oep_activation_missing_items') = 'array'
            then sr.row_json->'bmh_oep_activation_missing_items'
            else '[]'::jsonb
          end
        ) elem

        union all
        select
          sr.row_json,
          elem.value,
          'nav_hard_missing_items',
          'NAV',
          'critical',
          3
        from source_rows sr
        cross join lateral jsonb_array_elements(
          case when jsonb_typeof(sr.row_json->'nav_hard_missing_items') = 'array'
            then sr.row_json->'nav_hard_missing_items'
            else '[]'::jsonb
          end
        ) elem

        union all
        select
          sr.row_json,
          elem.value,
          'oep_hard_missing_items',
          'OEP',
          'critical',
          4
        from source_rows sr
        cross join lateral jsonb_array_elements(
          case when jsonb_typeof(sr.row_json->'oep_hard_missing_items') = 'array'
            then sr.row_json->'oep_hard_missing_items'
            else '[]'::jsonb
          end
        ) elem

        union all
        select
          sr.row_json,
          elem.value,
          'accommodation_hard_missing_items',
          'Szálláshely',
          'critical',
          5
        from source_rows sr
        cross join lateral jsonb_array_elements(
          case when jsonb_typeof(sr.row_json->'accommodation_hard_missing_items') = 'array'
            then sr.row_json->'accommodation_hard_missing_items'
            else '[]'::jsonb
          end
        ) elem

        union all
        select
          sr.row_json,
          elem.value,
          'package_hard_missing_items',
          'Csomagkezelés',
          'critical',
          6
        from source_rows sr
        cross join lateral jsonb_array_elements(
          case when jsonb_typeof(sr.row_json->'package_hard_missing_items') = 'array'
            then sr.row_json->'package_hard_missing_items'
            else '[]'::jsonb
          end
        ) elem

        union all
        select
          sr.row_json,
          elem.value,
          'package_soft_warning_items',
          'Csomagkezelés',
          'warning',
          7
        from source_rows sr
        cross join lateral jsonb_array_elements(
          case when jsonb_typeof(sr.row_json->'package_soft_warning_items') = 'array'
            then sr.row_json->'package_soft_warning_items'
            else '[]'::jsonb
          end
        ) elem
      ),
      normalized as (
        select
          e.*,
          nullif(btrim(
            case
              when jsonb_typeof(e.item_json) = 'string' then e.item_json #>> '{}'
              when jsonb_typeof(e.item_json) in ('number', 'boolean') then e.item_json #>> '{}'
              else e.item_json::text
            end
          ), '') as item_label
        from expanded e
      ),
      deduped as (
        select
          n.*,
          row_number() over (
            partition by lower(n.item_label)
            order by n.source_priority, n.source_column
          ) as duplicate_rank
        from normalized n
        where n.item_label is not null
      ),
      shaped as (
        select
          d.item_label,
          d.mapped_group,
          d.mapped_severity,
          d.source_column,
          d.source_priority,
          jsonb_build_object(
            'label', d.item_label,
            'group', d.mapped_group,
            'severity', d.mapped_severity,
            'status', 'missing',
            'details', 'Hiányzó követelmény: ' || d.item_label,
            'source', 'public.v_retool_workflow_missing_requirements.' || d.source_column,
            'source_array', d.source_column,
            'source_column', d.source_column,
            'retool_target', d.mapped_group,
            'raw_label', d.item_label
          ) as item
        from deduped d
        where d.duplicate_rank = 1
      )
      select coalesce(
        jsonb_agg(s.item order by s.source_priority, s.mapped_group, s.item_label),
        '[]'::jsonb
      )
      from shaped s
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
        'title', coalesce(item->>'label', item->>'raw_label', 'Blokkoló tétel'),
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
  where lower(concat_ws(' ', item->>'severity', item->>'status', item->>'details')) similar to '%(blocker|blocking|critical|hard_missing|hard|blokkol|kritikus)%';

  v_blocker_count := jsonb_array_length(coalesce(v_blockers, '[]'::jsonb));

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'action',
          case coalesce(item->>'retool_target', 'Alapadatok')
            when 'Dokumentumok' then 'Pótold vagy csatold: ' || coalesce(item->>'label', item->>'raw_label', 'hiányzó dokumentum') || '.'
            when 'BMH' then 'Pótold a BMH adatot: ' || coalesce(item->>'label', item->>'raw_label', 'hiányzó BMH adat') || '.'
            when 'NAV' then 'Pótold vagy ellenőrizd a NAV adatot: ' || coalesce(item->>'label', item->>'raw_label', 'hiányzó NAV adat') || '.'
            when 'OEP' then 'Pótold vagy ellenőrizd az OEP adatot: ' || coalesce(item->>'label', item->>'raw_label', 'hiányzó OEP adat') || '.'
            when 'Szálláshely' then 'Pótold a szálláshely adatot: ' || coalesce(item->>'label', item->>'raw_label', 'hiányzó szálláshely adat') || '.'
            when 'Határidők' then 'Ellenőrizd a határidő adatot: ' || coalesce(item->>'label', item->>'raw_label', 'hiányzó határidő adat') || '.'
            else 'Pótold az ügyadatot: ' || coalesce(item->>'label', item->>'raw_label', 'hiányzó adat') || '.'
          end,
        'why', coalesce(nullif(item->>'details', ''), item->>'label', item->>'group', 'Hiányzó követelmény.'),
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

  select item, item->>'label', coalesce(item->>'retool_target', 'Alapadatok'), item->>'details'
  into v_first_missing, v_first_missing_label, v_first_missing_target, v_first_missing_details
  from jsonb_array_elements(coalesce(v_missing, '[]'::jsonb)) with ordinality as fm(item, ord)
  order by ord
  limit 1;

  if v_blocker_count > 0 then
    v_case_status := 'Blokkolt';
    v_readiness_status := 'Nem kész';
    v_severity := 'critical';
    v_next_best_action := 'Pótold ezt: ' || coalesce(v_first_missing_label, 'blokkoló tétel') || '. Kezelés helye: ' || coalesce(v_first_missing_target, 'Alapadatok') || '.';
  elsif v_missing_count > 0 or v_documents_missing_count > 0 or v_documents_expired_count > 0 then
    v_case_status := 'Hiányos';
    v_readiness_status := 'Nem kész';
    v_severity := 'warning';
    v_next_best_action := 'Pótold ezt: ' || coalesce(v_first_missing_label, 'hiányzó tétel') || '. Kezelés helye: ' || coalesce(v_first_missing_target, 'Alapadatok') || '.';
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
is 'Read-only Robot Barat selected P02 workflow case assistant for Retool with array-based missing requirement extraction. Null or unknown case id returns zero rows.';

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
