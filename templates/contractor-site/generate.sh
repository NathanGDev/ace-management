#!/usr/bin/env bash
#
# generate.sh — Contractor Website Generator
# Produces a customized, ready-to-deploy index.html from config.json + template.
#
# Usage:
#   ./generate.sh <config.json> <output-directory>
#
# Example:
#   ./generate.sh config.json /var/www/acemanagement.so/clients/sample-remodeling/
#
# Requirements: jq, sed, bash 4+
#

set -euo pipefail

# ──────────────────────────────────────
# Validate arguments
# ──────────────────────────────────────
if [ $# -lt 2 ]; then
    echo "Usage: $0 <config.json> <output-directory>"
    echo ""
    echo "Example:"
    echo "  $0 config.json /var/www/acemanagement.so/clients/acme-remodeling/"
    exit 1
fi

CONFIG="$1"
OUTPUT_DIR="$2"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE="$SCRIPT_DIR/index.html"

if [ ! -f "$CONFIG" ]; then
    echo "Error: Config file not found: $CONFIG"
    exit 1
fi

if [ ! -f "$TEMPLATE" ]; then
    echo "Error: Template not found: $TEMPLATE"
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "Error: jq is required but not installed."
    echo "  Install: apt-get install jq  OR  brew install jq"
    exit 1
fi

echo "🏗️  Contractor Site Generator"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Config:   $CONFIG"
echo "Output:   $OUTPUT_DIR"
echo ""

# ──────────────────────────────────────
# Read config values
# ──────────────────────────────────────
BUSINESS_NAME=$(jq -r '.businessName // "Business Name"' "$CONFIG")
TAGLINE=$(jq -r '.tagline // "Your Trusted Local Contractor"' "$CONFIG")
PHONE=$(jq -r '.phone // "(555) 000-0000"' "$CONFIG")
PHONE_RAW=$(echo "$PHONE" | tr -d '() -')
EMAIL=$(jq -r '.email // "info@example.com"' "$CONFIG")
WEBSITE=$(jq -r '.website // ""' "$CONFIG")
ADDRESS=$(jq -r '.address // "123 Main St"' "$CONFIG")
HOURS=$(jq -r '.hours // "Mon-Fri 8AM-5PM"' "$CONFIG")
YEARS=$(jq -r '.yearsInBusiness // "10"' "$CONFIG")
PROJECTS=$(jq -r '.projectsCompleted // "100+"' "$CONFIG")
REVIEWS=$(jq -r '.reviewCount // "50+"' "$CONFIG")
LICENSE=$(jq -r '.licenseNumber // "LIC-00000"' "$CONFIG")
COLOR_PRIMARY=$(jq -r '.colors.primary // "#1a2332"' "$CONFIG")
COLOR_ACCENT=$(jq -r '.colors.accent // "#ff6b35"' "$CONFIG")
COLOR_LIGHT=$(jq -r '.colors.light // "#f8f9fa"' "$CONFIG")
FORM_ACTION=$(jq -r '.formAction // "#"' "$CONFIG")
MAP_EMBED=$(jq -r '.mapEmbed // ""' "$CONFIG")

echo "📋 Business: $BUSINESS_NAME"
echo "📞 Phone:    $PHONE"
echo "🎨 Colors:   $COLOR_PRIMARY / $COLOR_ACCENT"
echo ""

# ──────────────────────────────────────
# SVG Icon library
# ──────────────────────────────────────
get_icon() {
    local icon_name="$1"
    case "$icon_name" in
        kitchen)
            echo '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="6" y="14" width="36" height="26" rx="2"/><line x1="6" y1="24" x2="42" y2="24"/><circle cx="16" cy="32" r="3"/><circle cx="32" cy="32" r="3"/><rect x="14" y="16" width="8" height="6" rx="1"/><rect x="26" y="16" width="8" height="6" rx="1"/><line x1="24" y1="8" x2="24" y2="14"/><line x1="20" y1="10" x2="20" y2="14"/><line x1="28" y1="10" x2="28" y2="14"/></svg>'
            ;;
        bathroom)
            echo '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M8 24h32v8c0 4.4-3.6 8-8 8H16c-4.4 0-8-3.6-8-8v-8z"/><path d="M12 24V14c0-2.2 1.8-4 4-4h2c2.2 0 4 1.8 4 4v2"/><line x1="12" y1="40" x2="10" y2="44"/><line x1="36" y1="40" x2="38" y2="44"/><circle cx="20" cy="7" r="1.5" fill="currentColor"/></svg>'
            ;;
        basement)
            echo '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 20L24 8l18 12"/><rect x="10" y="20" width="28" height="22" rx="1"/><line x1="10" y1="32" x2="38" y2="32"/><rect x="18" y="34" width="12" height="8" rx="1"/><line x1="24" y1="34" x2="24" y2="42"/><line x1="14" y1="24" x2="14" y2="30"/><line x1="18" y1="22" x2="18" y2="30"/></svg>'
            ;;
        painting)
            echo '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="8" y="8" width="26" height="14" rx="2"/><path d="M34 15h4a2 2 0 0 1 2 2v0a2 2 0 0 1-2 2h-4"/><line x1="22" y1="22" x2="22" y2="30"/><rect x="19" y="30" width="6" height="12" rx="2"/></svg>'
            ;;
        flooring)
            echo '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="6" y="6" width="36" height="36" rx="2"/><line x1="6" y1="18" x2="42" y2="18"/><line x1="6" y1="30" x2="42" y2="30"/><line x1="22" y1="6" x2="22" y2="18"/><line x1="14" y1="18" x2="14" y2="30"/><line x1="30" y1="18" x2="30" y2="30"/><line x1="22" y1="30" x2="22" y2="42"/></svg>'
            ;;
        deck)
            echo '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 22l20-10 20 10"/><rect x="8" y="22" width="32" height="4" rx="1"/><line x1="10" y1="26" x2="10" y2="40"/><line x1="24" y1="26" x2="24" y2="40"/><line x1="38" y1="26" x2="38" y2="40"/><line x1="8" y1="32" x2="40" y2="32"/><line x1="8" y1="38" x2="40" y2="38"/></svg>'
            ;;
        roofing)
            echo '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 24L24 8l20 16"/><path d="M10 22v18h28V22"/><line x1="4" y1="24" x2="44" y2="24"/><line x1="8" y1="18" x2="40" y2="18"/><line x1="14" y1="14" x2="34" y2="14"/></svg>'
            ;;
        windows)
            echo '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="8" y="8" width="32" height="32" rx="2"/><line x1="24" y1="8" x2="24" y2="40"/><line x1="8" y1="24" x2="40" y2="24"/><rect x="10" y="10" width="12" height="12" rx="1"/></svg>'
            ;;
        doors)
            echo '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="12" y="6" width="24" height="36" rx="2"/><circle cx="30" cy="26" r="2"/><path d="M12 42h24"/><line x1="8" y1="42" x2="40" y2="42"/></svg>'
            ;;
        siding)
            echo '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 22L24 8l20 14"/><rect x="8" y="22" width="32" height="20" rx="1"/><line x1="8" y1="28" x2="40" y2="28"/><line x1="8" y1="34" x2="40" y2="34"/><rect x="18" y="34" width="12" height="8"/></svg>'
            ;;
        addition)
            echo '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 24L18 12l14 12"/><rect x="8" y="24" width="20" height="16" rx="1"/><rect x="14" y="30" width="8" height="10"/><line x1="36" y1="20" x2="36" y2="32"/><line x1="30" y1="26" x2="42" y2="26"/></svg>'
            ;;
        plumbing)
            echo '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8v8h12V8"/><rect x="14" y="16" width="20" height="6" rx="2"/><path d="M20 22v6c0 6-8 8-8 14"/><path d="M28 22v6c0 6 8 8 8 14"/><line x1="8" y1="42" x2="16" y2="42"/><line x1="32" y1="42" x2="40" y2="42"/></svg>'
            ;;
        electrical)
            echo '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M28 4L14 26h10L16 44l18-24H24L28 4z" fill="currentColor" opacity="0.15"/><path d="M28 4L14 26h10L16 44l18-24H24L28 4z"/></svg>'
            ;;
        *)
            # Default: wrench/hammer general icon
            echo '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 34l-6 6a2.8 2.8 0 0 0 4 4l6-6"/><path d="M18 30l12-12"/><path d="M30 6l-4 4 10 10 4-4a8 8 0 0 0-10-10z"/><path d="M12 28L6.3 33.7a2 2 0 0 0 0 2.8l5.2 5.2a2 2 0 0 0 2.8 0L20 36"/></svg>'
            ;;
    esac
}

