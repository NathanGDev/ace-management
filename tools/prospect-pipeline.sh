#!/usr/bin/env bash
set -uo pipefail

# ============================================================
# ♠️  Ace Growth — One-Command Prospect Pipeline
#
# Takes a business URL (or name + city) and automatically:
#   1. Researches the business (scrape site, extract info)
#   2. Generates a growth audit
#   3. Generates a demo website
#   4. Deploys both to acegrowth.net/demos/[slug]/
#   5. Outputs a call brief for Kae
#
# Usage:
#   ./prospect-pipeline.sh https://example.com
#   ./prospect-pipeline.sh "Business Name" "City"
#
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AUDIT_GENERATOR="$REPO_ROOT/tools/audit-generator/generate-audit.sh"
SITE_GENERATOR="$REPO_ROOT/templates/contractor-site/generate.sh"
DEPLOY_ROOT="/var/www/acemanagement.so/demos"
TMP_DIR="/tmp/prospect-pipeline-$$"
RESEARCH_FILE="$TMP_DIR/research.json"
AUDIT_FILE="$TMP_DIR/audit.json"
SITE_CONFIG="$TMP_DIR/site-config.json"
HTML_FILE="$TMP_DIR/website.html"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ──────────────────────────────────────
# Helper functions
# ──────────────────────────────────────

usage() {
    echo "♠️  Ace Growth — Prospect Pipeline"
    echo ""
    echo "Usage:"
    echo "  $0 <url>                    # Research by URL"
    echo "  $0 \"Business Name\" \"City\"   # Research by name + city"
    echo ""
    echo "Examples:"
    echo "  $0 https://blackrealtycompany.com"
    echo "  $0 \"Black Realty Company\" \"Indianapolis\""
    echo ""
    echo "Options:"
    echo "  --no-deploy    Generate but don't deploy"
    echo "  --audit-only   Only generate the audit"
    echo "  --demo-only    Only generate the demo site"
    exit 1
}

log_step() { echo -e "\n${BOLD}${CYAN}━━━ $1 ━━━${NC}"; }
log_ok()   { echo -e "${GREEN}✅ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_err()  { echo -e "${RED}❌ $1${NC}"; }

slugify() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//g'
}

