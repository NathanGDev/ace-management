# Growth Audit Generator

Generate beautiful, personalized growth audit pages for contractor prospects. These audits are the #1 sales weapon — they show a contractor exactly what's wrong with their website and why they're losing leads.

## Quick Start

```bash
# Generate an audit from JSON data
./generate-audit.sh sample-audit.json

# Generate AND deploy to the live site
./generate-audit.sh sample-audit.json --deploy
```

## How It Works

1. Create a JSON file with the audit data (see `sample-audit.json` for the format)
2. Run `generate-audit.sh` with the JSON file
3. A beautiful HTML page is generated in `./output/`
4. With `--deploy`, it's also copied to `/var/www/acemanagement.so/demos/<business-slug>/growth-audit.html`

## JSON Format

```json
{
  "businessName": "Business Name",
  "ownerName": "Owner First Name",
  "website": "example.com",
  "phone": "(317) 555-0123",
  "date": "January 29, 2026",
  "avgJobValue": "$25,000",
  "overallScore": 34,
  "executiveSummary": "2-3 sentences about what we found...",
  "categories": [
    {
      "name": "First Impressions",
      "icon": "👁️",
      "score": 3,
      "maxScore": 10,
      "issues": [
        "Issue 1",
        "Issue 2"
      ],
      "benchmark": "What good looks like for this category"
    }
  ],
  "revenueImpact": {
    "currentConversion": "under 1%",
    "potentialConversion": "5-8%",
    "estimatedMonthlyVisitors": 500,
    "avgJobValue": "$25,000",
    "lostLeadsPerMonth": "10-20",
    "annualRevenueLost": "$100K-300K"
  },
  "competitors": [
    "Competitor A does X better than you",
    "Competitor B has Y advantage"
  ],
  "recommendations": [
    "Fix #1 (highest impact)",
    "Fix #2",
    "Fix #3",
    "Fix #4",
    "Fix #5"
  ]
}
```

### Categories (5 standard)

| Category | Icon | What It Measures |
|----------|------|-----------------|
| First Impressions | 👁️ | Hero, headline, design quality |
| Mobile Experience | 📱 | Responsive, speed, usability |
| Trust & Credibility | ⭐ | Reviews, certifications, photos |
| Lead Capture | 🎯 | Forms, CTAs, phone placement |
| SEO & Visibility | 🔍 | Rankings, content, local SEO |

### Score Ranges

| Score | Color | Label |
|-------|-------|-------|
| 0-24 | Red | Critical — Immediate Action Needed |
| 25-39 | Red | Poor — Significant Issues Found |
| 40-54 | Yellow | Below Average — Room for Improvement |
| 55-69 | Yellow | Average — Some Gaps to Address |
| 70-84 | Green | Good — Minor Optimizations Needed |
| 85-100 | Green | Excellent — Well Optimized |

## Output

- **Local:** `./output/<business-slug>-growth-audit.html`
- **Deployed:** `https://acemanagement.so/demos/<business-slug>/growth-audit.html`

## Dependencies

- `jq` — JSON parser (auto-installs if missing)
- `python3` — for template processing
- `bc` — for math calculations

## Creating an Audit for a New Prospect

1. Visit their website, take notes on issues
2. Copy `sample-audit.json` → `<business-name>.json`
3. Fill in all fields with your findings
4. Run `./generate-audit.sh <business-name>.json --deploy`
5. Send the URL to the prospect

## Tips

- Keep the executive summary personal — use the owner's name if you have it
- Be specific with issues ("Phone number not clickable" > "Bad mobile experience")
- The revenue impact section is what closes deals — make the numbers real
- Always include competitor data — nothing motivates like competition
