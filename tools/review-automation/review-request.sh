#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════
#  Ace Growth — Review Request System
#  Sends review requests via SMS (Twilio) and/or Email (SMTP)
#  
#  Usage:
#    ./review-request.sh --name "John Smith" \
#                        --phone "+13175551234" \
#                        --email "john@example.com" \
#                        --company "Pro Contractors Inc." \
#                        --review-link "https://g.page/r/xxx/review" \
#                        [--method sms|email|both] \
#                        [--schedule-followup]
#
#  © 2025 Ace Growth (acegrowth.net)
# ═══════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRACKER_CSV="${SCRIPT_DIR}/data/review-tracker.csv"
FOLLOWUP_DIR="${SCRIPT_DIR}/data/followups"
SMS_TEMPLATE="${SCRIPT_DIR}/templates/sms-template.txt"
EMAIL_TEMPLATE="${SCRIPT_DIR}/templates/email-template.html"
CONFIG_FILE="${SCRIPT_DIR}/config.env"

# ─── Colors for terminal output ───
RED='\033[0;31m'
GREEN='\033[0;32m'
GOLD='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ─── Load config if exists ───
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
fi

# ─── Default values (override in config.env) ───
TWILIO_SID="${TWILIO_SID:-}"
TWILIO_TOKEN="${TWILIO_TOKEN:-}"
TWILIO_FROM="${TWILIO_FROM:-}"
SMTP_HOST="${SMTP_HOST:-smtp.gmail.com}"
SMTP_PORT="${SMTP_PORT:-587}"
SMTP_USER="${SMTP_USER:-}"
SMTP_PASS="${SMTP_PASS:-}"
FROM_EMAIL="${FROM_EMAIL:-}"
FROM_NAME="${FROM_NAME:-Ace Growth}"
DEFAULT_COMPANY="${DEFAULT_COMPANY:-Our Company}"
DEFAULT_REVIEW_LINK="${DEFAULT_REVIEW_LINK:-}"

# ─── Parse arguments ───
NAME=""
PHONE=""
EMAIL=""
COMPANY="${DEFAULT_COMPANY}"
REVIEW_LINK="${DEFAULT_REVIEW_LINK}"
METHOD="both"
SCHEDULE_FOLLOWUP=false
JOB_ID=""

usage() {
  echo -e "${GOLD}═══════════════════════════════════════════${NC}"
  echo -e "${GOLD}  Ace Growth — Review Request System${NC}"
  echo -e "${GOLD}═══════════════════════════════════════════${NC}"
  echo ""
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Required:"
  echo "  --name NAME           Customer name"
  echo "  --review-link URL     Google review link"
  echo ""
  echo "Contact (at least one):"
  echo "  --phone PHONE         Phone number (E.164 format: +13175551234)"
  echo "  --email EMAIL         Email address"
  echo ""
  echo "Optional:"
  echo "  --company NAME        Company name (default: from config)"
  echo "  --method METHOD       sms, email, or both (default: both)"
  echo "  --schedule-followup   Schedule a 3-day follow-up reminder"
  echo "  --job-id ID           Job/invoice reference number"
  echo "  --help                Show this help"
  echo ""
  echo "Examples:"
  echo "  $0 --name 'John Smith' --phone '+13175551234' --review-link 'https://g.page/r/xxx/review'"
  echo "  $0 --name 'Jane Doe' --email 'jane@example.com' --method email --schedule-followup"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) NAME="$2"; shift 2;;
    --phone) PHONE="$2"; shift 2;;
    --email) EMAIL="$2"; shift 2;;
    --company) COMPANY="$2"; shift 2;;
    --review-link) REVIEW_LINK="$2"; shift 2;;
    --method) METHOD="$2"; shift 2;;
    --schedule-followup) SCHEDULE_FOLLOWUP=true; shift;;
    --job-id) JOB_ID="$2"; shift 2;;
    --help) usage;;
    *) echo -e "${RED}Unknown option: $1${NC}"; usage;;
  esac
done

# ─── Validate ───
if [[ -z "$NAME" ]]; then
  echo -e "${RED}Error: --name is required${NC}"
  exit 1
fi

if [[ -z "$PHONE" && -z "$EMAIL" ]]; then
  echo -e "${RED}Error: At least --phone or --email is required${NC}"
  exit 1
fi

if [[ -z "$REVIEW_LINK" ]]; then
  echo -e "${RED}Error: --review-link is required${NC}"
  exit 1
fi

# ─── Setup directories ───
mkdir -p "$(dirname "$TRACKER_CSV")" "$FOLLOWUP_DIR"

