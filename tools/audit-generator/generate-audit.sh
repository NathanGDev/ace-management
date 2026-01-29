#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Ace Growth — Audit Generator
# Generates a beautiful HTML growth audit from a JSON input file
# Usage: ./generate-audit.sh <audit-data.json> [--deploy]
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/audit-template.html"
DEPLOY_ROOT="/var/www/acemanagement.so/demos"

# --- Helpers ---
usage() {
    echo "Usage: $0 <audit-data.json> [--deploy]"
    echo ""
    echo "Options:"
    echo "  --deploy    Auto-deploy to $DEPLOY_ROOT/<business-slug>/growth-audit.html"
    echo ""
    echo "Example:"
    echo "  $0 sample-audit.json"
    echo "  $0 sample-audit.json --deploy"
    exit 1
}

require_jq() {
    if ! command -v jq &>/dev/null; then
        echo "⚠️  jq not found. Installing..."
        apt-get install -y jq >/dev/null 2>&1
    fi
}

slugify() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//g'
}

# Score color: red < 40, yellow 40-69, green 70+
score_color() {
    local score=$1
    if [ "$score" -lt 40 ]; then
        echo "#ef4444"
    elif [ "$score" -lt 70 ]; then
        echo "#f59e0b"
    else
        echo "#22c55e"
    fi
}

# Score label
score_label() {
    local score=$1
    if [ "$score" -lt 25 ]; then
        echo "Critical — Immediate Action Needed"
    elif [ "$score" -lt 40 ]; then
        echo "Poor — Significant Issues Found"
    elif [ "$score" -lt 55 ]; then
        echo "Below Average — Room for Improvement"
    elif [ "$score" -lt 70 ]; then
        echo "Average — Some Gaps to Address"
    elif [ "$score" -lt 85 ]; then
        echo "Good — Minor Optimizations Needed"
    else
        echo "Excellent — Well Optimized"
    fi
}

score_subtitle() {
    local score=$1
    if [ "$score" -lt 40 ]; then
        echo "Your website is underperforming in key areas. You're likely losing leads to competitors with stronger online presence."
    elif [ "$score" -lt 70 ]; then
        echo "Your site has some strengths, but critical gaps are costing you leads. Targeted fixes can make a big difference."
    else
        echo "Your online presence is solid. A few strategic improvements could help you dominate your market."
    fi
}

# Category bar color class
bar_class() {
    local score=$1
    if [ "$score" -le 3 ]; then
        echo "bar-danger"
    elif [ "$score" -le 6 ]; then
        echo "bar-warning"
    else
        echo "bar-success"
    fi
}

# Category badge class
badge_class() {
    local score=$1
    if [ "$score" -le 3 ]; then
        echo "score-low"
    elif [ "$score" -le 6 ]; then
        echo "score-mid"
    else
        echo "score-high"
    fi
}