# ──────────────────────────────────────
# Build services HTML
# ──────────────────────────────────────
echo "🔨 Building services..."
SERVICES_HTML=""
SERVICE_OPTIONS_HTML=""
SERVICE_COUNT=$(jq '.services | length' "$CONFIG")

for i in $(seq 0 $((SERVICE_COUNT - 1))); do
    NAME=$(jq -r ".services[$i].name" "$CONFIG")
    DESC=$(jq -r ".services[$i].description" "$CONFIG")
    ICON_NAME=$(jq -r ".services[$i].icon // \"general\"" "$CONFIG")
    ICON_SVG=$(get_icon "$ICON_NAME")

    SERVICES_HTML+="
                <div class=\"service-card reveal\">
                    <div class=\"service-icon\">
                        ${ICON_SVG}
                    </div>
                    <h3>${NAME}</h3>
                    <p>${DESC}</p>
                </div>"

    SERVICE_OPTIONS_HTML+="
                            <option value=\"${NAME}\">${NAME}</option>"
done

# ──────────────────────────────────────
# Build testimonials HTML
# ──────────────────────────────────────
echo "⭐ Building testimonials..."
TESTIMONIALS_HTML=""
TESTIMONIAL_COUNT=$(jq '.testimonials | length' "$CONFIG")

