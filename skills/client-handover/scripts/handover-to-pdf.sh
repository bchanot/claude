#!/usr/bin/env bash
#
# handover-to-pdf.sh
# ------------------
# Renders a client-handover Markdown report (LIVRAISON.md / HANDOVER.md)
# into a branded HTML and (when a converter is available) a PDF using
# ZenQuality brand styling.
#
# Inputs:
#   $1  Path to the source Markdown file (required)
#
# Optional environment variables:
#   PROJECT_NAME   Displayed on the cover and as PDF page header.
#                  Defaults to the source filename.
#   CLIENT_NAME    Displayed on the cover. Defaults to "—".
#   PROJECT_PERIOD Displayed on the cover (e.g. "01/01/2026 → 31/03/2026").
#                  Defaults to "—".
#   PROJECT_URL    Displayed on the cover. Defaults to "—".
#   LANG           "fr" (default) or "en". Drives cover labels.
#   COVER_TITLE    Defaults to PROJECT_NAME.
#   COVER_SUBTITLE Defaults to "Compte rendu de livraison" (fr) /
#                  "Project handover recap" (en).
#   EYEBROW        Eyebrow line above the title. Defaults to
#                  "Livraison" / "Handover".
#   LOGO_URL       Logo URL or local path. Defaults to a remote
#                  ZenQuality logo (no offline fallback).
#   BRANDING_DIR   Override branding-asset directory. Defaults to the
#                  resources/branding/ folder next to this script.
#
# Behaviour:
#   1. Convert the Markdown body to HTML.
#   2. Wrap it in the ZenQuality template (cover + branded body).
#   3. Convert that HTML into a PDF using the first available engine:
#        weasyprint > wkhtmltopdf > chromium > headless Chrome
#   4. Always keep the .html file next to the .md.
#   5. If no PDF engine is available, exit with code 2 and a clear
#      message — never fail silently.
#
# Exit codes:
#   0  HTML and PDF written successfully.
#   1  Fatal error (bad arguments, missing files, conversion error).
#   2  HTML written but no PDF engine available — manual print needed.

set -euo pipefail

# ---------------------------- CLI ----------------------------------

if [ "$#" -lt 1 ]; then
  echo "usage: handover-to-pdf.sh <markdown-file>" >&2
  exit 1
fi

SRC_MD="$1"

if [ ! -f "$SRC_MD" ]; then
  echo "error: markdown file not found: $SRC_MD" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_BRANDING_DIR="$SCRIPT_DIR/../resources/branding"
BRANDING_DIR="${BRANDING_DIR:-$DEFAULT_BRANDING_DIR}"

if [ ! -f "$BRANDING_DIR/zenquality.css" ] || [ ! -f "$BRANDING_DIR/zenquality-template.html" ]; then
  echo "error: branding assets missing under $BRANDING_DIR" >&2
  echo "       expected: zenquality.css + zenquality-template.html" >&2
  exit 1
fi

OUT_DIR="$(cd "$(dirname "$SRC_MD")" && pwd)"
BASE="$(basename "$SRC_MD" .md)"
OUT_HTML="$OUT_DIR/$BASE.html"
OUT_PDF="$OUT_DIR/$BASE.pdf"

LANG_CODE="${LANG:-fr}"
case "$LANG_CODE" in
  en|EN|en_*|en-*)
    LANG_CODE="en"
    EYEBROW="${EYEBROW:-Project handover}"
    DEFAULT_SUBTITLE="Project handover recap"
    LABEL_CLIENT="Client"
    LABEL_PROJECT="Project"
    LABEL_DATE="Issued"
    LABEL_PERIOD="Period"
    LABEL_URL="Website"
    LABEL_PREPARED_BY="prepared for the client"
    ;;
  *)
    LANG_CODE="fr"
    EYEBROW="${EYEBROW:-Livraison}"
    DEFAULT_SUBTITLE="Compte rendu de livraison"
    LABEL_CLIENT="Client"
    LABEL_PROJECT="Projet"
    LABEL_DATE="Date d'émission"
    LABEL_PERIOD="Période"
    LABEL_URL="Site"
    LABEL_PREPARED_BY="préparé pour le client"
    ;;
esac

