# Robot Barát Daily Briefing Scheduler

## Cél

Ez a Retool Workflow naponta egyszer létrehozza vagy frissíti a Robot Barát napi briefing rekordot a Supabase/PostgreSQL backendben.

Nem küld emailt, Slack/Teams üzenetet, webhookot vagy más külső értesítést. A workflow kizárólag a jóváhagyott backend RPC-t hívja.

## Workflow alapbeállítások

- Workflow név: `Robot Barát Daily Briefing Scheduler`
- Trigger típusa: Scheduled
- Időzóna: `Europe/Budapest`
- Ütemezés: minden nap 08:00
- Manuális futtatás: engedélyezett smoke testhez

## Lépések

### 1. Scheduled trigger

Állítsd be a workflow triggert napi futásra:

- Timezone: `Europe/Budapest`
- Time: `08:00`
- Frequency: daily

### 2. Query step

- Step name: `qGenerateRobotBaratDailyBriefing`
- Resource: ugyanaz a Supabase/PostgreSQL resource, amelyet az UAHUN Retool app használ
- Query type: SQL

```sql
select *
from public.agent_v2_generate_daily_briefing(
  current_date,
  'retool-daily-scheduler',
  100
);
```

## Sikerfeltétel

A workflow futása akkor tekinthető sikeresnek, ha:

- a query pontosan 1 sort ad vissza,
- a visszaadott `status` értéke `ready`,
- a `briefing_key` értéke ezzel kezdődik: `robot_barat_daily_briefing:`.

Javasolt Retool Workflow ellenőrzési logika:

```javascript
const rows = qGenerateRobotBaratDailyBriefing.data || [];

if (!Array.isArray(rows) || rows.length !== 1) {
  throw new Error(`Daily briefing generation expected 1 row, got ${Array.isArray(rows) ? rows.length : 0}.`);
}

const briefing = rows[0];

if (briefing.status !== "ready") {
  throw new Error(`Daily briefing status must be ready, got ${briefing.status || "<empty>"}.`);
}

if (!String(briefing.briefing_key || "").startsWith("robot_barat_daily_briefing:")) {
  throw new Error(`Unexpected daily briefing key: ${briefing.briefing_key || "<empty>"}.`);
}

return briefing;
```

## Hiba esetén

- Ne legyen agresszív retry.
- Ne küldjön külső értesítést.
- A hiba maradjon látható a Retool Workflow run history nézetében.

## Idempotencia

A backend idempotens kulcsot használ:

```text
robot_barat_daily_briefing:<YYYY-MM-DD>
```

Ugyanazon a napon több futtatás ugyanazt a briefing rekordot frissíti, nem hoz létre duplikált napi rekordokat.

## Manuális futtatás

Smoke testhez a workflow manuálisan is futtatható. Ugyanaz az SQL használható:

```sql
select *
from public.agent_v2_generate_daily_briefing(
  current_date,
  'retool-daily-scheduler',
  100
);
```

## Későbbi bővítések

- Később jóváhagyás után hozzáadható email, Slack, Teams vagy Retool notification.
- Később a briefing megjeleníthető a Robot Barát UI-ban.
- Később külön súlyossági küszöbök adhatók a briefing generálásához.

## Biztonsági megjegyzések

- A workflow csak a `public.agent_v2_generate_daily_briefing(...)` RPC-t hívja.
- Nem módosít workflow, dokumentum vagy üzleti táblákat közvetlen SQL-lel.
- Nem tartalmaz raw `insert`, `update`, `delete`, `truncate` vagy destruktív SQL-t.
- Nem tartalmaz email, Slack, Teams, webhook vagy külső notification logikát.