STAR_SVG='<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/></svg>'
GOOGLE_SVG='<svg viewBox="0 0 24 24" width="14" height="14"><path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z"/><path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/><path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/><path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/></svg>'

for i in $(seq 0 $((TESTIMONIAL_COUNT - 1))); do
    T_NAME=$(jq -r ".testimonials[$i].name" "$CONFIG")
    T_TEXT=$(jq -r ".testimonials[$i].text" "$CONFIG")
    T_RATING=$(jq -r ".testimonials[$i].rating // 5" "$CONFIG")
    T_DATE=$(jq -r ".testimonials[$i].date // \"Recently\"" "$CONFIG")
    T_PROJECT=$(jq -r ".testimonials[$i].project // \"\"" "$CONFIG")

    # Generate initials for avatar
    INITIALS=$(echo "$T_NAME" | sed 's/\([A-Za-z]\)[^ ]*/\1/g' | tr -d ' .' | head -c 2 | tr '[:lower:]' '[:upper:]')

    # Build star rating
    STARS_HTML=""
    for s in $(seq 1 "$T_RATING"); do
        STARS_HTML+="$STAR_SVG"
    done

    # Project tag
    PROJECT_TAG=""
    if [ -n "$T_PROJECT" ] && [ "$T_PROJECT" != "" ] && [ "$T_PROJECT" != "null" ]; then
        PROJECT_TAG=" · ${T_PROJECT}"
    fi

    TESTIMONIALS_HTML+="
                <div class=\"testimonial-card reveal\">
                    <div class=\"testimonial-stars\">
                        ${STARS_HTML}
                    </div>
                    <p class=\"testimonial-text\">\"${T_TEXT}\"</p>
                    <div class=\"testimonial-author\">
                        <div class=\"testimonial-avatar\">${INITIALS}</div>
                        <div class=\"testimonial-meta\">
                            <h4>${T_NAME}</h4>
                            <p>${T_DATE}${PROJECT_TAG}</p>
                            <div class=\"testimonial-badge\">
                                ${GOOGLE_SVG}
                                <span>Google Review</span>
                            </div>
                        </div>
                    </div>
                </div>"
done

# ──────────────────────────────────────
# Build service areas HTML
# ──────────────────────────────────────
echo "📍 Building service areas..."
SERVICE_AREAS_HTML=""
AREA_COUNT=$(jq '.serviceAreas | length' "$CONFIG")
MAP_PIN='<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z"/><circle cx="12" cy="10" r="3"/></svg>'

for i in $(seq 0 $((AREA_COUNT - 1))); do
    AREA=$(jq -r ".serviceAreas[$i]" "$CONFIG")
    SERVICE_AREAS_HTML+="
                <div class=\"area-tag\">${MAP_PIN} ${AREA}</div>"
done

# ──────────────────────────────────────
# Generate the output file
# ──────────────────────────────────────
echo ""
echo "📄 Generating site..."

mkdir -p "$OUTPUT_DIR"

# Start with template
cp "$TEMPLATE" "$OUTPUT_DIR/index.html"

OUTPUT="$OUTPUT_DIR/index.html"