PROJECT_NAME_RESOLVED="${PROJECT_NAME:-$BASE}"
CLIENT_NAME_RESOLVED="${CLIENT_NAME:-—}"
PROJECT_PERIOD_RESOLVED="${PROJECT_PERIOD:-—}"
PROJECT_URL_RESOLVED="${PROJECT_URL:-—}"
COVER_TITLE_RESOLVED="${COVER_TITLE:-$PROJECT_NAME_RESOLVED}"
COVER_SUBTITLE_RESOLVED="${COVER_SUBTITLE:-$DEFAULT_SUBTITLE}"
LOGO_URL_RESOLVED="${LOGO_URL:-https://zenquality.fr/assets/logo-horizontal-1024.png}"

if command -v date >/dev/null 2>&1; then
  if [ "$LANG_CODE" = "fr" ]; then
    DATE_HUMAN="$(LC_ALL=fr_FR.UTF-8 date "+%d %B %Y" 2>/dev/null || date "+%Y-%m-%d")"
  else
    DATE_HUMAN="$(LC_ALL=en_US.UTF-8 date "+%d %B %Y" 2>/dev/null || date "+%Y-%m-%d")"
  fi
else
  DATE_HUMAN="$(date "+%Y-%m-%d")"
fi

# ---------------------------- MD -> HTML ---------------------------

md_to_html_body() {
  local src="$1"
  if command -v pandoc >/dev/null 2>&1; then
    pandoc --from=gfm --to=html5 --no-highlight "$src"
    return
  fi
  if command -v python3 >/dev/null 2>&1 && python3 -c "import markdown" >/dev/null 2>&1; then
    python3 -c "
import sys, markdown
src = open(sys.argv[1], encoding='utf-8').read()
print(markdown.markdown(
    src,
    extensions=['extra', 'tables', 'sane_lists', 'toc'],
))" "$src"
    return
  fi
  if command -v npx >/dev/null 2>&1; then
    # marked CLI 16.x ignores stdin and dumps its own cli.js source —
    # always pass the file via -i to get correct output.
    npx --yes marked --gfm -i "$src"
    return
  fi
  echo "error: no Markdown converter available (need pandoc, python3+markdown, or npx)" >&2
  exit 1
}

BODY_HTML="$(md_to_html_body "$SRC_MD")"

# ---------------------------- WRAP HTML ----------------------------

CSS_CONTENT="$(cat "$BRANDING_DIR/zenquality.css")"

render_template() {
  # Read template path from $1, output the substituted HTML on stdout.
  # Substitution variables are pulled from HQ_* environment variables.
  HQ_TEMPLATE_PATH="$1" python3 <<'PY'
import os, sys
path = os.environ["HQ_TEMPLATE_PATH"]
with open(path, encoding="utf-8") as f:
    template = f.read()
mapping = {
    "{{LANG}}":              os.environ.get("HQ_LANG", "fr"),
    "{{TITLE}}":             os.environ.get("HQ_TITLE", ""),
    "{{CSS}}":               os.environ.get("HQ_CSS", ""),
    "{{LOGO_URL}}":          os.environ.get("HQ_LOGO_URL", ""),
    "{{EYEBROW}}":           os.environ.get("HQ_EYEBROW", ""),
    "{{COVER_TITLE}}":       os.environ.get("HQ_COVER_TITLE", ""),
    "{{COVER_SUBTITLE}}":    os.environ.get("HQ_COVER_SUBTITLE", ""),
    "{{CLIENT_NAME}}":       os.environ.get("HQ_CLIENT_NAME", "—"),
    "{{PROJECT_NAME}}":      os.environ.get("HQ_PROJECT_NAME", ""),
    "{{DATE_HUMAN}}":        os.environ.get("HQ_DATE_HUMAN", ""),
    "{{PROJECT_PERIOD}}":    os.environ.get("HQ_PROJECT_PERIOD", "—"),
    "{{PROJECT_URL}}":       os.environ.get("HQ_PROJECT_URL", "—"),
    "{{LABEL_CLIENT}}":      os.environ.get("HQ_LABEL_CLIENT", ""),
    "{{LABEL_PROJECT}}":     os.environ.get("HQ_LABEL_PROJECT", ""),
    "{{LABEL_DATE}}":        os.environ.get("HQ_LABEL_DATE", ""),
    "{{LABEL_PERIOD}}":      os.environ.get("HQ_LABEL_PERIOD", ""),
    "{{LABEL_URL}}":         os.environ.get("HQ_LABEL_URL", ""),
    "{{LABEL_PREPARED_BY}}": os.environ.get("HQ_LABEL_PREPARED_BY", ""),
    "{{CONTENT}}":           os.environ.get("HQ_CONTENT", ""),
}
for k, v in mapping.items():
    template = template.replace(k, v)
sys.stdout.write(template)
PY
}

