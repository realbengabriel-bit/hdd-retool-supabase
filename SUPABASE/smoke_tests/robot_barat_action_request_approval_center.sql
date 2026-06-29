-- Robot Barat Action Request Approval Center smoke test
-- Run after SUPABASE/migrations/20260629140000_add_robot_barat_action_request_approval_center.sql.

-- 1) Create and approve one smoke action request.
with seed as (
  select gen_random_uuid()::text as run_id
),
created as (
  select c.*
  from seed s
  cross join lateral public.agent_v2_create_action_request(
    'smoke_test',
    '[SMOKE] approve action request ' || s.run_id,
    'Smoke approval center approve path.',
    'Approve this smoke request only.',
    'Validates approval transition.',
    'warning',
    'smoke_test',
    s.run_id,
    null,
    null,
    null,
    null,
    jsonb_build_object('smoke_run_id', s.run_id, 'path', 'approve'),
    'manual-smoke-test'
  ) c
),
approved as (
  select a.*
  from created c
  cross join lateral public.agent_v2_approve_action_request(c.id, 'manual-smoke-test', 'Smoke approval note.') a
)
select *
from approved;

-- 2) Create and reject another smoke action request.
with seed as (
  select gen_random_uuid()::text as run_id
),
created as (
  select c.*
  from seed s
  cross join lateral public.agent_v2_create_action_request(
    'smoke_test',
    '[SMOKE] reject action request ' || s.run_id,
    'Smoke approval center reject path.',
    'Reject this smoke request only.',
    'Validates rejection transition.',
    'info',
    'smoke_test',
    s.run_id,
    null,
    null,
    null,
    null,
    jsonb_build_object('smoke_run_id', s.run_id, 'path', 'reject'),
    'manual-smoke-test'
  ) c
),
rejected as (
  select r.*
  from created c
  cross join lateral public.agent_v2_reject_action_request(c.id, 'manual-smoke-test', 'Smoke rejection reason.') r
)
select *
from rejected;

-- 3) Create another smoke action request and request clarification.
with seed as (
  select gen_random_uuid()::text as run_id
),
created as (
  select c.*
  from seed s
  cross join lateral public.agent_v2_create_action_request(
    'smoke_test',
    '[SMOKE] clarification action request ' || s.run_id,
    'Smoke approval center clarification path.',
    'Ask for clarification on this smoke request only.',
    'Validates clarification transition.',
    'urgent',
    'smoke_test',
    s.run_id,
    null,
    null,
    null,
    null,
    jsonb_build_object('smoke_run_id', s.run_id, 'path', 'clarification'),
    'manual-smoke-test'
  ) c
),
clarified as (
  select q.*
  from created c
  cross join lateral public.agent_v2_request_action_clarification(c.id, 'manual-smoke-test', 'Smoke clarification question?') q
)
select *
from clarified;

-- 4) Duplicate deterministic key check: same inputs return the same open row.
with seed as (
  select gen_random_uuid()::text as run_id
),
first_created as (
  select c.*
  from seed s
  cross join lateral public.agent_v2_create_action_request(
    'smoke_test',
    '[SMOKE] duplicate action request ' || s.run_id,
    'Smoke duplicate path.',
    'Create once.',
    'Validates deterministic request_key.',
    'info',
    'smoke_test',
    s.run_id,
    null,
    null,
    null,
    null,
    jsonb_build_object('smoke_run_id', s.run_id, 'path', 'duplicate'),
    'manual-smoke-test'
  ) c
),
second_created as (
  select c.*
  from seed s
  cross join lateral public.agent_v2_create_action_request(
    'smoke_test',
    '[SMOKE] duplicate action request ' || s.run_id,
    'Smoke duplicate path.',
    'Create once.',
    'Validates deterministic request_key.',
    'info',
    'smoke_test',
    s.run_id,
    null,
    null,
    null,
    null,
    jsonb_build_object('smoke_run_id', s.run_id, 'path', 'duplicate'),
    'manual-smoke-test'
  ) c
),
row_count as (
  select count(*)::integer as rows_with_same_key
  from public.agent_action_requests ar
  where ar.request_key = (select request_key from first_created)
)
select
  (select id from first_created) = (select id from second_created) as duplicate_returned_same_id,
  (select rows_with_same_key from row_count) = 1 as duplicate_key_has_one_row,
  (select status from first_created) as first_status,
  (select status from second_created) as second_status,
  (select request_key from first_created) as request_key;

-- 5) Read through the list RPC.
select *
from public.agent_v2_get_action_requests('all', 100)
where request_type = 'smoke_test'
  and title like '[SMOKE]%'
order by created_at desc;

-- 6) Validation summary for recent smoke rows.
select
  count(*) filter (where status = 'approved') > 0 as has_approved_smoke_row,
  count(*) filter (where status = 'rejected') > 0 as has_rejected_smoke_row,
  count(*) filter (where status = 'needs_clarification') > 0 as has_clarification_smoke_row,
  count(*) filter (where status = 'executed') = 0 as no_smoke_row_executed,
  bool_and(jsonb_typeof(payload) = 'object') as payload_remains_jsonb_object
from public.agent_action_requests
where request_type = 'smoke_test'
  and title like '[SMOKE]%'
  and created_at >= now() - interval '1 hour';
