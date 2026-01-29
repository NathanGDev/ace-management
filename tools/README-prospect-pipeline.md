# ♠️ Ace Growth — Prospect Pipeline

**One command. Full prospect package. Ready to call.**

The Prospect Pipeline takes a business URL (or name + city) and automatically:
1. **Researches** the business — scrapes their site for phone, address, email, services, and site quality
2. **Generates a growth audit** — scores their site across 5 categories with specific issues found
3. **Generates a demo website** — creates a polished demo showing what their site *could* look like
4. **Deploys both** to `acegrowth.net/demos/[business-slug]/`
5. **Outputs a call brief** — everything Kae needs to pick up the phone and close

## Usage

```bash
# By URL (most common)
./prospect-pipeline.sh https://blackrealtycompany.com

# By business name + city
./prospect-pipeline.sh "Black Realty Company" "Indianapolis"

# Just a domain (auto-adds https://)
./prospect-pipeline.sh blackrealtycompany.com
```

## Options

```bash
--no-deploy    # Generate audit + demo but don't deploy to production
--audit-only   # Only generate the growth audit (skip demo site)
--demo-only    # Only generate the demo site (skip audit)
```

## What Gets Deployed

After running, you'll find:

| URL | Content |
|-----|---------|
| `acegrowth.net/demos/[slug]/growth-audit.html` | Interactive growth audit |
| `acegrowth.net/demos/[slug]/` | Demo website |
| `acegrowth.net/demos/[slug]/call-brief.txt` | Text call brief |

## How Scoring Works

The pipeline runs automated checks on the business website and scores across 5 categories (0-10 each, combined to 0-100):

| Category | What It Checks |
|----------|---------------|
| **First Impressions** | H1 tags, CTAs, images, content depth |
| **Mobile Experience** | Viewport meta, click-to-call, HTTPS |
| **Trust & Credibility** | Reviews/testimonials, social links, portfolio |
| **Lead Capture** | Forms, click-to-call, chat widgets |
| **SEO & Visibility** | Title tag, meta description, schema, content length |

> ⚠️ Scores are **rough automated estimates** — directionally correct, not perfect. They're designed to start a conversation, not be a definitive audit.

## Service Detection

The pipeline tries to auto-detect what services the business offers by:
1. Parsing `<h2>` and `<h3>` headings from their site
2. Looking at meta descriptions and page content
3. Matching against known industry keywords

If it can't detect services, it falls back to industry-appropriate defaults based on the business name and description.

## Dependencies

- `curl` — web fetching
- `jq` — JSON processing (auto-installs if missing)
- `python3` — data processing and JSON generation
- `grep`, `sed`, `awk` — text processing
- `generate-audit.sh` — audit HTML generator (in `tools/audit-generator/`)
- `generate.sh` — site generator (in `templates/contractor-site/`)

## File Locations

| File | Location |
|------|----------|
| Pipeline script | `tools/prospect-pipeline.sh` |
| Audit generator | `tools/audit-generator/generate-audit.sh` |
| Site generator | `templates/contractor-site/generate.sh` |
| Deploy root | `/var/www/acemanagement.so/demos/` |
| Research output | `/tmp/prospect-research.json` |
| Audit JSON | `/tmp/prospect-audit.json` |

## Example Output

```
♠️ PROSPECT READY: Black Realty Company

📞 Phone: (317) 555-1234
📧 Email: info@blackrealty.com
📍 Address: 123 Main St, Indianapolis, IN 46204
🌐 Website: https://blackrealtycompany.com
📊 Score: 34/100

🔍 AUDIT: https://acegrowth.net/demos/black-realty-company/growth-audit.html
🎨 DEMO:  https://acegrowth.net/demos/black-realty-company/

📋 KEY TALKING POINTS:
  • No clear headline — visitors don't know what you do in 3 seconds
  • Phone number not clickable — mobile users can't tap to call
  • No Google reviews or testimonials displayed on website

💰 REVENUE IMPACT:
  • Losing an estimated 10-25 leads per month
  • Potential annual revenue lost: $100K-300K
  • Fixing these issues = more calls, more customers

Ready to call. Go get it. ♠️
```

## Troubleshooting

- **Website returns 403/blocked**: Some sites block automated requests. Try fetching manually and check the output.
- **No services detected**: The pipeline defaults to industry-appropriate services based on the business name.
- **Audit generator fails**: Make sure `tools/audit-generator/generate-audit.sh` exists and is executable.
- **Deploy fails**: Check that `/var/www/acemanagement.so/demos/` exists and is writable.