export HQ_LANG="$LANG_CODE"
export HQ_TITLE="$COVER_TITLE_RESOLVED"
export HQ_CSS="$CSS_CONTENT"
export HQ_LOGO_URL="$LOGO_URL_RESOLVED"
export HQ_EYEBROW="$EYEBROW"
export HQ_COVER_TITLE="$COVER_TITLE_RESOLVED"
export HQ_COVER_SUBTITLE="$COVER_SUBTITLE_RESOLVED"
export HQ_CLIENT_NAME="$CLIENT_NAME_RESOLVED"
export HQ_PROJECT_NAME="$PROJECT_NAME_RESOLVED"
export HQ_DATE_HUMAN="$DATE_HUMAN"
export HQ_PROJECT_PERIOD="$PROJECT_PERIOD_RESOLVED"
export HQ_PROJECT_URL="$PROJECT_URL_RESOLVED"
export HQ_LABEL_CLIENT="$LABEL_CLIENT"
export HQ_LABEL_PROJECT="$LABEL_PROJECT"
export HQ_LABEL_DATE="$LABEL_DATE"
export HQ_LABEL_PERIOD="$LABEL_PERIOD"
export HQ_LABEL_URL="$LABEL_URL"
export HQ_LABEL_PREPARED_BY="$LABEL_PREPARED_BY"
export HQ_CONTENT="$BODY_HTML"

render_template "$BRANDING_DIR/zenquality-template.html" > "$OUT_HTML"

echo "wrote: $OUT_HTML"

# ---------------------------- HTML -> PDF --------------------------

PDF_ENGINE=""
PDF_REASON=""

if command -v weasyprint >/dev/null 2>&1; then
  PDF_ENGINE="weasyprint"
elif command -v wkhtmltopdf >/dev/null 2>&1; then
  PDF_ENGINE="wkhtmltopdf"
elif command -v chromium >/dev/null 2>&1; then
  PDF_ENGINE="chromium"
elif command -v chromium-browser >/dev/null 2>&1; then
  PDF_ENGINE="chromium-browser"
elif command -v google-chrome >/dev/null 2>&1; then
  PDF_ENGINE="google-chrome"
else
  PDF_REASON="no PDF engine found (looked for: weasyprint, wkhtmltopdf, chromium, google-chrome)"
fi

if [ -n "$PDF_ENGINE" ]; then
  case "$PDF_ENGINE" in
    weasyprint)
      weasyprint --base-url "$OUT_DIR/" "$OUT_HTML" "$OUT_PDF"
      ;;
    wkhtmltopdf)
      wkhtmltopdf --enable-local-file-access \
        --margin-top 0 --margin-bottom 0 \
        --margin-left 0 --margin-right 0 \
        --print-media-type \
        "$OUT_HTML" "$OUT_PDF"
      ;;
    chromium|chromium-browser|google-chrome)
      "$PDF_ENGINE" --headless --disable-gpu --no-sandbox \
        --no-pdf-header-footer \
        --print-to-pdf="$OUT_PDF" \
        --print-to-pdf-no-header \
        "file://$OUT_HTML"
      ;;
  esac
  echo "wrote: $OUT_PDF (engine: $PDF_ENGINE)"
  exit 0
fi

cat <<EOF >&2

note: HTML written, but no PDF engine is available.
      reason: $PDF_REASON

To generate $OUT_PDF, install one of:
  - weasyprint   pip install --user weasyprint
  - wkhtmltopdf  apt install wkhtmltopdf  (or download from wkhtmltopdf.org)
  - chromium     apt install chromium-browser
Or open $OUT_HTML in a browser and use "Print → Save as PDF".

EOF
exit 2
