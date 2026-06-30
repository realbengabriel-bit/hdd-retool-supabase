const row = tblOifEhPackages?.selectedSourceRow || tblOifEhPackages?.selectedRow || {};
const workflowCaseId = row.workflow_case_id || selectedWorkflowCaseId?.value || "";

const appType = selOifEhApplicationType?.value || row.application_type || row.application_type_code || "";

if (!workflowCaseId) {
  utils.showNotification({
    title: "Nincs workflow_case_id",
    description: "Válassz ki egy P02 / UAHUN csomagot az EH agent futtatáshoz.",
    notificationType: "warning"
  });
  return;
}

const body = {
  workflow_case_id: workflowCaseId,
  live_fill: true,
  allow_submit: false,
  additional_payload: {
    application_type: appType,
    application_type_code: appType,
    xls_free: true,
    agent_version: "v12.1"
  }
};

return await fetch("https://eh-agent-api.hddirekt.com/agent/eh/fill", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify(body)
}).then(r => r.json());