cleanup() {
    cp "$TMP_DIR"/*.json /tmp/ 2>/dev/null || true
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

check_deps() {
    for cmd in curl jq python3; do
        if ! command -v "$cmd" &>/dev/null; then
            if [ "$cmd" = "jq" ]; then
                echo "Installing jq..."
                apt-get install -y jq >/dev/null 2>&1
            else
                log_err "Required command not found: $cmd"
                exit 1
            fi
        fi
    done
    [ ! -f "$AUDIT_GENERATOR" ] && log_err "Audit generator not found: $AUDIT_GENERATOR" && exit 1
    [ ! -f "$SITE_GENERATOR" ] && log_err "Site generator not found: $SITE_GENERATOR" && exit 1
}

# ──────────────────────────────────────
# Parse input
# ──────────────────────────────────────

WEBSITE_URL=""
BUSINESS_SEARCH_NAME=""
BUSINESS_CITY="Indianapolis"
DO_DEPLOY=true
AUDIT_ONLY=false
DEMO_ONLY=false

parse_input() {
    [ $# -lt 1 ] && usage

    local positional=()
    for arg in "$@"; do
        case "$arg" in
            --no-deploy) DO_DEPLOY=false ;;
            --audit-only) AUDIT_ONLY=true ;;
            --demo-only) DEMO_ONLY=true ;;
            --help|-h) usage ;;
            *) positional+=("$arg") ;;
        esac
    done

    [ ${#positional[@]} -eq 0 ] && usage

    if [[ "${positional[0]}" =~ ^https?:// ]]; then
        WEBSITE_URL="${positional[0]}"
    elif [[ "${positional[0]}" =~ \.[a-z]{2,}$ ]]; then
        WEBSITE_URL="https://${positional[0]}"
    else
        BUSINESS_SEARCH_NAME="${positional[0]}"
        [ ${#positional[@]} -ge 2 ] && BUSINESS_CITY="${positional[1]}"
    fi
}

# ──────────────────────────────────────
# Phase 1: Research (fetch HTML)
# ──────────────────────────────────────

fetch_website() {
    local url="$1"
    log_step "PHASE 1: RESEARCH — $url"

    echo "  Fetching website..."
    local status_code
    status_code=$(curl -sS -L -o "$HTML_FILE" -w "%{http_code}" \
        --max-time 30 \
        --user-agent "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
        "$url" 2>/dev/null) || true

    if [ ! -f "$HTML_FILE" ] || [ "$(wc -c < "$HTML_FILE")" -lt 100 ]; then
        log_warn "Could not fetch website (HTTP $status_code). Using defaults."
        echo "<html><head><title>Unknown Business</title></head><body></body></html>" > "$HTML_FILE"
    else
        log_ok "Fetched website (HTTP $status_code, $(wc -c < "$HTML_FILE" | tr -d ' ') bytes)"
    fi

    # Try fetching additional pages
    local base_url
    base_url=$(echo "$url" | sed -E 's|(https?://[^/]+).*|\1|')

    for page in about about-us contact contact-us services our-services; do
        local page_file="$TMP_DIR/${page}.html"
        curl -sS -L -o "$page_file" --max-time 15 \
            --user-agent "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
            "${base_url}/${page}" 2>/dev/null || true
        if [ -f "$page_file" ] && [ "$(wc -c < "$page_file")" -gt 500 ]; then
            echo "  Found /${page} page"
            cat "$page_file" >> "$HTML_FILE"
        fi
    done
}

research_by_name() {
    local name="$1"
    local city="$2"
    log_step "PHASE 1: RESEARCH — $name ($city)"

    local search_slug
    search_slug=$(echo "$name" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//g')

    local found_url=""
    for domain_suffix in ".com" ".net" ".org" ".biz"; do
        local try_url="https://${search_slug}${domain_suffix}"
        local http_code
        http_code=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 10 -L "$try_url" 2>/dev/null) || true
        if [ "$http_code" = "200" ] || [ "$http_code" = "301" ] || [ "$http_code" = "302" ]; then
            found_url="$try_url"
            echo "  Found website: $found_url"
            break
        fi
    done

    if [ -z "$found_url" ]; then
        local no_hyphen
        no_hyphen=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
        for domain_suffix in ".com" ".net" ".org"; do
            local try_url="https://${no_hyphen}${domain_suffix}"
            local http_code
            http_code=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 10 -L "$try_url" 2>/dev/null) || true
            if [ "$http_code" = "200" ] || [ "$http_code" = "301" ] || [ "$http_code" = "302" ]; then
                found_url="$try_url"
                echo "  Found website: $found_url"
                break
            fi
        done
    fi

    if [ -n "$found_url" ]; then
        WEBSITE_URL="$found_url"
        fetch_website "$found_url"
    else
        log_warn "Could not find website. Creating minimal research."
        WEBSITE_URL=""
        echo "<html><head><title>$name</title></head><body></body></html>" > "$HTML_FILE"
    fi
}

# ──────────────────────────────────────
# The Python analysis engine
# Handles research, audit JSON, and site config
# in one robust script to avoid shell quoting issues
# ──────────────────────────────────────

run_analysis() {
    log_step "ANALYZING WEBSITE & GENERATING DATA"

    python3 "$SCRIPT_DIR/prospect-analyzer.py" \
        --html "$HTML_FILE" \
        --url "$WEBSITE_URL" \
        --research-out "$RESEARCH_FILE" \
        --audit-out "$AUDIT_FILE" \
        --site-config-out "$SITE_CONFIG" \
        ${BUSINESS_SEARCH_NAME:+--override-name "$BUSINESS_SEARCH_NAME"} \
        ${BUSINESS_CITY:+--city "$BUSINESS_CITY"}
}

# ──────────────────────────────────────
# Phase 2: Generate Audit HTML
# ──────────────────────────────────────

generate_audit_html() {
    log_step "GENERATING AUDIT HTML"
    echo "  Running audit generator..."
    bash "$AUDIT_GENERATOR" "$AUDIT_FILE" 2>&1 | sed 's/^/  /'
    log_ok "Audit HTML generated"
}

# ──────────────────────────────────────
# Phase 3: Generate Demo Site
# ──────────────────────────────────────

generate_demo_site() {
    log_step "GENERATING DEMO SITE"
    local demo_output="$TMP_DIR/demo-site"
    mkdir -p "$demo_output"
    echo "  Running site generator..."
    bash "$SITE_GENERATOR" "$SITE_CONFIG" "$demo_output" 2>&1 | sed 's/^/  /'
    log_ok "Demo site generated"
}

# ──────────────────────────────────────
# Phase 4: Deploy
# ──────────────────────────────────────

deploy() {
    log_step "DEPLOYING TO PRODUCTION"

    local biz_name slug
    biz_name=$(jq -r '.businessName' "$RESEARCH_FILE")
    slug=$(slugify "$biz_name")

    local deploy_dir="$DEPLOY_ROOT/$slug"
    mkdir -p "$deploy_dir"

    # Deploy audit
    local audit_output
    audit_output=$(find "$REPO_ROOT/tools/audit-generator/output" -name "${slug}*audit*.html" -type f 2>/dev/null | sort | tail -1)
    if [ -z "$audit_output" ]; then
        audit_output=$(find "$REPO_ROOT/tools/audit-generator/output" -name "*.html" -newer "$AUDIT_FILE" -type f 2>/dev/null | head -1)
    fi
    if [ -n "$audit_output" ] && [ -f "$audit_output" ]; then
        cp "$audit_output" "$deploy_dir/growth-audit.html"
        chmod 644 "$deploy_dir/growth-audit.html"
        log_ok "Audit deployed"
    else
        log_warn "Audit HTML not found for deployment"
    fi

    # Deploy demo site
    local demo_site="$TMP_DIR/demo-site/index.html"
    if [ -f "$demo_site" ]; then
        cp "$demo_site" "$deploy_dir/index.html"
        chmod 644 "$deploy_dir/index.html"
        log_ok "Demo site deployed"
    else
        log_warn "Demo site not found for deployment"
    fi

    chmod 755 "$deploy_dir"

    echo ""
    echo -e "  ${GREEN}🌐 Audit: https://acegrowth.net/demos/$slug/growth-audit.html${NC}"
    echo -e "  ${GREEN}🌐 Demo:  https://acegrowth.net/demos/$slug/${NC}"
}

# ──────────────────────────────────────
# Phase 5: Call Brief
# ──────────────────────────────────────

output_brief() {
    log_step "CALL BRIEF"

    local biz_name phone email address website slug overall_score
    biz_name=$(jq -r '.businessName // "Unknown"' "$RESEARCH_FILE" 2>/dev/null || echo "Unknown")
    phone=$(jq -r '.phone // "Not found"' "$RESEARCH_FILE" 2>/dev/null || echo "Not found")
    email=$(jq -r '.email // "Not found"' "$RESEARCH_FILE" 2>/dev/null || echo "Not found")
    address=$(jq -r '.address // "Not found"' "$RESEARCH_FILE" 2>/dev/null || echo "Not found")
    website=$(jq -r '.url // ""' "$RESEARCH_FILE" 2>/dev/null || echo "")
    slug=$(slugify "$biz_name")
    overall_score=$(jq -r '.overallScore // "?"' "$AUDIT_FILE" 2>/dev/null || echo "?")

    local issues
    issues=$(jq -r '[.categories[].issues[0]] | .[:3] | .[]' "$AUDIT_FILE" 2>/dev/null || echo "Issues analysis pending")

    local lost_leads annual_lost
    lost_leads=$(jq -r '.revenueImpact.lostLeadsPerMonth // "10-25"' "$AUDIT_FILE" 2>/dev/null || echo "10-25")
    annual_lost=$(jq -r '.revenueImpact.annualRevenueLost // "$100K+"' "$AUDIT_FILE" 2>/dev/null || echo '$100K+')

    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BOLD}♠️  PROSPECT READY: ${biz_name}${NC}"
    echo ""
    echo "📞 Phone: $phone"
    echo "📧 Email: $email"
    echo "📍 Address: $address"
    echo "🌐 Website: $website"
    echo "📊 Score: ${overall_score}/100"
    echo ""
    echo "🔍 AUDIT: https://acegrowth.net/demos/$slug/growth-audit.html"
    echo "🎨 DEMO:  https://acegrowth.net/demos/$slug/"
    echo ""
    echo "📋 KEY TALKING POINTS:"
    echo "$issues" | while IFS= read -r issue; do
        [ -n "$issue" ] && echo "  • $issue"
    done
    echo ""
    echo "💰 REVENUE IMPACT:"
    echo "  • Losing an estimated $lost_leads leads per month"
    echo "  • Potential annual revenue lost: $annual_lost"
    echo "  • Fixing these issues = more calls, more customers"
    echo ""
    echo -e "${BOLD}Ready to call. Go get it. ♠️${NC}"
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Save brief
    if [ -d "$DEPLOY_ROOT/$slug" ]; then
        cat > "$DEPLOY_ROOT/$slug/call-brief.txt" << BRIEF
♠️ PROSPECT READY: $biz_name

📞 Phone: $phone
📧 Email: $email
📍 Address: $address
🌐 Website: $website
📊 Score: ${overall_score}/100

🔍 AUDIT: https://acegrowth.net/demos/$slug/growth-audit.html
🎨 DEMO:  https://acegrowth.net/demos/$slug/

📋 KEY TALKING POINTS:
$(echo "$issues" | while IFS= read -r issue; do [ -n "$issue" ] && echo "  • $issue"; done)

💰 REVENUE IMPACT:
  • Losing an estimated $lost_leads leads per month
  • Potential annual revenue lost: $annual_lost

Ready to call. Go get it. ♠️
BRIEF
        chmod 644 "$DEPLOY_ROOT/$slug/call-brief.txt"
    fi
}

# ──────────────────────────────────────
# Main
# ──────────────────────────────────────

main() {
    echo ""
    echo -e "${BOLD}♠️  ACE GROWTH — PROSPECT PIPELINE${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    parse_input "$@"
    check_deps
    mkdir -p "$TMP_DIR"

    # Phase 1: Fetch
    if [ -n "$WEBSITE_URL" ]; then
        fetch_website "$WEBSITE_URL"
    else
        research_by_name "$BUSINESS_SEARCH_NAME" "$BUSINESS_CITY"
    fi

    # Analysis: research + audit JSON + site config (all in Python)
    run_analysis

    # Phase 2: Audit HTML
    if [ "$DEMO_ONLY" = false ]; then
        generate_audit_html
    fi

    # Phase 3: Demo site
    if [ "$AUDIT_ONLY" = false ]; then
        generate_demo_site
    fi

    # Phase 4: Deploy
    if [ "$DO_DEPLOY" = true ]; then
        deploy
    fi

    # Phase 5: Brief
    output_brief

    # Copy to /tmp for reference
    cp "$RESEARCH_FILE" /tmp/prospect-research.json 2>/dev/null || true
    cp "$AUDIT_FILE" /tmp/prospect-audit.json 2>/dev/null || true
}

main "$@"
