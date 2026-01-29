# Contractor Lead System — Build Plan
**Date:** 2026-01-29
**Status:** IN PROGRESS

## What We're Building

A complete, repeatable system to sell, deliver, and retain contractor clients at $3K setup + $1K/mo.

---

## Component 1: Contractor Website Template
**Priority:** 🔴 CRITICAL — This is the product
**Location:** `templates/contractor-site/`

A premium, conversion-optimized contractor website that can be customized for any client in under 2 hours.

### Requirements:
- Single HTML file (self-contained, easy to deploy)
- Config-driven via `config.json` (swap name, phone, colors, services, photos)
- Mobile-first, loads in <2 seconds
- Sections:
  - Sticky header with phone number + CTA button
  - Hero: Strong headline + subhead + "Get Free Quote" form
  - Trust bar: Years in business, projects completed, 5-star reviews, licensed/insured
  - Services grid (6-8 services with icons)
  - Before/After project gallery
  - Testimonials carousel (Google reviews style)
  - Process section (How it works: 1-2-3)
  - About section with photo
  - Service areas (city list)
  - Contact form + map embed
  - Footer with NAP, hours, license info
- SEO: Schema.org LocalBusiness markup, meta tags, OG tags
- Click-to-call on all phone numbers
- Form submissions → email notification (Formspree or similar)
- Conversion elements: sticky mobile CTA bar, exit intent, urgency

### Deliverable:
- `index.html` — The template
- `config.json` — Business customization file
- `README.md` — How to customize and deploy
- `generator.sh` — Script that takes config.json and outputs a ready-to-deploy site

---

## Component 2: Growth Audit Generator
**Priority:** 🔴 CRITICAL — This is the sales weapon
**Location:** `tools/audit-generator/`

Automated tool that creates personalized growth audit pages for prospects.

### Requirements:
- Shell script or Node script
- Input: `audit.json` with prospect details:
  ```json
  {
    "businessName": "White Rabbit Wraps",
    "ownerName": "Billie",
    "phone": "(317) 858-5297",
    "website": "whiterabbitwraps.com",
    "services": ["Vehicle Wraps", "PPF", "Ceramic Coating"],
    "issues": [
      {"category": "First Impression", "score": 3, "detail": "No clear CTA above fold"},
      {"category": "Mobile Experience", "score": 2, "detail": "Menu doesn't work on mobile"},
      {"category": "Trust Signals", "score": 4, "detail": "Reviews exist but buried"},
      {"category": "Lead Capture", "score": 1, "detail": "No quote form anywhere"},
      {"category": "SEO", "score": 2, "detail": "No service area pages, thin content"}
    ],
    "competitors": ["Competitor A is ranking above you for 'vehicle wraps indianapolis'"],
    "opportunities": ["Could capture 15-20 more leads/month with proper conversion funnel"]
  }
  ```
- Output: Beautiful HTML audit page (like White Rabbit's)
- Auto-deploy to `/var/www/acemanagement.so/demos/[business-slug]/growth-audit.html`
- Overall score, category breakdowns, specific recommendations
- CTA at bottom: "Let's fix this — call Kae at (317) 572-7018"

### Deliverable:
- `generate-audit.sh` — The generator script
- `audit-template.html` — Base HTML template
- `README.md` — How to use

---

## Component 3: Sales Playbook & SOPs
**Priority:** 🟡 HIGH — Kae needs this for calls
**Location:** `docs/`

### Documents to create:
1. **SALES-PLAYBOOK.md** — Complete A-Z guide
   - Prospecting process
   - Cold call script (with branches)
   - Discovery call framework
   - Audit walkthrough script
   - The 15-minute close
   - Objection handling (every objection + response)
   - Pricing presentation
   - Follow-up sequence
   - When to walk away

2. **CLIENT-ONBOARDING.md** — After they pay
   - Kickoff call agenda
   - Information needed checklist:
     - Google Business Profile login
     - Logo files
     - Photos (what to take, how many)
     - Service list
     - Service areas
     - Business story / about
     - Existing reviews to feature
   - Timeline: Day 1-14 delivery schedule
   - Communication expectations

3. **MONTHLY-OPERATIONS.md** — Ongoing $1K/mo work
   - Weekly GBP posts (templates)
   - Monthly content calendar
   - SEO check-in tasks
   - Review generation system
   - Monthly report template (what to include)
   - Client call agenda (15 min monthly check-in)

4. **REPORT-TEMPLATE.html** — Monthly performance report
   - Branded, professional HTML report
   - Sections: calls received, form submissions, Google rankings, GBP views, recommendations
   - Easy to fill in and send

---

## Component 4: Service Area Page Generator
**Priority:** 🟢 MEDIUM — Upsell/retention tool
**Location:** `tools/service-area-generator/`

Script that generates SEO-optimized pages for each city a contractor serves.

### Requirements:
- Input: business name, service type, list of cities
- Output: Individual HTML pages optimized for "[service] in [city]"
- Each page: unique intro, service details, local references, CTA, schema markup
- Naming: `[service]-[city].html`

---

## Deployment Plan

1. All code → GitHub `ace-management` repo
2. Client sites → `/var/www/acemanagement.so/clients/[name]/`
3. Audit pages → `/var/www/acemanagement.so/demos/[name]/`
4. Caddy auto-serves everything under acemanagement.so

---

## Sub-Agent Assignments

| Agent | Task | Status |
|-------|------|--------|
| Agent 1 | Contractor Website Template + Generator | 🔄 |
| Agent 2 | Growth Audit Generator | 🔄 |
| Agent 3 | Sales Playbook + SOPs + Report Template | 🔄 |

---

*Plan created: 2026-01-29 by Ace*
