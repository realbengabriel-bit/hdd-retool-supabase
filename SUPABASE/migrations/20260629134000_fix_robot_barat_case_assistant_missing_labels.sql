-- HDD / UAHUN Robot Barat Case Assistant missing label fix
-- Replaces only public.agent_v2_get_case_assistant(uuid). No writes, no notifications.

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
      ),
      expanded as (
        select
          sr.row_json,
          sr.row_json as item_json,
          null::text as source_array
        from source_rows sr

        union all
        select sr.row_json, elem.value, 'package_hard_missing_items'
        from source_rows sr
        cross join lateral jsonb_array_elements(
          case when jsonb_typeof(sr.row_json->'package_hard_missing_items') = 'array'
            then sr.row_json->'package_hard_missing_items'
            else '[]'::jsonb
          end
        ) elem

        union all
        select sr.row_json, elem.value, 'package_soft_warning_items'
        from source_rows sr
        cross join lateral jsonb_array_elements(
          case when jsonb_typeof(sr.row_json->'package_soft_warning_items') = 'array'
            then sr.row_json->'package_soft_warning_items'
            else '[]'::jsonb
          end
        ) elem

        union all
        select sr.row_json, elem.value, 'accommodation_hard_missing_items'
        from source_rows sr
        cross join lateral jsonb_array_elements(
          case when jsonb_typeof(sr.row_json->'accommodation_hard_missing_items') = 'array'
            then sr.row_json->'accommodation_hard_missing_items'
            else '[]'::jsonb
          end
        ) elem

        union all
        select sr.row_json, elem.value, 'nav_hard_missing_items'
        from source_rows sr
        cross join lateral jsonb_array_elements(
          case when jsonb_typeof(sr.row_json->'nav_hard_missing_items') = 'array'
            then sr.row_json->'nav_hard_missing_items'
            else '[]'::jsonb
          end
        ) elem

        union all
        select sr.row_json, elem.value, 'bmh_oep_activation_missing_items'
        from source_rows sr
        cross join lateral jsonb_array_elements(
          case when jsonb_typeof(sr.row_json->'bmh_oep_activation_missing_items') = 'array'
            then sr.row_json->'bmh_oep_activation_missing_items'
            else '[]'::jsonb
          end
        ) elem

        union all
        select sr.row_json, elem.value, 'bmh_hard_missing_items'
        from source_rows sr
        cross join lateral jsonb_array_elements(
          case when jsonb_typeof(sr.row_json->'bmh_hard_missing_items') = 'array'
            then sr.row_json->'bmh_hard_missing_items'
            else '[]'::jsonb
          end
        ) elem

        union all
        select sr.row_json, elem.value, 'oep_hard_missing_items'
        from source_rows sr
        cross join lateral jsonb_array_elements(
          case when jsonb_typeof(sr.row_json->'oep_hard_missing_items') = 'array'
            then sr.row_json->'oep_hard_missing_items'
            else '[]'::jsonb
          end
        ) elem
      ),
      normalized as (
        select
          e.row_json,
          e.item_json,
          e.source_array,
          nullif(btrim(coalesce(
            e.row_json->>'workflow_case_id',
            e.row_json->>'workflow_case_uuid',
            e.row_json->>'case_id',
            e.row_json->>'workflow_id'
          )), '') as normalized_workflow_case_id,
          nullif(btrim(coalesce(
            e.item_json->>'group_label',
            e.item_json->>'requirement_group',
            e.item_json->>'csoport',
            e.item_json->>'group',
            e.item_json->>'category',
            e.item_json->>'tab',
            e.item_json->>'target_tab',
            e.item_json->>'source_type',
            e.item_json->>'stage',
            e.item_json->>'workflow_stage',
            e.row_json->>'group_label',
            e.row_json->>'requirement_group',
            e.row_json->>'csoport',
            e.row_json->>'group',
            e.row_json->>'category',
            e.row_json->>'tab',
            e.row_json->>'target_tab',
            e.row_json->>'source_type',
            e.row_json->>'stage',
            e.row_json->>'workflow_stage',
            e.source_array
          )), '') as group_raw,
          nullif(btrim(coalesce(
            e.item_json->>'tetel',
            e.item_json->>'hianyzo_tetel',
            e.item_json->>'missing_item',
            e.item_json->>'missing_label',
            e.item_json->>'requirement_label_hu',
            e.item_json->>'requirement_label',
            e.item_json->>'requirement_name',
            e.item_json->>'requirement_title',
            e.item_json->>'requirement_key',
            e.item_json->>'requirement_code',
            e.item_json->>'label_hu',
            e.item_json->>'label',
            e.item_json->>'title',
            e.item_json->>'name',
            e.item_json->>'field_label',
            e.item_json->>'field_name',
            e.item_json->>'item_label',
            e.item_json->>'document_type_label',
            e.item_json->>'document_type_name',
            e.item_json->>'document_type',
            e.item_json->>'document_type_code',
            e.item_json->>'source_column',
            case when jsonb_typeof(e.item_json) in ('string', 'number', 'boolean') then trim(both '"' from e.item_json::text) end,
            e.row_json->>'tetel',
            e.row_json->>'hianyzo_tetel',
            e.row_json->>'missing_item',
            e.row_json->>'missing_label',
            e.row_json->>'requirement_label_hu',
            e.row_json->>'requirement_label',
            e.row_json->>'requirement_name',
            e.row_json->>'requirement_title',
            e.row_json->>'requirement_key',
            e.row_json->>'requirement_code',
            e.row_json->>'label_hu',
            e.row_json->>'label',
            e.row_json->>'title',
            e.row_json->>'name',
            e.row_json->>'field_label',
            e.row_json->>'field_name',
            e.row_json->>'item_label',
            e.row_json->>'document_type_label',
            e.row_json->>'document_type_name',
            e.row_json->>'document_type',
            e.row_json->>'document_type_code',
            e.row_json->>'source_column'
          )), '') as label_raw,
          nullif(btrim(coalesce(
            e.item_json->>'document_type_label',
            e.item_json->>'document_type_name',
            e.item_json->>'document_type',
            e.item_json->>'document_type_code',
            e.item_json->>'suggested_document_type_code',
            e.item_json->>'required_document_type_code',
            e.item_json->>'document_code',
            e.row_json->>'document_type_label',
            e.row_json->>'document_type_name',
            e.row_json->>'document_type',
            e.row_json->>'document_type_code',
            e.row_json->>'suggested_document_type_code',
            e.row_json->>'required_document_type_code',
            e.row_json->>'document_code'
          )), '') as document_text,
          nullif(btrim(coalesce(
            e.item_json->>'source_column',
            e.item_json->>'field_name',
            e.item_json->>'requirement_key',
            e.item_json->>'requirement_code',
            e.row_json->>'source_column',
            e.row_json->>'field_name',
            e.row_json->>'requirement_key',
            e.row_json->>'requirement_code'
          )), '') as technical_key,
          nullif(btrim(coalesce(
            e.item_json->>'sulyossag',
            e.item_json->>'severity',
            e.item_json->>'priority',
            e.item_json->>'risk_level',
            e.row_json->>'sulyossag',
            e.row_json->>'severity',
            e.row_json->>'priority',
            e.row_json->>'risk_level'
          )), '') as missing_severity,
          nullif(btrim(coalesce(
            e.item_json->>'statusz',
            e.item_json->>'status',
            e.item_json->>'missing_status',
            e.item_json->>'requirement_status',
            e.item_json->>'state',
            e.row_json->>'statusz',
            e.row_json->>'status',
            e.row_json->>'missing_status',
            e.row_json->>'requirement_status',
            e.row_json->>'state'
          )), '') as missing_status,
          nullif(btrim(coalesce(
            e.item_json->>'reszletek',
            e.item_json->>'details',
            e.item_json->>'status_message',
            e.item_json->>'message',
            e.item_json->>'blocker_message',
            e.item_json->>'description',
            e.item_json->>'reason',
            e.row_json->>'reszletek',
            e.row_json->>'details',
            e.row_json->>'status_message',
            e.row_json->>'message',
            e.row_json->>'blocker_message',
            e.row_json->>'description',
            e.row_json->>'reason'
          )), '') as missing_details,
          nullif(btrim(coalesce(
            e.item_json->>'retool_target',
            e.item_json->>'target_tab',
            e.item_json->>'tab',
            e.row_json->>'retool_target',
            e.row_json->>'target_tab',
            e.row_json->>'tab'
          )), '') as explicit_target,
          nullif(btrim(coalesce(
            e.item_json->>'source_table',
            e.row_json->>'source_table'
          )), '') as source_table,
          nullif(btrim(coalesce(
            e.item_json->>'raw_requirement',
            e.item_json->>'requirement',
            e.item_json->>'raw',
            e.item_json->>'source_requirement',
            e.row_json->>'raw_requirement',
            e.row_json->>'requirement',
            e.row_json->>'raw',
            e.row_json->>'source_requirement'
          )), '') as raw_requirement_text
        from expanded e
      ),
      enriched as (
        select
          n.*,
          coalesce(n.label_raw, n.document_text, n.technical_key, n.raw_requirement_text) as best_key,
          lower(concat_ws(
            ' ',
            n.label_raw,
            n.document_text,
            n.technical_key,
            n.group_raw,
            n.missing_status,
            n.missing_severity,
            n.missing_details,
            n.explicit_target,
            n.source_table,
            n.raw_requirement_text,
            n.source_array,
            n.row_json::text,
            n.item_json::text
          )) as search_text
        from normalized n
      ),
      classified as (
        select
          e.*,
          case lower(coalesce(e.best_key, ''))
            when 'passport_expiry_date' then 'útlevél lejárati dátum'
            when 'passport_number' then 'útlevélszám'
            when 'residence_permit_number' then 'tartózkodási engedély száma'
            when 'residence_permit_valid_until' then 'tartózkodási engedély érvényessége'
            when 'decision_valid_until' then 'határozat érvényessége'
            when 'decision_number' then 'határozat száma'
            when 'tax_id' then 'adóazonosító'
            when 'taj_number' then 'TAJ szám'
            when 'oep_taj_number' then 'TAJ szám'
            when 'planned_accommodation' then 'tervezett szálláshely'
            when 'planned_arrival_date' then 'tervezett érkezési dátum'
            when 'planned_work_start_date' then 'tervezett munkakezdés'
            when 'birth_date' then 'születési dátum'
            when 'birth_place' then 'születési hely'
            when 'phone' then 'telefonszám'
            else nullif(replace(coalesce(e.best_key, ''), '_', ' '), '')
          end as display_key,
          case
            when coalesce(e.explicit_target, '') in ('Dokumentumok', 'BMH', 'NAV', 'OEP', 'Szálláshely', 'Határidők', 'Alapadatok') then e.explicit_target
            when lower(coalesce(e.explicit_target, '')) in ('documents', 'document', 'dokumentumok', 'dokumentum') then 'Dokumentumok'
            when lower(coalesce(e.explicit_target, '')) in ('accommodation', 'szallashely', 'szálláshely') then 'Szálláshely'
            when lower(coalesce(e.explicit_target, '')) in ('deadlines', 'deadline', 'expiry', 'hataridok', 'határidők') then 'Határidők'
            when e.source_array in ('accommodation_hard_missing_items') then 'Szálláshely'
            when e.source_array in ('nav_hard_missing_items') then 'NAV'
            when e.source_array in ('bmh_oep_activation_missing_items', 'bmh_hard_missing_items') then 'BMH'
            when e.source_array in ('oep_hard_missing_items') then 'OEP'
            when e.search_text like '%dokument%' or e.search_text like '%document%' or e.document_text is not null then 'Dokumentumok'
            when e.search_text like '%bmh%' then 'BMH'
            when e.search_text like '%nav%' or e.search_text like '%adó%' or e.search_text like '%ado%' or e.search_text like '%tax%' then 'NAV'
            when e.search_text like '%oep%' or e.search_text like '%taj%' then 'OEP'
            when e.search_text like '%szállás%' or e.search_text like '%szallas%' or e.search_text like '%accommodation%' then 'Szálláshely'
            when e.search_text like '%határid%' or e.search_text like '%hatarid%' or e.search_text like '%deadline%' or e.search_text like '%expiry%' or e.search_text like '%valid_until%' or e.search_text like '%lejár%' or e.search_text like '%lejar%' then 'Határidők'
            else 'Alapadatok'
          end as retool_target,
          lower(coalesce(e.missing_severity, e.missing_status, e.source_array, '')) as severity_text,
          lower(coalesce(e.missing_status, '')) as status_text
        from enriched e
        where e.normalized_workflow_case_id = $1::text
          and lower(coalesce(e.missing_status, '')) not in ('resolved', 'closed', 'complete', 'completed', 'ok', 'ready', 'done')
          and (
            e.best_key is not null
            or e.source_array is not null
            or (
              e.missing_details is not null
              and e.search_text similar to '%(missing|hiány|hiany|block|blokkol|hard|required|kötelező|kotelezo|pótol|potol)%'
            )
          )
      ),
      shaped as (
        select
          c.*,
          case
            when c.best_key is null and c.missing_details is not null then c.missing_details
            when c.retool_target = 'Dokumentumok' then 'Hiányzó dokumentum: ' || coalesce(c.display_key, c.best_key, c.document_text)
            when c.retool_target = 'BMH' then 'Hiányzó BMH adat: ' || coalesce(c.display_key, c.best_key)
            when c.retool_target = 'NAV' then 'Hiányzó NAV adat: ' || coalesce(c.display_key, c.best_key)
            when c.retool_target = 'OEP' then 'Hiányzó OEP adat: ' || coalesce(c.display_key, c.best_key)
            when c.retool_target = 'Szálláshely' then 'Hiányzó szálláshely adat: ' || coalesce(c.display_key, c.best_key)
            when c.retool_target = 'Határidők' then 'Hiányzó határidő adat: ' || coalesce(c.display_key, c.best_key)
            when c.best_key is not null then 'Hiányzó adat: ' || coalesce(c.display_key, c.best_key)
            else 'Hiányzó tétel'
          end as final_label,
          coalesce(
            nullif(c.group_raw, ''),
            case c.retool_target
              when 'Dokumentumok' then 'Dokumentumok'
              when 'BMH' then 'BMH'
              when 'NAV' then 'NAV'
              when 'OEP' then 'OEP'
              when 'Szálláshely' then 'Szálláshely'
              when 'Határidők' then 'Határidők'
              else 'Alapadatok'
            end
          ) as final_group,
          concat_ws(
            ' | ',
            c.missing_details,
            case when c.technical_key is not null then 'Forrás mező: ' || c.technical_key end,
            case when c.source_table is not null then 'Forrás tábla/nézet: ' || c.source_table end,
            case when c.source_array is not null then 'Forrás lista: ' || c.source_array end,
            case when c.raw_requirement_text is not null and c.raw_requirement_text is distinct from c.best_key then 'Nyers követelmény: ' || c.raw_requirement_text end
          ) as final_details
        from classified c
      )
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'label', s.final_label,
            'group', s.final_group,
            'severity', coalesce(
              s.missing_severity,
              case
                when s.source_array like '%hard%' then 'blocker'
                when s.severity_text similar to '%(blocker|blocking|critical|hard_missing|hard|blokkol|kritikus)%' then 'blocker'
                else 'warning'
              end
            ),
            'status', coalesce(s.missing_status, 'hiányzik'),
            'retool_target', s.retool_target,
            'details', coalesce(s.final_details, ''),
            'source', 'public.v_retool_workflow_missing_requirements',
            'source_array', s.source_array,
            'source_column', s.technical_key,
            'raw_label', s.best_key
          )
          order by
            case
              when s.source_array like '%hard%' then 1
              when s.severity_text similar to '%(blocker|blocking|critical|hard_missing|hard|blokkol|kritikus)%' then 1
              when s.severity_text in ('urgent', 'high') then 2
              when s.severity_text in ('warning', 'soft_warning') then 3
              else 4
            end,
            s.retool_target,
            s.final_group,
            s.final_label
        ),
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
    v_next_best_action := 'Először ezt kezeld: ' || coalesce(v_first_missing_label, 'blokkoló tétel') || ' a(z) ' || coalesce(v_first_missing_target, 'Alapadatok') || ' részen.';
  elsif v_missing_count > 0 or v_documents_missing_count > 0 or v_documents_expired_count > 0 then
    v_case_status := 'Hiányos';
    v_readiness_status := 'Nem kész';
    v_severity := 'warning';
    v_next_best_action := 'Pótold: ' || coalesce(v_first_missing_label, 'hiányzó tétel') || ' a(z) ' || coalesce(v_first_missing_target, 'Alapadatok') || ' részen.';
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
is 'Read-only Robot Barat selected P02 workflow case assistant for Retool with improved missing requirement labels. Null or unknown case id returns zero rows.';

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
