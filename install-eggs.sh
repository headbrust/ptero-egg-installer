#!/usr/bin/env bash
# ptero-egg-installer — download & optionally import main Pterodactyl eggs
# Usage:
#   ./install-eggs.sh                  # download only
#   ./install-eggs.sh --import         # download + import via API
# Env (for --import):
#   PANEL_URL   e.g. https://panel.example.com
#   API_KEY     Pterodactyl root admin Client API key (ptlc_...) for Panel 2.x
#               or Application API key on some 1.x setups

set -euo pipefail

VERSION="1.0.0"
BASE="https://raw.githubusercontent.com/pterodactyl/generic-eggs/main"
OUT_DIR="${OUT_DIR:-./eggs}"
IMPORT=0

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}[*]${NC} $*"; }
ok()    { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[-]${NC} $*" >&2; }

# name|relative-path
EGGS=(
  "python|python/egg-python-generic.json"
  "java|java/egg-java.json"
  "nodejs|nodejs/egg-node-js-generic.json"
  "bun|bun/egg-bun.json"
  "deno|deno/egg-deno-generic.json"
  "golang|golang/egg-golang-generic.json"
)

usage() {
  cat <<EOF
ptero-egg-installer v${VERSION}

Download main generic eggs for Pterodactyl (Python, Java, Node.js, Bun, Deno, Go).

Usage:
  $0 [options]

Options:
  --import, -i     After download, import each egg via Panel Admin API
  --out DIR        Output directory (default: ./eggs)
  --list           List eggs that will be installed
  -h, --help       Show help

Environment (required for --import):
  PANEL_URL        Panel base URL, e.g. https://panel.example.com
  API_KEY          Root admin Client API key (Panel 2.x: ptlc_...)
                   Create: Admin → Account → API Credentials (Client)

Examples:
  $0
  PANEL_URL=https://panel.example.com API_KEY=ptlc_xxx $0 --import
  curl -fsSL https://raw.githubusercontent.com/headbrust/ptero-egg-installer/main/install-eggs.sh | bash
EOF
}

for arg in "$@"; do
  case "$arg" in
    --import|-i) IMPORT=1 ;;
    --out) shift; OUT_DIR="${1:-./eggs}" ;;
    --list)
      echo "Eggs included:"
      for e in "${EGGS[@]}"; do
        name="${e%%|*}"
        path="${e#*|}"
        echo "  - $name  ($path)"
      done
      exit 0
      ;;
    -h|--help) usage; exit 0 ;;
    *)
      if [[ "$arg" == --out=* ]]; then
        OUT_DIR="${arg#--out=}"
      fi
      ;;
  esac
done

# re-parse --out value if passed as separate
args=("$@")
for ((i=0; i<${#args[@]}; i++)); do
  if [[ "${args[$i]}" == "--out" && $((i+1)) -lt ${#args[@]} ]]; then
    OUT_DIR="${args[$((i+1))]}"
  fi
done

echo ""
echo -e "${GREEN}ptero-egg-installer${NC} v${VERSION}"
echo "----------------------------------------"
mkdir -p "$OUT_DIR"

download_one() {
  local name="$1"
  local rel="$2"
  local url="${BASE}/${rel}"
  local dest="${OUT_DIR}/$(basename "$rel")"
  info "Downloading ${name}..."
  if curl -fsSL -o "$dest" "$url"; then
    ok "Saved $dest"
    return 0
  else
    err "Failed to download $name from $url"
    return 1
  fi
}

import_one() {
  local file="$1"
  local panel="${PANEL_URL%/}"
  local key="$API_KEY"

  if [[ -z "${PANEL_URL:-}" || -z "${API_KEY:-}" ]]; then
    err "PANEL_URL and API_KEY required for --import"
    return 1
  fi

  info "Importing $(basename "$file") → ${panel}/api/admin/eggs/import"
  local code
  code=$(curl -sS -o /tmp/ptero-egg-import-resp.json -w "%{http_code}" \
    -X POST "${panel}/api/admin/eggs/import" \
    -H "Authorization: Bearer ${key}" \
    -H "Accept: application/json" \
    -F "import_file=@${file};type=application/json" || true)

  if [[ "$code" == "201" || "$code" == "200" ]]; then
    local egg_name
    egg_name=$(python3 -c "import json; d=json.load(open('/tmp/ptero-egg-import-resp.json')); print(d.get('attributes',{}).get('name', 'ok'))" 2>/dev/null || echo "ok")
    ok "Imported: $egg_name (HTTP $code)"
    return 0
  fi

  warn "Import HTTP $code for $(basename "$file")"
  if [[ -f /tmp/ptero-egg-import-resp.json ]]; then
    head -c 400 /tmp/ptero-egg-import-resp.json; echo
  fi
  return 1
}

FAILED=0
IMPORTED=0
DOWNLOADED=0

for e in "${EGGS[@]}"; do
  name="${e%%|*}"
  rel="${e#*|}"
  if download_one "$name" "$rel"; then
    DOWNLOADED=$((DOWNLOADED + 1))
    dest="${OUT_DIR}/$(basename "$rel")"
    if [[ "$IMPORT" -eq 1 ]]; then
      if import_one "$dest"; then
        IMPORTED=$((IMPORTED + 1))
      else
        FAILED=$((FAILED + 1))
      fi
    fi
  else
    FAILED=$((FAILED + 1))
  fi
done

echo "----------------------------------------"
ok "Downloaded: $DOWNLOADED egg(s) → $OUT_DIR"

if [[ "$IMPORT" -eq 1 ]]; then
  ok "Imported via API: $IMPORTED"
  [[ "$FAILED" -gt 0 ]] && warn "Failures: $FAILED"
  echo ""
  info "Panel 2.x: eggs appear under Admin → Eggs (assign tags if needed)."
  info "Panel 1.x: if API import failed, use Admin → Nests → Import Egg and upload files from $OUT_DIR"
else
  echo ""
  info "Manual import:"
  echo "  1. Admin → Nests (create nest e.g. Generic if needed)"
  echo "  2. Import Egg → upload each .json from $OUT_DIR"
  echo ""
  info "Or re-run with API import:"
  echo "  PANEL_URL=https://your-panel.com API_KEY=ptlc_xxx $0 --import"
fi

echo ""
warn "After import: edit each egg's startup 'done' detection text so servers leave Starting state."
exit 0