# --- Main ---
[ $# -lt 1 ] && usage
JSON_FILE="$1"
DEPLOY=false
[ "${2:-}" = "--deploy" ] && DEPLOY=true

[ ! -f "$JSON_FILE" ] && echo "❌ File not found: $JSON_FILE" && exit 1
[ ! -f "$TEMPLATE" ] && echo "❌ Template not found: $TEMPLATE" && exit 1

require_jq

echo "📊 Generating growth audit..."

# --- Read JSON ---
BUSINESS_NAME=$(jq -r '.businessName' "$JSON_FILE")
OWNER_NAME=$(jq -r '.ownerName' "$JSON_FILE")
WEBSITE=$(jq -r '.website' "$JSON_FILE")
AUDIT_DATE=$(jq -r '.date' "$JSON_FILE")
AVG_JOB_VALUE=$(jq -r '.avgJobValue' "$JSON_FILE")
OVERALL_SCORE=$(jq -r '.overallScore' "$JSON_FILE")
EXEC_SUMMARY=$(jq -r '.executiveSummary // "We conducted a comprehensive audit of your website, online presence, and lead generation systems. Several critical issues were identified that are likely costing you qualified leads every month."' "$JSON_FILE")

# Revenue impact
CURRENT_CONV=$(jq -r '.revenueImpact.currentConversion // "under 1%"' "$JSON_FILE")
POTENTIAL_CONV=$(jq -r '.revenueImpact.potentialConversion // "5-8%"' "$JSON_FILE")
LOST_LEADS=$(jq -r '.revenueImpact.lostLeadsPerMonth // "10-20"' "$JSON_FILE")
ANNUAL_LOST=$(jq -r '.revenueImpact.annualRevenueLost // "$100K+"' "$JSON_FILE")

# --- Calculate score visuals ---
SCORE_COLOR=$(score_color "$OVERALL_SCORE")
SCORE_LABEL=$(score_label "$OVERALL_SCORE")
SCORE_SUBTITLE=$(score_subtitle "$OVERALL_SCORE")

# SVG circle: circumference = 2 * π * 90 ≈ 565.48
# dashoffset = circumference * (1 - score/100)
CIRCUMFERENCE="565.48"
DASH_OFFSET=$(echo "scale=2; $CIRCUMFERENCE * (1 - $OVERALL_SCORE / 100)" | bc)

# --- Build categories HTML ---
CATEGORIES_HTML=""
NUM_CATEGORIES=$(jq '.categories | length' "$JSON_FILE")

for i in $(seq 0 $(( NUM_CATEGORIES - 1 ))); do
    CAT_NAME=$(jq -r ".categories[$i].name" "$JSON_FILE")
    CAT_ICON=$(jq -r ".categories[$i].icon // \"📋\"" "$JSON_FILE")
    CAT_SCORE=$(jq -r ".categories[$i].score" "$JSON_FILE")
    CAT_MAX=$(jq -r ".categories[$i].maxScore" "$JSON_FILE")
    CAT_BENCHMARK=$(jq -r ".categories[$i].benchmark" "$JSON_FILE")
    
    FILL_PCT=$(( CAT_SCORE * 100 / CAT_MAX ))
    BAR_CLS=$(bar_class "$CAT_SCORE")
    BADGE_CLS=$(badge_class "$CAT_SCORE")
    
    # Build issues HTML
    ISSUES_HTML=""
    NUM_ISSUES=$(jq ".categories[$i].issues | length" "$JSON_FILE")
    for j in $(seq 0 $(( NUM_ISSUES - 1 ))); do
        ISSUE=$(jq -r ".categories[$i].issues[$j]" "$JSON_FILE")
        ISSUES_HTML+="                    <li>${ISSUE}</li>
"
    done

    CATEGORIES_HTML+="
            <div class=\"category\">
                <div class=\"category-header\">
                    <div class=\"category-name\">
                        <div class=\"category-icon\">${CAT_ICON}</div>
                        <div class=\"category-title\">${CAT_NAME}</div>
                    </div>
                    <div class=\"category-score-badge ${BADGE_CLS}\">${CAT_SCORE}/${CAT_MAX}</div>
                </div>
                <div class=\"category-bar-container\">
                    <div class=\"category-bar-fill ${BAR_CLS}\" style=\"--fill-width: ${FILL_PCT}%\"></div>
                </div>
                <ul class=\"category-issues\">
${ISSUES_HTML}                </ul>
                <div class=\"category-benchmark\">
                    <strong>What good looks like:</strong> ${CAT_BENCHMARK}
                </div>
            </div>
"
done

# --- Build competitors HTML ---
COMPETITORS_HTML=""
NUM_COMP=$(jq '.competitors | length' "$JSON_FILE")

for i in $(seq 0 $(( NUM_COMP - 1 ))); do
    COMP=$(jq -r ".competitors[$i]" "$JSON_FILE")
    COMPETITORS_HTML+="
            <div class=\"competitor-item\">
                <div class=\"competitor-icon\">⚠️</div>
                <div class=\"competitor-text\">${COMP}</div>
            </div>
"
done

# --- Build recommendations HTML ---
RECS_HTML=""
NUM_RECS=$(jq '.recommendations | length' "$JSON_FILE")

for i in $(seq 0 $(( NUM_RECS - 1 ))); do
    REC=$(jq -r ".recommendations[$i]" "$JSON_FILE")
    # First 2 are high priority, next 2 medium, rest normal
    if [ "$i" -lt 2 ]; then
        PRIORITY_HTML="<span class=\"rec-priority priority-high\">High Impact</span>"
    elif [ "$i" -lt 4 ]; then
        PRIORITY_HTML="<span class=\"rec-priority priority-medium\">Medium Impact</span>"
    else
        PRIORITY_HTML=""
    fi
    
    RECS_HTML+="
                <li class=\"recommendation-item\">
                    <div class=\"rec-number\"></div>
                    <div class=\"rec-content\">${REC} ${PRIORITY_HTML}</div>
                </li>
"
done

# --- Read template and replace placeholders ---
OUTPUT=$(cat "$TEMPLATE")

# Simple replacements
OUTPUT="${OUTPUT//\{\{BUSINESS_NAME\}\}/$BUSINESS_NAME}"
OUTPUT="${OUTPUT//\{\{AUDIT_DATE\}\}/$AUDIT_DATE}"
OUTPUT="${OUTPUT//\{\{OVERALL_SCORE\}\}/$OVERALL_SCORE}"
OUTPUT="${OUTPUT//\{\{SCORE_COLOR\}\}/$SCORE_COLOR}"
OUTPUT="${OUTPUT//\{\{SCORE_LABEL\}\}/$SCORE_LABEL}"
OUTPUT="${OUTPUT//\{\{SCORE_SUBTITLE\}\}/$SCORE_SUBTITLE}"
OUTPUT="${OUTPUT//\{\{SCORE_DASH_OFFSET\}\}/$DASH_OFFSET}"
OUTPUT="${OUTPUT//\{\{EXECUTIVE_SUMMARY\}\}/$EXEC_SUMMARY}"
OUTPUT="${OUTPUT//\{\{CURRENT_CONVERSION\}\}/$CURRENT_CONV}"
OUTPUT="${OUTPUT//\{\{POTENTIAL_CONVERSION\}\}/$POTENTIAL_CONV}"
OUTPUT="${OUTPUT//\{\{LOST_LEADS\}\}/$LOST_LEADS}"
OUTPUT="${OUTPUT//\{\{AVG_JOB_VALUE\}\}/$AVG_JOB_VALUE}"
OUTPUT="${OUTPUT//\{\{ANNUAL_REVENUE_LOST\}\}/$ANNUAL_LOST}"

# Multi-line replacements via temp files
TMPFILE=$(mktemp)
echo "$OUTPUT" > "$TMPFILE"

# Replace block placeholders using awk for multi-line content
python3 -c "
import sys

with open('$TMPFILE', 'r') as f:
    content = f.read()

categories = '''$CATEGORIES_HTML'''
competitors = '''$COMPETITORS_HTML'''
recommendations = '''$RECS_HTML'''

content = content.replace('{{CATEGORIES_HTML}}', categories)
content = content.replace('{{COMPETITORS_HTML}}', competitors)
content = content.replace('{{RECOMMENDATIONS_HTML}}', recommendations)

with open('$TMPFILE', 'w') as f:
    f.write(content)
"

# --- Output ---
SLUG=$(slugify "$BUSINESS_NAME")
OUTPUT_DIR="$SCRIPT_DIR/output"
mkdir -p "$OUTPUT_DIR"
OUTPUT_FILE="$OUTPUT_DIR/${SLUG}-growth-audit.html"
cp "$TMPFILE" "$OUTPUT_FILE"
rm "$TMPFILE"

echo "✅ Audit generated: $OUTPUT_FILE"

# --- Deploy ---
if [ "$DEPLOY" = true ]; then
    DEPLOY_DIR="$DEPLOY_ROOT/$SLUG"
    mkdir -p "$DEPLOY_DIR"
    cp "$OUTPUT_FILE" "$DEPLOY_DIR/growth-audit.html"
    echo "🚀 Deployed to: $DEPLOY_DIR/growth-audit.html"
    echo "🌐 URL: https://acemanagement.so/demos/$SLUG/growth-audit.html"
fi

echo ""
echo "📋 Audit Summary:"
echo "   Business: $BUSINESS_NAME"
echo "   Score: $OVERALL_SCORE/100"
echo "   Status: $SCORE_LABEL"
echo ""
