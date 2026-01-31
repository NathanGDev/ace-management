#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════
#  Ace Growth — Review Request Tracker
#  View, search, and manage review requests
#  
#  Usage:
#    ./tracker.sh list                    — Show all requests
#    ./tracker.sh list --pending          — Show pending follow-ups
#    ./tracker.sh stats                   — Summary statistics
#    ./tracker.sh search "John"           — Search by name
#    ./tracker.sh followup                — Process due follow-ups
#    ./tracker.sh mark-reviewed REQ_ID    — Mark as reviewed
#
#  © 2025 Ace Growth (acegrowth.net)
# ═══════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRACKER_CSV="${SCRIPT_DIR}/data/review-tracker.csv"
FOLLOWUP_DIR="${SCRIPT_DIR}/data/followups"

# ─── Colors ───
RED='\033[0;31m'
GREEN='\033[0;32m'
GOLD='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Check if tracker exists ───
check_tracker() {
  if [[ ! -f "$TRACKER_CSV" ]]; then
    echo -e "${GOLD}No review requests yet.${NC}"
    echo "Run review-request.sh to create your first request."
    exit 0
  fi
}

# ─── List all requests ───
list_requests() {
  check_tracker
  
  local filter="${1:-all}"
  
  echo -e "${GOLD}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${GOLD}  📋 Review Requests${NC}"
  echo -e "${GOLD}═══════════════════════════════════════════════════════════════${NC}"
  echo ""
  
  local count=0
  
  # Skip header, read each line
  tail -n +2 "$TRACKER_CSV" | while IFS=',' read -r id timestamp name phone email company review_link method status followup followup_sent job_id; do
    # Remove quotes
    name=$(echo "$name" | tr -d '"')
    phone=$(echo "$phone" | tr -d '"')
    email=$(echo "$email" | tr -d '"')
    company=$(echo "$company" | tr -d '"')
    job_id=$(echo "$job_id" | tr -d '"')
    
    if [[ "$filter" == "pending" ]]; then
      if [[ "$followup" == "no" ]] || [[ "$followup_sent" == "yes" ]]; then
        continue
      fi
    fi
    
    count=$((count + 1))
    
    # Format timestamp
    local date_part="${timestamp:0:10}"
    local time_part="${timestamp:11:5}"
    
    echo -e "  ${BOLD}${name}${NC}  ${CYAN}${date_part} ${time_part}${NC}"
    echo -e "  │ Phone: ${phone:-n/a}  |  Email: ${email:-n/a}"
    echo -e "  │ Company: ${company}  |  Method: ${method}"
    echo -e "  │ Status: ${status}"
    [[ -n "$job_id" ]] && echo -e "  │ Job: ${job_id}"
    echo -e "  │ Follow-up: ${followup}  |  Follow-up Sent: ${followup_sent}"
    echo -e "  │ ID: ${id}"
    echo -e "  └─────────────────────────────────────────"
    echo ""
  done
  
  # Count total
  local total=$(($(wc -l < "$TRACKER_CSV") - 1))
  echo -e "  ${BLUE}Total: ${total} request(s)${NC}"
}

# ─── Statistics ───
show_stats() {
  check_tracker
  
  local total=$(($(wc -l < "$TRACKER_CSV") - 1))
  local sms_sent=$(grep -c "sms:sent" "$TRACKER_CSV" 2>/dev/null || echo "0")
  local email_sent=$(grep -c "email:sent" "$TRACKER_CSV" 2>/dev/null || echo "0")
  local pending_followups=0
  
  if [[ -d "$FOLLOWUP_DIR" ]]; then
    pending_followups=$(find "$FOLLOWUP_DIR" -name "*.json" -exec grep -l '"status": "pending"' {} \; 2>/dev/null | wc -l || echo "0")
  fi
  
  # Unique companies
  local companies=$(tail -n +2 "$TRACKER_CSV" | cut -d',' -f6 | sort -u | wc -l)
  
  echo -e "${GOLD}═══════════════════════════════════════════${NC}"
  echo -e "${GOLD}  📊 Review Request Statistics${NC}"
  echo -e "${GOLD}═══════════════════════════════════════════${NC}"
  echo ""
  echo -e "  Total Requests:      ${BOLD}${total}${NC}"
  echo -e "  SMS Sent:            ${GREEN}${sms_sent}${NC}"
  echo -e "  Emails Sent:         ${GREEN}${email_sent}${NC}"
  echo -e "  Pending Follow-ups:  ${GOLD}${pending_followups}${NC}"
  echo -e "  Companies:           ${BLUE}${companies}${NC}"
  echo ""
  
  # Last 7 days activity
  local week_ago
  week_ago=$(date -d "-7 days" +"%Y-%m-%d" 2>/dev/null || date -v-7d +"%Y-%m-%d" 2>/dev/null || echo "")
  if [[ -n "$week_ago" ]]; then
    local this_week=$(tail -n +2 "$TRACKER_CSV" | awk -F',' -v d="$week_ago" '$2 >= d' | wc -l)
    echo -e "  Last 7 Days:         ${CYAN}${this_week} request(s)${NC}"
  fi
  echo ""
}

