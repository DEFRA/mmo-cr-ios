#!/bin/bash
# Xcode Run Script phase (last phase of the record-catch target): writes MMOCRAppConfig into a local
# Debug build's Info.plist from CR_APP_CFG_<KEY> build settings, for every key in the schema (ADR-0020).
set -euo pipefail

# Release builds and archives are configured only by the release pipeline.
if [[ "${CONFIGURATION:-}" != Debug* || "${ACTION:-}" == "install" ]]; then
  exit 0
fi

schema="${SRCROOT}/Config/app-config.schema.json"
plist="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"

# Values come from Config/Local.xcconfig or the xcodebuild command line; Xcode exports build settings as env vars.
# Prints two JSON lines (MMOCRAppConfig, then the ATS exception); warnings go to stderr, where Xcode shows them.
output=$(/usr/bin/python3 - "$schema" <<'PY'
import json, os, sys
from urllib.parse import urlsplit

values, http_hosts = {}, {"localhost"}
for key, spec in json.load(open(sys.argv[1]))["keys"].items():
    value = os.environ.get(f"CR_APP_CFG_{key}", "").strip()
    if not value:
        print(f"warning: CR_APP_CFG_{key} is not set; add it to Config/Local.xcconfig", file=sys.stderr)
    if spec.get("type") == "bool":
        value = value == "true"
    elif spec.get("type") == "url" and urlsplit(value).scheme == "http" and urlsplit(value).hostname:
        http_hosts.add(urlsplit(value).hostname)
    values[key] = value
print(json.dumps(values))
print(json.dumps({"NSExceptionDomains": {h: {"NSExceptionAllowsInsecureHTTPLoads": True} for h in sorted(http_hosts)}}))
PY
)
{ read -r config_json; read -r ats_json; } <<<"$output"

/usr/bin/plutil -replace MMOCRAppConfig -json "$config_json" "$plist"

# Debug only: plain http to localhost and to the host of any local http:// URL (e.g. this Mac's LAN IP for a device).
# Release builds never get an ATS exception.
/usr/bin/plutil -replace NSAppTransportSecurity -json "$ats_json" "$plist"
