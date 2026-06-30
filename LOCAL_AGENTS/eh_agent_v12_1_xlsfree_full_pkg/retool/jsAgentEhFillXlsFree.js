const workflowCaseId = selectedWorkflowCaseId.value;
if (!workflowCaseId) {
  utils.showNotification({ title: "Nincs workflow kiválasztva", notificationType: "warning" });
  return;
}

const res = await fetch("https://eh-agent-api.hddirekt.com/agent/eh/fill", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    workflow_case_id: workflowCaseId,
    live_fill: true,
    allow_submit: false
  })
});

const data = await res.json();
if (!res.ok || data.ok === false) {
  utils.showNotification({ title: "EH agent hiba", description: JSON.stringify(data).slice(0, 500), notificationType: "error" });
  return data;
}

utils.showNotification({ title: "EH agent indítva", description: data.run_id || "", notificationType: "success" });
return data;
