select *
from public.agent_v2_generate_daily_briefing(current_date, 'manual-smoke-test', 100);

select *
from public.agent_v2_get_latest_daily_briefing();
