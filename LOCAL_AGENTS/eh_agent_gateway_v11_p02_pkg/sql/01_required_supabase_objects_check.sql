-- EH Agent Gateway v11 P02-first required Supabase object inventory check
-- Read-only checks only. This file contains no DDL or DML statements.

select
  'function' as object_type,
  'get_oif_eh_agent_package' as object_name,
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'get_oif_eh_agent_package'
  ) as exists_in_public;

select
  'relation' as object_type,
  'v_oif_eh_agent_package_source' as object_name,
  exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'v_oif_eh_agent_package_source'
      and c.relkind in ('v', 'm', 'r', 'p')
  ) as exists_in_public;

select
  'relation' as object_type,
  'v_retool_oif_eh_payload_preview' as object_name,
  exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'v_retool_oif_eh_payload_preview'
      and c.relkind in ('v', 'm', 'r', 'p')
  ) as exists_in_public;

select
  'relation' as object_type,
  'v_retool_oif_eh_attachment_manifest' as object_name,
  exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'v_retool_oif_eh_attachment_manifest'
      and c.relkind in ('v', 'm', 'r', 'p')
  ) as exists_in_public;

select
  'relation' as object_type,
  'v_retool_eh_local_agent_run_log' as object_name,
  exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'v_retool_eh_local_agent_run_log'
      and c.relkind in ('v', 'm', 'r', 'p')
  ) as exists_in_public;
