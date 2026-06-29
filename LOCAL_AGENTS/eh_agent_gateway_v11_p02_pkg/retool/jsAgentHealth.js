// Example only. Do not wire this to Robot Barát yet.
// This snippet is for a future manual Retool health-check surface.
// It calls only /health and does not execute, fill, submit, or mutate business data.

const gatewayBaseUrl = "http://127.0.0.1:8788";

const response = await fetch(gatewayBaseUrl + "/health", {
  method: "GET",
  headers: {
    "Accept": "application/json"
  }
});

if (!response.ok) {
  throw new Error("EH Agent Gateway health check failed: " + response.status);
}

return await response.json();
