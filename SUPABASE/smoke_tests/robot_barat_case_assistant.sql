-- Robot Barat Case Assistant smoke test
-- Run after the latest Robot Barat Case Assistant migration.

-- 1) Inspect the database-side definition of the missing requirements source.
select pg_get_viewdef('public.v_retool_workflow_missing_requirements'::regclass, true) as missing_requirements_view_definition;

-- 2) Inspect available source columns for label/debug mapping.
select
  c.ordinal_position,
  c.column_name,
  c.data_type
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name = 'v_retool_workflow_missing_requirements'
order by c.ordinal_position;

-- 3) Pick one workflow case and show raw missing requirement rows.
with picked as (
  select workflow_case_id
  from public.v_retool_workflow_detail_core
  where workflow_case_id is not null
  limit 1
)
select mr.*
from picked p
join public.v_retool_workflow_missing_requirements mr
  on mr.workflow_case_id = p.workflow_case_id;

-- 4) Show the same raw rows as JSON, useful when the view shape differs between environments.
with picked as (
  select workflow_case_id
  from public.v_retool_workflow_detail_core
  where workflow_case_id is not null
  limit 1
)
select to_jsonb(mr) as raw_missing_requirement_json
from picked p
join public.v_retool_workflow_missing_requirements mr
  on mr.workflow_case_id = p.workflow_case_id;

-- 5) Run the Case Assistant for the same picked case.
with picked as (
  select workflow_case_id
  from public.v_retool_workflow_detail_core
  where workflow_case_id is not null
  limit 1
)
select a.*
from picked p
cross join lateral public.agent_v2_get_case_assistant(p.workflow_case_id) a;

-- 6) Validate stable return shape and JSON types.
with picked as (
  select workflow_case_id
  from public.v_retool_workflow_detail_core
  where workflow_case_id is not null
  limit 1
),
result as (
  select a.*
  from picked p
  cross join lateral public.agent_v2_get_case_assistant(p.workflow_case_id) a
)
select
  count(*) <= 1 as returns_at_most_one_row,
  count(*) = 1 as returned_one_row,
  bool_and(workflow_case_id is not null) as workflow_case_id_not_null,
  bool_and(case_status is not null) as case_status_not_null,
  bool_and(readiness_status is not null) as readiness_status_not_null,
  bool_and(severity is not null) as severity_not_null,
  bool_and(jsonb_typeof(blockers) = 'array') as blockers_is_array,
  bool_and(jsonb_typeof(missing_requirements) = 'array') as missing_requirements_is_array,
  bool_and(jsonb_typeof(recommended_actions) = 'array') as recommended_actions_is_array,
  bool_and(jsonb_typeof(source_signals) = 'object') as source_signals_is_object
from result;

-- 7) Label-focused check: useful labels should not be the generic fallback when source has fields/keys.
with picked as (
  select workflow_case_id
  from public.v_retool_workflow_detail_core
  where workflow_case_id is not null
  limit 1
),
assistant as (
  select a.*
  from picked p
  cross join lateral public.agent_v2_get_case_assistant(p.workflow_case_id) a
),
items as (
  select item
  from assistant a
  cross join lateral jsonb_array_elements(a.missing_requirements) as x(item)
)
select
  count(*) as missing_item_count,
  count(*) filter (where item->>'label' = 'Hiányzó tétel') as generic_label_count,
  jsonb_agg(item order by item->>'retool_target', item->>'label') as missing_items
from items;

-- Manual fallback if the automatic picker does not find a case in this environment:
select *
from public.agent_v2_get_case_assistant('PASTE_WORKFLOW_CASE_ID_HERE'::uuid);


-- 8) Array-source readiness row: the actual source is one row per workflow case with missing-item arrays.
with picked as (
  select workflow_case_id
  from public.v_retool_workflow_missing_requirements
  where workflow_case_id is not null
  limit 1
)
select mr.*
from public.v_retool_workflow_missing_requirements mr
join picked p using (workflow_case_id);

-- 9) Assistant output for the same readiness-summary case.
with picked as (
  select workflow_case_id
  from public.v_retool_workflow_missing_requirements
  where workflow_case_id is not null
  limit 1
)
select *
from picked p
cross join lateral public.agent_v2_get_case_assistant(p.workflow_case_id) a;

-- 10) Validation: no generic labels when readiness arrays contain items.
with picked as (
  select workflow_case_id
  from public.v_retool_workflow_missing_requirements
  where workflow_case_id is not null
    and (
      coalesce(jsonb_array_length(case when jsonb_typeof(to_jsonb(package_hard_missing_items)) = 'array' then to_jsonb(package_hard_missing_items) else '[]'::jsonb end), 0) > 0
      or coalesce(jsonb_array_length(case when jsonb_typeof(to_jsonb(package_soft_warning_items)) = 'array' then to_jsonb(package_soft_warning_items) else '[]'::jsonb end), 0) > 0
      or coalesce(jsonb_array_length(case when jsonb_typeof(to_jsonb(accommodation_hard_missing_items)) = 'array' then to_jsonb(accommodation_hard_missing_items) else '[]'::jsonb end), 0) > 0
      or coalesce(jsonb_array_length(case when jsonb_typeof(to_jsonb(nav_hard_missing_items)) = 'array' then to_jsonb(nav_hard_missing_items) else '[]'::jsonb end), 0) > 0
      or coalesce(jsonb_array_length(case when jsonb_typeof(to_jsonb(bmh_oep_activation_missing_items)) = 'array' then to_jsonb(bmh_oep_activation_missing_items) else '[]'::jsonb end), 0) > 0
      or coalesce(jsonb_array_length(case when jsonb_typeof(to_jsonb(bmh_hard_missing_items)) = 'array' then to_jsonb(bmh_hard_missing_items) else '[]'::jsonb end), 0) > 0
      or coalesce(jsonb_array_length(case when jsonb_typeof(to_jsonb(oep_hard_missing_items)) = 'array' then to_jsonb(oep_hard_missing_items) else '[]'::jsonb end), 0) > 0
    )
  limit 1
),
assistant as (
  select a.*
  from picked p
  cross join lateral public.agent_v2_get_case_assistant(p.workflow_case_id) a
)
select
  jsonb_path_exists(missing_requirements, '$[*] ? (@.label == "Hiányzó tétel")') as has_generic_missing_label,
  jsonb_array_length(missing_requirements) as missing_count,
  missing_requirements
from assistant;