# Initialize CSV if it doesn't exist
if [[ ! -f "$TRACKER_CSV" ]]; then
  echo "id,timestamp,name,phone,email,company,review_link,method,status,followup_scheduled,followup_sent,job_id" > "$TRACKER_CSV"
fi

# ─── Generate request ID ───
REQUEST_ID="req_$(date +%s)_$(head -c 4 /dev/urandom | xxd -p)"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
FIRST_NAME=$(echo "$NAME" | awk '{print $1}')

echo -e "${GOLD}═══════════════════════════════════════════${NC}"
echo -e "${GOLD}  📋 Sending Review Request${NC}"
echo -e "${GOLD}═══════════════════════════════════════════${NC}"
echo -e "  Customer:  ${GREEN}${NAME}${NC}"
echo -e "  Company:   ${BLUE}${COMPANY}${NC}"
echo -e "  Method:    ${METHOD}"
echo -e "  Request:   ${REQUEST_ID}"
echo ""

# ─── Prepare SMS message ───
prepare_sms() {
  if [[ -f "$SMS_TEMPLATE" ]]; then
    sed -e "s/{{NAME}}/${FIRST_NAME}/g" \
        -e "s/{{FULL_NAME}}/${NAME}/g" \
        -e "s/{{COMPANY}}/${COMPANY}/g" \
        -e "s|{{REVIEW_LINK}}|${REVIEW_LINK}|g" \
        "$SMS_TEMPLATE"
  else
    echo "Hey ${FIRST_NAME}, thanks for choosing ${COMPANY}! If you loved the work, a Google review would mean the world to us: ${REVIEW_LINK}"
  fi
}

# ─── Prepare email HTML ───
prepare_email() {
  if [[ -f "$EMAIL_TEMPLATE" ]]; then
    sed -e "s/{{NAME}}/${FIRST_NAME}/g" \
        -e "s/{{FULL_NAME}}/${NAME}/g" \
        -e "s/{{COMPANY}}/${COMPANY}/g" \
        -e "s|{{REVIEW_LINK}}|${REVIEW_LINK}|g" \
        -e "s|{{PHONE}}|${TWILIO_FROM:-}|g" \
        "$EMAIL_TEMPLATE"
  else
    echo "<html><body><h1>Thanks, ${FIRST_NAME}!</h1><p>If you loved working with ${COMPANY}, please leave us a review!</p><a href='${REVIEW_LINK}'>Leave a Review</a></body></html>"
  fi
}

# ─── Send SMS via Twilio ───
send_sms() {
  local message
  message=$(prepare_sms)
  
  if [[ -z "$TWILIO_SID" || -z "$TWILIO_TOKEN" || -z "$TWILIO_FROM" ]]; then
    echo -e "${GOLD}  ⚠️  Twilio not configured — SMS preview:${NC}"
    echo -e "  ┌──────────────────────────────────────────"
    echo -e "  │ To: ${PHONE}"
    echo -e "  │ From: ${TWILIO_FROM:-[not set]}"
    echo -e "  │"
    echo "$message" | while IFS= read -r line; do
      echo -e "  │ ${line}"
    done
    echo -e "  └──────────────────────────────────────────"
    echo ""
    echo -e "  ${BLUE}To enable: Add TWILIO_SID, TWILIO_TOKEN, TWILIO_FROM to config.env${NC}"
    return 1
  fi

  local response
  response=$(curl -s -X POST "https://api.twilio.com/2010-04-01/Accounts/${TWILIO_SID}/Messages.json" \
    -u "${TWILIO_SID}:${TWILIO_TOKEN}" \
    --data-urlencode "Body=${message}" \
    --data-urlencode "From=${TWILIO_FROM}" \
    --data-urlencode "To=${PHONE}" 2>&1)
  
  if echo "$response" | grep -q '"sid"'; then
    local msg_sid
    msg_sid=$(echo "$response" | grep -o '"sid": *"[^"]*"' | head -1 | cut -d'"' -f4)
    echo -e "  ${GREEN}✅ SMS sent successfully!${NC} (SID: ${msg_sid})"
    return 0
  else
    echo -e "  ${RED}❌ SMS failed:${NC} $response"
    return 1
  fi
}