# Replace scalar placeholders
# Using | as sed delimiter since URLs contain /
sed -i "s|{{BUSINESS_NAME}}|${BUSINESS_NAME}|g" "$OUTPUT"
sed -i "s|{{TAGLINE}}|${TAGLINE}|g" "$OUTPUT"
sed -i "s|{{PHONE}}|${PHONE}|g" "$OUTPUT"
sed -i "s|{{PHONE_RAW}}|${PHONE_RAW}|g" "$OUTPUT"
sed -i "s|{{EMAIL}}|${EMAIL}|g" "$OUTPUT"
sed -i "s|{{WEBSITE}}|${WEBSITE}|g" "$OUTPUT"
sed -i "s|{{ADDRESS}}|${ADDRESS}|g" "$OUTPUT"
sed -i "s|{{HOURS}}|${HOURS}|g" "$OUTPUT"
sed -i "s|{{YEARS_IN_BUSINESS}}|${YEARS}|g" "$OUTPUT"
sed -i "s|{{PROJECTS_COMPLETED}}|${PROJECTS}|g" "$OUTPUT"
sed -i "s|{{REVIEW_COUNT}}|${REVIEWS}|g" "$OUTPUT"
sed -i "s|{{LICENSE_NUMBER}}|${LICENSE}|g" "$OUTPUT"
sed -i "s|{{COLOR_PRIMARY}}|${COLOR_PRIMARY}|g" "$OUTPUT"
sed -i "s|{{COLOR_ACCENT}}|${COLOR_ACCENT}|g" "$OUTPUT"
sed -i "s|{{COLOR_LIGHT}}|${COLOR_LIGHT}|g" "$OUTPUT"
sed -i "s|{{FORM_ACTION}}|${FORM_ACTION}|g" "$OUTPUT"
sed -i "s|{{MAP_EMBED}}|${MAP_EMBED}|g" "$OUTPUT"

# Replace dynamic sections using Python for multi-line content
python3 -c "
import sys

with open('$OUTPUT', 'r') as f:
    content = f.read()

# Replace dynamic sections
services_html = '''$SERVICES_HTML'''
options_html = '''$SERVICE_OPTIONS_HTML'''
testimonials_html = '''$TESTIMONIALS_HTML'''
areas_html = '''$SERVICE_AREAS_HTML'''

# Services
import re
content = re.sub(
    r'<!-- DYNAMIC:SERVICES -->.*?<!-- /DYNAMIC:SERVICES -->',
    '<!-- DYNAMIC:SERVICES -->' + services_html + '\n                <!-- /DYNAMIC:SERVICES -->',
    content, flags=re.DOTALL
)

# Service options (both hero and contact forms)
content = re.sub(
    r'<!-- DYNAMIC:SERVICE_OPTIONS -->.*?<!-- /DYNAMIC:SERVICE_OPTIONS -->',
    '<!-- DYNAMIC:SERVICE_OPTIONS -->' + options_html + '\n                            <!-- /DYNAMIC:SERVICE_OPTIONS -->',
    content, flags=re.DOTALL
)
content = re.sub(
    r'<!-- DYNAMIC:CONTACT_SERVICE_OPTIONS -->.*?<!-- /DYNAMIC:CONTACT_SERVICE_OPTIONS -->',
    '<!-- DYNAMIC:CONTACT_SERVICE_OPTIONS -->' + options_html + '\n                                <!-- /DYNAMIC:CONTACT_SERVICE_OPTIONS -->',
    content, flags=re.DOTALL
)

# Testimonials
content = re.sub(
    r'<!-- DYNAMIC:TESTIMONIALS -->.*?<!-- /DYNAMIC:TESTIMONIALS -->',
    '<!-- DYNAMIC:TESTIMONIALS -->' + testimonials_html + '\n                <!-- /DYNAMIC:TESTIMONIALS -->',
    content, flags=re.DOTALL
)

# Service areas
content = re.sub(
    r'<!-- DYNAMIC:SERVICE_AREAS -->.*?<!-- /DYNAMIC:SERVICE_AREAS -->',
    '<!-- DYNAMIC:SERVICE_AREAS -->' + areas_html + '\n                <!-- /DYNAMIC:SERVICE_AREAS -->',
    content, flags=re.DOTALL
)

with open('$OUTPUT', 'w') as f:
    f.write(content)
"

echo ""
echo "✅ Site generated successfully!"
echo "📁 Output: $OUTPUT_DIR/index.html"
echo ""
echo "Next steps:"
echo "  1. Replace placeholder images (hero-bg.jpg, about-photo.jpg)"
echo "  2. Update form action URL (Formspree, Netlify Forms, etc.)"
echo "  3. Add Google Maps embed URL in config"
echo "  4. Deploy to your web server"
echo ""
echo "🚀 Done!"
