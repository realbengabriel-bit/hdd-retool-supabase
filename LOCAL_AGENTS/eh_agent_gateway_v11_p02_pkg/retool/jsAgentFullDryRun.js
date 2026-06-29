// Example only. Do not wire this to Robot Barát yet.
// This snippet is for a future manual Retool full dry-run surface.
// It must not submit EH/OIF, must not open a browser, and must not auto-run.

const gatewayBaseUrl = "http://127.0.0.1:8788";
const gatewayToken = "PASTE_OPERATOR_TOKEN_HERE";

const payload = {
  workflow_case_id: selectedWorkflowCaseId?.value || null,
  candidate_id: null,
  assignment_id: null,
  rq_code: null,
  requested_by: current_user?.email || "manual-retool-operator",
  dry_run: true
};

const response = await fetch(gatewayBaseUrl + "/agent/run-full-dry", {
  method: "POST",
  headers: {
    "Accept": "application/json",
    "Content-Type": "application/json",
    "Authorization": "Bearer " + gatewayToken
  },
  body: JSON.stringify(payload)
});

if (!response.ok) {
  throw new Error("EH Agent full dry run failed: " + response.status);
}

const result = await response.json();

if (result.execution_allowed_now !== false) {
  throw new Error("Safety violation: execution_allowed_now must be false.");
}

return result;