# ─── Send email via SMTP ───
send_email() {
  local html_body
  html_body=$(prepare_email)
  local subject="Thanks for choosing ${COMPANY}! 🏠"
  
  if [[ -z "$SMTP_USER" || -z "$SMTP_PASS" ]]; then
    echo -e "${GOLD}  ⚠️  SMTP not configured — Email preview:${NC}"
    echo -e "  ┌──────────────────────────────────────────"
    echo -e "  │ To: ${EMAIL}"
    echo -e "  │ From: ${FROM_NAME} <${FROM_EMAIL:-[not set]}>"
    echo -e "  │ Subject: ${subject}"
    echo -e "  │"
    echo -e "  │ [HTML email — see templates/email-template.html]"
    echo -e "  └──────────────────────────────────────────"
    echo ""
    echo -e "  ${BLUE}To enable: Add SMTP_USER, SMTP_PASS, FROM_EMAIL to config.env${NC}"
    return 1
  fi

  # Build email with boundaries for HTML
  local boundary="ace_$(date +%s)"
  local email_content="From: ${FROM_NAME} <${FROM_EMAIL}>
To: ${EMAIL}
Subject: ${subject}
MIME-Version: 1.0
Content-Type: multipart/alternative; boundary=\"${boundary}\"

--${boundary}
Content-Type: text/plain; charset=UTF-8

Hey ${FIRST_NAME}, thanks for choosing ${COMPANY}! If you loved the work, a Google review would mean the world to us: ${REVIEW_LINK}

--${boundary}
Content-Type: text/html; charset=UTF-8

${html_body}

--${boundary}--"

  # Send via curl SMTP
  echo "$email_content" | curl -s --url "smtp://${SMTP_HOST}:${SMTP_PORT}" \
    --ssl-reqd \
    --mail-from "${FROM_EMAIL}" \
    --mail-rcpt "${EMAIL}" \
    --upload-file - \
    --user "${SMTP_USER}:${SMTP_PASS}" 2>&1

  if [[ $? -eq 0 ]]; then
    echo -e "  ${GREEN}✅ Email sent successfully!${NC}"
    return 0
  else
    echo -e "  ${RED}❌ Email send failed${NC}"
    return 1
  fi
}

# ─── Execute based on method ───
SMS_STATUS="skipped"
EMAIL_STATUS="skipped"

if [[ "$METHOD" == "sms" || "$METHOD" == "both" ]]; then
  if [[ -n "$PHONE" ]]; then
    echo -e "${BLUE}📱 Sending SMS...${NC}"
    if send_sms; then
      SMS_STATUS="sent"
    else
      SMS_STATUS="preview"
    fi
    echo ""
  fi
fi

if [[ "$METHOD" == "email" || "$METHOD" == "both" ]]; then
  if [[ -n "$EMAIL" ]]; then
    echo -e "${BLUE}📧 Sending Email...${NC}"
    if send_email; then
      EMAIL_STATUS="sent"
    else
      EMAIL_STATUS="preview"
    fi
    echo ""
  fi
fi

# ─── Schedule follow-up ───
FOLLOWUP_SCHEDULED="no"
if [[ "$SCHEDULE_FOLLOWUP" == true ]]; then
  FOLLOWUP_DATE=$(date -d "+3 days" +"%Y-%m-%d" 2>/dev/null || date -v+3d +"%Y-%m-%d" 2>/dev/null || echo "")
  if [[ -n "$FOLLOWUP_DATE" ]]; then
    cat > "${FOLLOWUP_DIR}/${REQUEST_ID}.json" << EOF
{
  "request_id": "${REQUEST_ID}",
  "name": "${NAME}",
  "first_name": "${FIRST_NAME}",
  "phone": "${PHONE}",
  "email": "${EMAIL}",
  "company": "${COMPANY}",
  "review_link": "${REVIEW_LINK}",
  "method": "${METHOD}",
  "followup_date": "${FOLLOWUP_DATE}",
  "original_date": "${TIMESTAMP}",
  "status": "pending"
}
EOF
    FOLLOWUP_SCHEDULED="yes (${FOLLOWUP_DATE})"
    echo -e "${GREEN}📅 Follow-up scheduled for ${FOLLOWUP_DATE}${NC}"
  fi
fi

# ─── Log to tracker CSV ───
echo "${REQUEST_ID},${TIMESTAMP},\"${NAME}\",\"${PHONE}\",\"${EMAIL}\",\"${COMPANY}\",\"${REVIEW_LINK}\",${METHOD},sms:${SMS_STATUS}/email:${EMAIL_STATUS},${FOLLOWUP_SCHEDULED},no,\"${JOB_ID}\"" >> "$TRACKER_CSV"

# ─── Summary ───
echo ""
echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅ Review Request Complete${NC}"
echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo -e "  Request ID:  ${REQUEST_ID}"
echo -e "  SMS:         ${SMS_STATUS}"
echo -e "  Email:       ${EMAIL_STATUS}"
echo -e "  Follow-up:   ${FOLLOWUP_SCHEDULED}"
echo -e "  Logged to:   ${TRACKER_CSV}"
echo ""
