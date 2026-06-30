cd C:\EH_AGENT\eh_agent_v12_1_xlsfree_full_pkg

$env:EH_AGENT_PACKAGE_RPC="get_oif_eh_agent_package"
$env:EH_AGENT_PACKAGE_VIEW="v_oif_eh_agent_package_source"
$env:OIF_EH_PDF_GENERATOR_URL="http://127.0.0.1:8787"
$env:EH_AGENT_LEGACY_MODE="search_only"
$env:EH_AGENT_ALLOW_LIVE_FILL="true"
$env:EH_AGENT_RUN_DIR="C:\EH_AGENT\agent_runs"
$env:EH_FILL_SCRIPT_PATH="C:\EH_AGENT\eh_agent_v12_1_xlsfree_full_pkg\eh_enterhungary_assistant_v12_1_payload_first.py"
$env:EH_FILL_COMMAND_TEMPLATE='py "$eh_fill_script_path" --json "$json_path" --application-type $application_type'

py -m uvicorn eh_agent_gateway_v12_1_xlsfree:app --host 127.0.0.1 --port 8788