# ─── Search ───
search_requests() {
  check_tracker
  local query="$1"
  
  echo -e "${GOLD}  🔍 Search: \"${query}\"${NC}"
  echo ""
  
  local results
  results=$(grep -i "$query" "$TRACKER_CSV" | grep -v "^id," || true)
  
  if [[ -z "$results" ]]; then
    echo -e "  ${RED}No results found.${NC}"
    return
  fi
  
  echo "$results" | while IFS=',' read -r id timestamp name phone email company review_link method status followup followup_sent job_id; do
    name=$(echo "$name" | tr -d '"')
    phone=$(echo "$phone" | tr -d '"')
    email=$(echo "$email" | tr -d '"')
    company=$(echo "$company" | tr -d '"')
    
    echo -e "  ${BOLD}${name}${NC} — ${company}"
    echo -e "  │ ${phone:-n/a} | ${email:-n/a} | ${status}"
    echo -e "  │ ${id} — ${timestamp:0:10}"
    echo ""
  done
}

# ─── Process follow-ups ───
process_followups() {
  if [[ ! -d "$FOLLOWUP_DIR" ]]; then
    echo -e "${GOLD}No follow-ups directory found.${NC}"
    return
  fi
  
  local today
  today=$(date +"%Y-%m-%d")
  local processed=0
  
  echo -e "${GOLD}═══════════════════════════════════════════${NC}"
  echo -e "${GOLD}  📅 Processing Follow-ups (${today})${NC}"
  echo -e "${GOLD}═══════════════════════════════════════════${NC}"
  echo ""
  
  for file in "${FOLLOWUP_DIR}"/*.json; do
    [[ -f "$file" ]] || continue
    
    local status followup_date name phone email company review_link method
    status=$(grep '"status"' "$file" | cut -d'"' -f4)
    
    [[ "$status" != "pending" ]] && continue
    
    followup_date=$(grep '"followup_date"' "$file" | cut -d'"' -f4)
    
    if [[ "$followup_date" <= "$today" ]]; then
      name=$(grep '"name"' "$file" | cut -d'"' -f4)
      first_name=$(grep '"first_name"' "$file" | cut -d'"' -f4)
      phone=$(grep '"phone"' "$file" | cut -d'"' -f4)
      email=$(grep '"email"' "$file" | cut -d'"' -f4)
      company=$(grep '"company"' "$file" | cut -d'"' -f4)
      review_link=$(grep '"review_link"' "$file" | cut -d'"' -f4)
      method=$(grep '"method"' "$file" | cut -d'"' -f4)
      
      echo -e "  ${GOLD}⏰ Due: ${name} (${company})${NC}"
      echo -e "  │ Scheduled: ${followup_date}"
      echo ""
      
      # Re-send with follow-up messaging
      echo -e "  ${BLUE}Triggering follow-up...${NC}"
      "${SCRIPT_DIR}/review-request.sh" \
        --name "$name" \
        ${phone:+--phone "$phone"} \
        ${email:+--email "$email"} \
        --company "$company" \
        --review-link "$review_link" \
        --method "$method" 2>/dev/null || true
      
      # Mark as sent
      sed -i 's/"status": "pending"/"status": "sent"/' "$file"
      processed=$((processed + 1))
      echo ""
    fi
  done
  
  if [[ $processed -eq 0 ]]; then
    echo -e "  ${GREEN}No follow-ups due today.${NC}"
  else
    echo -e "  ${GREEN}Processed ${processed} follow-up(s).${NC}"
  fi
  echo ""
}

# ─── Mark as reviewed ───
mark_reviewed() {
  local req_id="$1"
  
  if [[ -f "${FOLLOWUP_DIR}/${req_id}.json" ]]; then
    sed -i 's/"status": "pending"/"status": "reviewed"/' "${FOLLOWUP_DIR}/${req_id}.json"
    echo -e "${GREEN}✅ Marked ${req_id} as reviewed${NC}"
  else
    echo -e "${RED}Request ID not found: ${req_id}${NC}"
  fi
}

# ─── Main ───
case "${1:-help}" in
  list)
    list_requests "${2:-all}"
    ;;
  stats)
    show_stats
    ;;
  search)
    if [[ -z "${2:-}" ]]; then
      echo -e "${RED}Usage: $0 search QUERY${NC}"
      exit 1
    fi
    search_requests "$2"
    ;;
  followup|followups)
    process_followups
    ;;
  mark-reviewed|reviewed)
    if [[ -z "${2:-}" ]]; then
      echo -e "${RED}Usage: $0 mark-reviewed REQUEST_ID${NC}"
      exit 1
    fi
    mark_reviewed "$2"
    ;;
  help|*)
    echo -e "${GOLD}═══════════════════════════════════════════${NC}"
    echo -e "${GOLD}  Ace Growth — Review Tracker${NC}"
    echo -e "${GOLD}═══════════════════════════════════════════${NC}"
    echo ""
    echo "Commands:"
    echo "  list                  Show all review requests"
    echo "  list --pending        Show only pending follow-ups"
    echo "  stats                 Summary statistics"
    echo "  search QUERY          Search requests by name/company"
    echo "  followup              Process due follow-up reminders"
    echo "  mark-reviewed ID      Mark a request as reviewed"
    echo "  help                  Show this help"
    echo ""
    ;;
esac
