# Real Estate Brokerage Website Template

Premium, luxury-aesthetic website template for real estate brokerages. Single-file HTML with all CSS/JS inline — designed for Ace Growth clients.

## Features

- **Luxury Design** — Dark backgrounds, gold accents, serif headings, glass effects
- **11 Sections** — Header, Hero, Services, Listings, About/Team, Why Choose Us, Testimonials, Neighborhoods, Contact, Footer, Sticky Mobile CTA
- **Mobile-First** — Fully responsive with mobile navigation and sticky CTA bar
- **SEO Optimized** — Schema.org RealEstateAgent JSON-LD, OG meta tags, semantic HTML
- **Performance** — Single file, no external dependencies (except Google Fonts), smooth animations
- **Accessible** — Scroll reveal with reduced-motion support, semantic markup, ARIA labels
- **Print Friendly** — Clean print styles

## Quick Start

### 1. Copy the template
```bash
cp index.html /path/to/client-site/index.html
```

### 2. Replace placeholders with client data

All placeholders use the `{{PLACEHOLDER}}` format. Here's the full list:

| Placeholder | Example | Description |
|---|---|---|
| `{{BROKERAGE_NAME}}` | Black Realty Company | Full brokerage name |
| `{{BROKERAGE_NAME_SHORT}}` | Black Realty | Short name for header/footer |
| `{{TAGLINE}}` | Unveiling Elegance. Redefining Luxury. | Brand tagline |
| `{{HEADLINE_PART1}}` | Your Dream Home Awaits in | Hero headline (first part) |
| `{{HEADLINE_PART2}}` | Indianapolis | Hero headline (italic/gold part) |
| `{{HERO_SUBTEXT}}` | (paragraph text) | Hero subtitle text |
| `{{PHONE}}` | (317) 710-7754 | Display phone |
| `{{PHONE_RAW}}` | +13177107754 | tel: link format |
| `{{EMAIL}}` | summer@blackrealtycompany.com | Primary email |
| `{{ADDRESS}}` | 1533 Lewis St, Indianapolis IN 46202 | Full address |
| `{{ADDRESS_STREET}}` | 1533 Lewis St | Street only |
| `{{ADDRESS_ZIP}}` | 46202 | ZIP code |
| `{{HOURS}}` | Mon-Fri 8:30AM-6PM, ... | Business hours |
| `{{WEBSITE}}` | https://blackrealtycompany.com | Website URL |
| `{{LICENSE_INFO}}` | Licensed in Indiana | License text |
| `{{COLOR_PRIMARY}}` | #0f0f1a | Primary dark color |
| `{{COLOR_ACCENT}}` | #c9a962 | Gold accent color |
| `{{COLOR_LIGHT}}` | #f8f6f0 | Light background color |
| `{{FORM_ACTION}}` | https://formspree.io/f/xxxxx | Form submission URL |
| `{{YEAR}}` | 2025 | Copyright year |

**Services** (1-4):
- `{{SERVICE_N_NAME}}`, `{{SERVICE_N_DESC}}`

**Listings** (1-3):
- `{{LISTING_N_ADDRESS}}`, `{{LISTING_N_CITY}}`, `{{LISTING_N_PRICE}}`, `{{LISTING_N_BEDS}}`, `{{LISTING_N_BATHS}}`, `{{LISTING_N_SQFT}}`, `{{LISTING_N_STATUS}}`

**Team** (1-3, add/remove cards as needed):
- `{{TEAM_N_NAME}}`, `{{TEAM_N_TITLE}}`, `{{TEAM_N_PHONE_HTML}}`, `{{TEAM_N_EMAIL_HTML}}`
- Phone HTML: `<a href="tel:+1XXXXXXXXXX"><svg ...></svg> (XXX) XXX-XXXX</a>` or empty string
- Email HTML: `<a href="mailto:x@x.com"><svg ...></svg> x@x.com</a>` or empty string

**Differentiators** (1-4):
- `{{WHY_N_TITLE}}`, `{{WHY_N_DESC}}`

**Testimonials** (1-3):
- `{{TESTIMONIAL_N_NAME}}`, `{{TESTIMONIAL_N_TEXT}}`, `{{TESTIMONIAL_N_INITIAL}}`

**Neighborhoods:**
- `{{NEIGHBORHOODS_HTML}}` — Replace with neighborhood card HTML blocks

**Social Links:**
- `{{SOCIAL_FACEBOOK_HTML}}`, `{{SOCIAL_INSTAGRAM_HTML}}` — Full `<a>` tags or empty string

**About:**
- `{{ABOUT_HEADLINE}}`, `{{ABOUT_PARAGRAPH_1}}`, `{{ABOUT_PARAGRAPH_2}}`

### 3. Set up form handling

Sign up at [Formspree](https://formspree.io) and replace `{{FORM_ACTION}}` with your endpoint.

### 4. Deploy

Upload `index.html` to your web server. That's it — single file, zero build steps.

## Customization

### Colors
Edit the CSS custom properties in `:root`:
```css
--primary: #0f0f1a;      /* Dark background */
--accent: #c9a962;        /* Gold accent */
--light: #f8f6f0;         /* Light cream */
```

### Team Members
Add or remove `.team-card` blocks in the Team section. Template supports 1-5 agents. The grid auto-adjusts.

### Listings
Add or remove `.listing-card` blocks. Update with real MLS data and replace emoji placeholders with actual property photos.

### Neighborhoods
Add or remove `.neighborhood-card` blocks in `{{NEIGHBORHOODS_HTML}}`.

## Deploy Script (Example)

```bash
# Quick deploy with sed replacements
cp templates/realty-site/index.html /var/www/site/index.html
cd /var/www/site

sed -i 's/{{BROKERAGE_NAME}}/Black Realty Company/g' index.html
sed -i 's/{{PHONE}}/(317) 710-7754/g' index.html
# ... etc for all placeholders
```

## Client Config

See `config.json` for a complete example configuration (Black Realty Company). This JSON can drive automated deployment scripts.

## License

Proprietary — Ace Growth client template. Do not distribute.
