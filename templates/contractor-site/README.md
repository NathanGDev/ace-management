# Contractor Website Template

Premium, conversion-optimized website template for home improvement contractors.

## Quick Start

```bash
# Edit config.json with client details
cp config.json my-client.json
vim my-client.json

# Generate the site
./generate.sh my-client.json /var/www/acemanagement.so/clients/my-client/
```

## Config Fields

| Field | Description |
|-------|-------------|
| businessName | Company name |
| tagline | Hero headline text |
| phone | Primary phone (click-to-call) |
| email | Contact email |
| address | Physical address |
| hours | Business hours |
| yearsInBusiness | For trust bar |
| projectsCompleted | For trust bar |
| reviewCount | For trust bar |
| licenseNumber | Footer display |
| colors.primary | Main color (default: #1a2332) |
| colors.accent | Accent color (default: #ff6b35) |
| services[] | Array of {name, description, icon} |
| serviceAreas[] | Array of city names |
| testimonials[] | Array of {name, text, rating, date, project} |
| formAction | Formspree or form endpoint URL |
| mapEmbed | Google Maps embed URL |

## Available Icons

kitchen, bathroom, basement, painting, flooring, deck, roofing, windows, doors, siding, addition, plumbing, electrical, hvac, general

## Customization

1. Edit `config.json` with the client's details
2. Run `generate.sh` to produce the site
3. Replace placeholder images
4. Update form endpoint
5. Deploy

## Template Sections

1. Sticky header + mobile CTA bar
2. Hero with quote form
3. Trust bar (stats)
4. Services grid with SVG icons
5. Before/after gallery
6. Testimonials
7. How it works (3 steps)
8. About section
9. Service areas (SEO)
10. Contact + map
11. Footer

## Deployment

Copy generated `index.html` to the client's web directory. Single file, no build step needed.
