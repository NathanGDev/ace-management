#!/usr/bin/env python3
"""
Ace Growth — Prospect Analyzer

Reads a fetched HTML file and produces:
  1. research.json — extracted business info
  2. audit.json — growth audit data with scores
  3. site-config.json — demo site configuration

All in one shot, no shell quoting issues.
"""

import argparse
import json
import re
import os
import sys
from datetime import datetime
from html.parser import HTMLParser


# ──────────────────────────────────────
# HTML text extraction
# ──────────────────────────────────────

class TextExtractor(HTMLParser):
    def __init__(self):
        super().__init__()
        self.text_parts = []
        self.skip_tags = {'script', 'style', 'noscript', 'svg', 'path'}
        self._skip_depth = 0

    def handle_starttag(self, tag, attrs):
        if tag in self.skip_tags:
            self._skip_depth += 1

    def handle_endtag(self, tag):
        if tag in self.skip_tags and self._skip_depth > 0:
            self._skip_depth -= 1

    def handle_data(self, data):
        if self._skip_depth == 0:
            text = data.strip()
            if text:
                self.text_parts.append(text)

    def get_text(self):
        return ' '.join(self.text_parts)


def extract_text(html):
    """Extract visible text from HTML."""
    extractor = TextExtractor()
    try:
        extractor.feed(html)
    except:
        pass
    return extractor.get_text()


# ──────────────────────────────────────
# Research: extract business info
# ──────────────────────────────────────

def extract_business_info(html, url):
    """Extract business details from HTML."""
    text = extract_text(html)
    html_lower = html.lower()

    # Business name from <title>
    title_match = re.search(r'<title[^>]*>([^<]+)</title>', html, re.IGNORECASE)
    biz_name = ""
    if title_match:
        biz_name = title_match.group(1).strip()
        # Clean up common title suffixes
        biz_name = re.split(r'\s*[|–—\-]\s*', biz_name)[0].strip()

    if not biz_name:
        # Try og:title
        og_match = re.search(r'property=["\']og:title["\'][^>]*content=["\']([^"\']+)', html, re.IGNORECASE)
        if og_match:
            biz_name = og_match.group(1).strip()

    if not biz_name and url:
        # Derive from URL
        domain = re.sub(r'https?://(www\.)?', '', url).split('/')[0].split('.')[0]
        biz_name = domain.replace('-', ' ').replace('_', ' ').title()

    # Phone number
    phone = "Not found"
    # First check tel: links
    tel_match = re.search(r'href=["\']tel:([^"\']+)', html, re.IGNORECASE)
    if tel_match:
        raw = re.sub(r'[^\d]', '', tel_match.group(1))
        if len(raw) == 11 and raw[0] == '1':
            raw = raw[1:]
        if len(raw) == 10:
            phone = f"({raw[:3]}) {raw[3:6]}-{raw[6:]}"
        elif len(raw) >= 7:
            phone = tel_match.group(1).strip()

    if phone == "Not found":
        # Search text for phone patterns
        phone_patterns = [
            r'\(?\d{3}\)?[\s.-]\d{3}[\s.-]\d{4}',
            r'\d{3}[\s.-]\d{3}[\s.-]\d{4}',
        ]
        for pat in phone_patterns:
            m = re.search(pat, text)
            if m:
                raw_phone = m.group(0)
                digits = re.sub(r'[^\d]', '', raw_phone)
                if len(digits) == 10:
                    phone = f"({digits[:3]}) {digits[3:6]}-{digits[6:]}"
                else:
                    phone = raw_phone
                break

    # Email
    email = "Not found"
    email_matches = re.findall(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}', html)
    skip_domains = ['example.', 'placeholder.', 'sentry.', 'wixpress.', 'w3.org', 'schema.org',
                    'domain.', 'email.', 'yoursite.', 'test.']
    for em in email_matches:
        if not any(d in em.lower() for d in skip_domains):
            email = em
            break

    # Address — look for structured patterns
    address = "Not found"
    addr_patterns = [
        r'\d{1,5}\s+[A-Z][a-zA-Z\s]+(?:Street|St|Avenue|Ave|Boulevard|Blvd|Drive|Dr|Road|Rd|Lane|Ln|Court|Ct|Way|Circle|Cir|Place|Pl)\.?[\s,]+(?:Suite|Ste|#|Apt\.?)?\s*\d*[\s,]+[A-Z][a-zA-Z\s]+,?\s*[A-Z]{2}\s+\d{5}',
        r'\d{1,5}\s+\S+\s+\S+[.,]\s*\S+[.,]?\s*[A-Z]{2}\s+\d{5}',
    ]
    for pat in addr_patterns:
        m = re.search(pat, text)
        if m:
            address = m.group(0).strip()
            break

    # Meta description
    meta_desc = ""
    meta_match = re.search(r'name=["\']description["\'][^>]*content=["\']([^"\']+)', html, re.IGNORECASE)
    if meta_match:
        meta_desc = meta_match.group(1).strip()
    if not meta_desc:
        og_desc = re.search(r'property=["\']og:description["\'][^>]*content=["\']([^"\']+)', html, re.IGNORECASE)
        if og_desc:
            meta_desc = og_desc.group(1).strip()
    if not meta_desc:
        meta_desc = "No meta description found"

    # Service headings — extract h2/h3 content
    headings = re.findall(r'<h[2-4][^>]*>([^<]{3,60})</h[2-4]>', html, re.IGNORECASE)
    skip_words = ['welcome', 'hello', 'click', 'learn more', 'read more', 'view', 'see',
                  'our team', 'meet', 'get started', 'sign up', 'log in', 'subscribe',
                  'menu', 'navigation', 'footer', 'header', 'copyright', 'cookie', 'privacy']
    service_headings = []
    for h in headings:
        h = h.strip()
        if h and not any(sw in h.lower() for sw in skip_words):
            service_headings.append(h)

    # Site quality checks
    checks = {
        "hasViewport": bool(re.search(r'viewport', html_lower)),
        "hasForms": bool(re.search(r'<form', html_lower)),
        "hasSchema": bool(re.search(r'application/ld\+json|schema\.org|itemtype', html_lower)),
        "hasReviews": bool(re.search(r'review|testimonial|rating|stars', text.lower())),
        "hasCTA": bool(re.search(r'btn|button|cta|get.*quote|free.*estimate|contact.*us|call.*now|schedule|book.*now', html_lower)),
        "hasH1": bool(re.search(r'<h1', html_lower)),
        "hasClickablePhone": bool(re.search(r'tel:', html_lower)),
        "hasChat": bool(re.search(r'livechat|tawk|intercom|drift|crisp|zendesk|hubspot.*chat|chat.*widget|messenger', html_lower)),
        "hasSSL": url.startswith('https://') if url else False,
        "hasTitleTag": bool(title_match),
        "hasImages": len(re.findall(r'<img', html_lower)) > 3,
        "hasSocial": bool(re.search(r'facebook|instagram|twitter|linkedin|youtube|yelp|google.*business|bbb\.org', html_lower)),
        "contentLength": len(text),
        "reviewMentions": len(re.findall(r'review|testimonial', text.lower())),
        "ctaCount": len(re.findall(r'btn|button|cta|get.*quote|free.*estimate|contact.*us|call.*now|schedule|book.*now', html_lower)),
        "formCount": len(re.findall(r'<form', html_lower)),
        "imageCount": len(re.findall(r'<img', html_lower)),
    }

    # Try to extract brand colors
    primary_color = "#1a2332"
    accent_color = "#ff6b35"

    color_vars = re.findall(r'--(?:primary|brand|main)[^:]*:\s*(#[0-9a-fA-F]{3,8})', html)
    if color_vars:
        primary_color = color_vars[0]

    accent_vars = re.findall(r'--(?:accent|secondary|highlight)[^:]*:\s*(#[0-9a-fA-F]{3,8})', html)
    if accent_vars:
        accent_color = accent_vars[0]

    return {
        "url": url or "",
        "businessName": biz_name,
        "phone": phone,
        "email": email,
        "address": address,
        "metaDescription": meta_desc[:500],
        "serviceHeadings": service_headings[:15],
        "siteChecks": checks,
        "colors": {
            "primary": primary_color,
            "accent": accent_color,
        }
    }


# ──────────────────────────────────────
# Audit: score and generate audit JSON
# ──────────────────────────────────────

def generate_audit(research):
    """Generate audit JSON from research data."""
    checks = research["siteChecks"]
    biz_name = research["businessName"]
    phone = research["phone"]
    website = research["url"]

    # --- First Impressions (0-10) ---
    fi_score = 3
    if checks.get("hasH1"): fi_score += 2
    if checks.get("ctaCount", 0) > 2: fi_score += 2
    elif checks.get("hasCTA"): fi_score += 1
    if checks.get("imageCount", 0) > 5: fi_score += 2
    elif checks.get("hasImages"): fi_score += 1
    if checks.get("contentLength", 0) > 5000: fi_score += 1
    fi_score = min(fi_score, 10)

    fi_issues = []
    if not checks.get("hasH1"):
        fi_issues.append("No clear headline — visitors don't know what you do in 3 seconds")
    if not checks.get("hasCTA") or checks.get("ctaCount", 0) < 3:
        fi_issues.append("Weak or missing call-to-action — visitors aren't guided to contact you")
    if not checks.get("hasImages") or checks.get("imageCount", 0) < 5:
        fi_issues.append("Few or no project images — missing visual proof of your work")
    if checks.get("contentLength", 0) < 3000:
        fi_issues.append("Thin content — not enough information to build confidence")
    if not fi_issues:
        fi_issues.append("Homepage could benefit from a stronger hero section and visual hierarchy")

    # --- Mobile Experience (0-10) ---
    mob_score = 3
    if checks.get("hasViewport"): mob_score += 3
    if checks.get("hasClickablePhone"): mob_score += 2
    if checks.get("hasSSL"): mob_score += 1
    if checks.get("hasCTA"): mob_score += 1
    mob_score = min(mob_score, 10)

    mob_issues = []
    if not checks.get("hasViewport"):
        mob_issues.append("No viewport meta tag — site may not be mobile-responsive")
    if not checks.get("hasClickablePhone"):
        mob_issues.append("Phone number not clickable — mobile users can't tap to call")
    if not checks.get("hasSSL"):
        mob_issues.append("Not using HTTPS — browsers show 'Not Secure' warning")
    if not mob_issues:
        mob_issues.append("Mobile layout could be optimized for thumb-friendly navigation")
        mob_issues.append("Key information may be hidden below the fold on mobile")

    # --- Trust & Credibility (0-10) ---
    trust_score = 2
    review_mentions = checks.get("reviewMentions", 0)
    if review_mentions > 5: trust_score += 3
    elif review_mentions > 0: trust_score += 1
    if checks.get("hasSocial"): trust_score += 2
    if checks.get("imageCount", 0) > 10: trust_score += 2
    elif checks.get("hasImages"): trust_score += 1
    if checks.get("hasSchema"): trust_score += 1
    trust_score = min(trust_score, 10)

    trust_issues = []
    if review_mentions < 3:
        trust_issues.append("No Google reviews or testimonials displayed on website")
    if not checks.get("hasImages") or checks.get("imageCount", 0) < 10:
        trust_issues.append("Limited portfolio — no before/after project showcase")
    if not checks.get("hasSocial"):
        trust_issues.append("No social media links — missing social proof opportunities")
    if not trust_issues:
        trust_issues.append("License and insurance information not prominently displayed")

    # --- Lead Capture (0-10) ---
    lead_score = 2
    if checks.get("formCount", 0) > 1: lead_score += 3
    elif checks.get("hasForms"): lead_score += 2
    if checks.get("hasClickablePhone"): lead_score += 2
    if checks.get("hasChat"): lead_score += 2
    if checks.get("ctaCount", 0) > 3: lead_score += 1
    lead_score = min(lead_score, 10)

    lead_issues = []
    if not checks.get("hasForms") or checks.get("formCount", 0) < 2:
        lead_issues.append("No quote request form on homepage — forcing visitors to hunt for contact info")
    if not checks.get("hasClickablePhone"):
        lead_issues.append("No sticky phone number — mobile users lose the number when scrolling")
    if not checks.get("hasChat"):
        lead_issues.append("No live chat or chat widget — missing instant engagement opportunity")
    if not lead_issues:
        lead_issues.append("Contact form could be simplified to reduce friction")

    # --- SEO & Visibility (0-10) ---
    seo_score = 2
    if checks.get("hasTitleTag"): seo_score += 2
    if checks.get("hasSchema"): seo_score += 2
    if checks.get("contentLength", 0) > 10000: seo_score += 2
    elif checks.get("contentLength", 0) > 3000: seo_score += 1
    if checks.get("hasSSL"): seo_score += 1
    meta = research.get("metaDescription", "")
    if meta and meta != "No meta description found": seo_score += 1
    seo_score = min(seo_score, 10)

    seo_issues = []
    if not checks.get("hasTitleTag"):
        seo_issues.append("Missing or generic title tag — invisible to Google searchers")
    if not meta or meta == "No meta description found":
        seo_issues.append("No meta description — Google shows random text in search results")
    if not checks.get("hasSchema"):
        seo_issues.append("No schema markup — missing rich snippets in search results")
    if checks.get("contentLength", 0) < 5000:
        seo_issues.append("Thin content — not enough text for Google to understand your services")
    if not seo_issues:
        seo_issues.append("No dedicated service area pages for local SEO")

    # Overall score (each category 0-10, total * 2 = 0-100)
    overall = (fi_score + mob_score + trust_score + lead_score + seo_score) * 2

    # Executive summary
    if overall < 30:
        summary = f"{biz_name} has significant gaps in their online presence that are costing them leads every day. Critical issues in mobile experience, lead capture, and SEO mean potential customers are finding competitors instead. The good news: these are all fixable, and fixing them would put you ahead of 90% of local competitors."
    elif overall < 50:
        summary = f"{biz_name} has a basic web presence, but major gaps in lead capture, trust signals, and SEO are leaving money on the table. Competitors with better-optimized sites are capturing the leads that should be yours. Strategic improvements could double your online lead generation within 90 days."
    elif overall < 70:
        summary = f"{biz_name} has a decent foundation online, but specific gaps in conversion optimization and local SEO are limiting your growth. Targeted improvements in lead capture and trust-building could significantly increase your lead flow."
    else:
        summary = f"{biz_name} has a solid online presence with room for strategic improvements. Fine-tuning your conversion funnel and local SEO presence would help capture more market share."

    # Recommendations
    recommendations = []
    if lead_score < 5:
        recommendations.append("Add a prominent quote request form above the fold on every page")
    if not checks.get("hasClickablePhone"):
        recommendations.append("Make phone number click-to-call and sticky on mobile")
    if trust_score < 5:
        recommendations.append("Display your best Google reviews and before/after project photos")
    if mob_score < 5:
        recommendations.append("Rebuild for mobile-first — 60%+ of your visitors are on phones")
    if seo_score < 5:
        recommendations.append("Create service area pages targeting '[service] + [city]' keywords")
    if not recommendations:
        recommendations.append("Optimize conversion funnel for higher lead capture rate")
    recommendations.append("Implement structured data markup for rich search results")
    recommendations.append("Add a lead magnet (free guide, checklist) to capture email leads")

    # Competitors
    competitors = [
        "Top-ranking competitors in your area have 10+ service pages — they're capturing search traffic you're missing",
        "Competitors with reviews displayed on their site convert 2-3x more visitors into leads"
    ]

    # Revenue impact
    monthly_visitors = 800 if checks.get("contentLength", 0) > 10000 else 500
    current_conv = "1-2%" if lead_score > 5 else "under 1%"

    audit = {
        "businessName": biz_name,
        "ownerName": "Owner",
        "website": website or "Not found",
        "phone": phone,
        "date": datetime.now().strftime("%B %d, %Y"),
        "avgJobValue": "$15,000",
        "overallScore": overall,
        "executiveSummary": summary,
        "categories": [
            {
                "name": "First Impressions",
                "icon": "👁️",
                "score": fi_score,
                "maxScore": 10,
                "issues": fi_issues[:3],
                "benchmark": "Top businesses have a clear value prop + contact form visible immediately"
            },
            {
                "name": "Mobile Experience",
                "icon": "📱",
                "score": mob_score,
                "maxScore": 10,
                "issues": mob_issues[:3],
                "benchmark": "60%+ of visitors are on mobile. They should be able to call you in one tap."
            },
            {
                "name": "Trust & Credibility",
                "icon": "⭐",
                "score": trust_score,
                "maxScore": 10,
                "issues": trust_issues[:3],
                "benchmark": "Customers check 3-5 businesses before calling. Reviews and photos win."
            },
            {
                "name": "Lead Capture",
                "icon": "🎯",
                "score": lead_score,
                "maxScore": 10,
                "issues": lead_issues[:3],
                "benchmark": "Best sites have a form above the fold + click-to-call everywhere."
            },
            {
                "name": "SEO & Visibility",
                "icon": "🔍",
                "score": seo_score,
                "maxScore": 10,
                "issues": seo_issues[:3],
                "benchmark": "Local SEO = free leads forever. Service area pages rank for '[service] in [city]'."
            }
        ],
        "revenueImpact": {
            "currentConversion": current_conv,
            "potentialConversion": "5-8%",
            "estimatedMonthlyVisitors": monthly_visitors,
            "avgJobValue": "$15,000",
            "lostLeadsPerMonth": "10-25",
            "annualRevenueLost": "$100K-300K"
        },
        "competitors": competitors,
        "recommendations": recommendations[:5]
    }

    print(f"  Overall Score: {overall}/100")
    print(f"  First Impressions: {fi_score}/10")
    print(f"  Mobile: {mob_score}/10")
    print(f"  Trust: {trust_score}/10")
    print(f"  Lead Capture: {lead_score}/10")
    print(f"  SEO: {seo_score}/10")

    return audit


# ──────────────────────────────────────
# Site config: generate demo site config
# ──────────────────────────────────────

def detect_industry(research):
    """Guess the industry from available text."""
    meta = research.get("metaDescription", "").lower()
    name = research["businessName"].lower()
    headings = " ".join(research.get("serviceHeadings", [])).lower()
    all_text = f"{meta} {name} {headings}"

    industries = {
        "real_estate": ["real estate", "realty", "realtor", "property", "homes for sale", "mls", "broker"],
        "plumbing": ["plumb", "drain", "pipe", "water heater", "sewer"],
        "electrical": ["electric", "wiring", "panel", "circuit", "outlet"],
        "roofing": ["roof", "shingle", "gutter", "storm damage"],
        "hvac": ["hvac", "heating", "cooling", "air condition", "furnace", "ac repair"],
        "cleaning": ["clean", "maid", "janitorial", "pressure wash"],
        "landscaping": ["landscap", "lawn", "garden", "tree", "mow", "irrigation"],
        "painting": ["paint", "stain", "finish", "coating"],
        "auto": ["auto", "car", "vehicle", "mechanic", "repair shop", "tire", "brake"],
        "dental": ["dental", "dentist", "teeth", "orthodont", "oral"],
        "legal": ["law", "attorney", "legal", "lawyer", "counsel"],
        "wraps": ["wrap", "vinyl", "graphic", "signage", "print"],
        "remodeling": ["remodel", "renovation", "kitchen", "bathroom", "basement", "contractor"],
        "moving": ["moving", "movers", "relocation", "hauling"],
        "pest": ["pest", "exterminator", "termite", "bug"],
        "insurance": ["insurance", "coverage", "policy", "claim"],
    }

    for industry, keywords in industries.items():
        if any(kw in all_text for kw in keywords):
            return industry

    return "general"


def get_industry_services(industry):
    """Return default services for an industry."""
    service_map = {
        "real_estate": [
            ("Residential Sales", "Expert guidance buying or selling your home. We know the local market inside and out."),
            ("Property Management", "Full-service property management that maximizes your investment returns."),
            ("Commercial Real Estate", "Commercial property sales, leasing, and investment opportunities."),
            ("Investment Properties", "Find and analyze investment properties with strong ROI potential."),
            ("First-Time Buyers", "Dedicated support for first-time homebuyers navigating the process."),
            ("Market Analysis", "Comprehensive market analysis to price your property competitively."),
        ],
        "plumbing": [
            ("Emergency Plumbing", "24/7 emergency plumbing service when you need it most."),
            ("Drain Cleaning", "Professional drain cleaning to restore full flow to your pipes."),
            ("Water Heater Repair", "Expert water heater repair and installation for reliable hot water."),
            ("Pipe Installation", "Quality pipe installation and repair for your home or business."),
            ("Bathroom Plumbing", "Complete bathroom plumbing services from faucets to full renovations."),
            ("Kitchen Plumbing", "Kitchen plumbing solutions including garbage disposals and dishwashers."),
        ],
        "electrical": [
            ("Residential Electrical", "Complete electrical services for your home's safety and comfort."),
            ("Panel Upgrades", "Electrical panel upgrades to handle modern power demands."),
            ("Lighting Installation", "Interior and exterior lighting design and installation."),
            ("Emergency Repairs", "24/7 emergency electrical repair when you need it fast."),
            ("Code Compliance", "Electrical inspections and code compliance updates."),
            ("EV Charger Installation", "Home EV charger installation for your electric vehicle."),
        ],
        "roofing": [
            ("Roof Replacement", "Complete roof replacement with premium materials and expert installation."),
            ("Roof Repair", "Fast, reliable roof repairs to protect your home."),
            ("Storm Damage", "Emergency storm damage repair and insurance claim assistance."),
            ("Gutter Installation", "Seamless gutter installation and maintenance."),
            ("Roof Inspection", "Thorough roof inspections with detailed reports."),
            ("Commercial Roofing", "Commercial roofing solutions for businesses of all sizes."),
        ],
        "hvac": [
            ("AC Installation", "High-efficiency AC installation to keep you cool and save energy."),
            ("Heating Repair", "Expert heating system repair for all makes and models."),
            ("HVAC Maintenance", "Preventive maintenance plans to extend equipment life."),
            ("Duct Cleaning", "Professional duct cleaning for better air quality."),
            ("Emergency Service", "24/7 emergency HVAC service when comfort can't wait."),
            ("Commercial HVAC", "Commercial HVAC solutions for offices and retail."),
        ],
        "cleaning": [
            ("Residential Cleaning", "Thorough home cleaning that gives you your weekends back."),
            ("Commercial Cleaning", "Professional cleaning services for offices and businesses."),
            ("Deep Cleaning", "Intensive deep cleaning for a truly spotless space."),
            ("Move-In/Move-Out", "Move-in and move-out cleaning that gets your deposit back."),
            ("Office Cleaning", "Regular office cleaning to maintain a professional workspace."),
            ("Post-Construction", "Post-construction cleanup to make new spaces shine."),
        ],
        "landscaping": [
            ("Landscape Design", "Custom landscape design that transforms your outdoor space."),
            ("Lawn Maintenance", "Regular lawn care that keeps your property looking its best."),
            ("Tree Service", "Professional tree trimming, removal, and stump grinding."),
            ("Hardscaping", "Patios, walkways, retaining walls, and outdoor living spaces."),
            ("Irrigation", "Sprinkler system installation, repair, and maintenance."),
            ("Seasonal Cleanup", "Spring and fall cleanup to keep your property pristine."),
        ],
        "wraps": [
            ("Vehicle Wraps", "Turn your vehicles into mobile billboards with stunning wraps."),
            ("Wall Graphics", "Transform walls into branded experiences with custom graphics."),
            ("Window Graphics", "Professional window graphics for privacy and branding."),
            ("Floor Graphics", "Eye-catching floor graphics for retail and events."),
            ("Trade Show Displays", "Stand out at trade shows with professional displays."),
            ("Custom Signage", "Custom signage solutions for businesses of all sizes."),
        ],
        "remodeling": [
            ("Kitchen Remodeling", "Complete kitchen transformations from cabinets to countertops."),
            ("Bathroom Renovation", "Modern bathroom upgrades including tile, vanities, and showers."),
            ("Basement Finishing", "Transform unused space into living areas and entertainment rooms."),
            ("Interior Painting", "Professional painting with premium paints and meticulous prep."),
            ("Flooring Installation", "Hardwood, tile, luxury vinyl, and carpet installation."),
            ("Decks & Outdoor", "Custom decks, patios, pergolas, and outdoor kitchens."),
        ],
    }

    default = [
        ("Consultation", "Professional consultation to understand your needs and goals."),
        ("Project Management", "End-to-end project management for seamless execution."),
        ("Custom Solutions", "Tailored solutions designed specifically for your situation."),
        ("Maintenance Plans", "Ongoing maintenance plans to protect your investment."),
        ("Emergency Service", "Responsive emergency service when you need it most."),
        ("Commercial Services", "Professional services for businesses and commercial properties."),
    ]

    return service_map.get(industry, default)


def get_icon(name):
    """Map service name to an icon key."""
    name_lower = name.lower()
    icon_map = {
        "kitchen": "kitchen", "bathroom": "bathroom", "bath": "bathroom",
        "basement": "basement", "paint": "painting", "floor": "flooring",
        "deck": "deck", "outdoor": "deck", "patio": "deck",
        "roof": "roofing", "window": "windows", "door": "doors",
        "siding": "siding", "addition": "addition", "plumb": "plumbing",
        "electric": "electrical", "wiring": "electrical",
    }
    for keyword, icon in icon_map.items():
        if keyword in name_lower:
            return icon
    return "general"


def generate_site_config(research, city="Indianapolis"):
    """Generate demo site config from research."""
    biz_name = research["businessName"]
    phone = research["phone"] if research["phone"] != "Not found" else "(317) 555-0000"
    email = research["email"] if research["email"] != "Not found" else "info@example.com"
    address = research["address"] if research["address"] != "Not found" else f"{city}, IN"
    website = research["url"]
    primary = research["colors"]["primary"]
    accent = research["colors"]["accent"]

    industry = detect_industry(research)
    print(f"  Detected industry: {industry}")

    # Build services from headings or defaults
    service_headings = research.get("serviceHeadings", [])
    industry_services = get_industry_services(industry)

    services = []
    used_names = set()

    # First try extracted headings
    for h in service_headings[:6]:
        h = h.strip()
        if h and len(h) > 2 and h.lower() not in used_names:
            services.append({
                "name": h,
                "description": f"Professional {h.lower()} services delivered with quality craftsmanship and attention to detail.",
                "icon": get_icon(h)
            })
            used_names.add(h.lower())

    # Fill remaining with industry defaults
    for name, desc in industry_services:
        if len(services) >= 6:
            break
        if name.lower() not in used_names:
            services.append({
                "name": name,
                "description": desc,
                "icon": get_icon(name)
            })
            used_names.add(name.lower())

    print(f"  Services: {', '.join(s['name'] for s in services)}")
    print(f"  Colors: {primary} / {accent}")

    config = {
        "businessName": biz_name,
        "tagline": f"{biz_name} — Your Trusted Local Partner",
        "phone": phone,
        "email": email,
        "website": website,
        "address": address,
        "hours": "Mon–Fri 8AM–6PM, Sat 9AM–2PM",
        "yearsInBusiness": 10,
        "projectsCompleted": "500+",
        "reviewCount": "100+",
        "licenseNumber": "Licensed & Insured",
        "colors": {
            "primary": primary,
            "accent": accent,
            "light": "#f8f9fa"
        },
        "services": services,
        "serviceAreas": [
            city, "Carmel", "Fishers", "Noblesville",
            "Westfield", "Zionsville", "Brownsburg", "Avon",
            "Greenwood", "Lawrence"
        ],
        "testimonials": [
            {
                "name": "Sarah M.",
                "text": f"Amazing experience with {biz_name}! Professional, responsive, and delivered exactly what was promised. Highly recommend to anyone looking for quality service.",
                "rating": 5,
                "date": "2 months ago",
                "project": services[0]["name"] if services else "Service"
            },
            {
                "name": "James K.",
                "text": f"We've used {biz_name} twice now and both times exceeded expectations. Fair pricing, great communication, and outstanding results.",
                "rating": 5,
                "date": "3 weeks ago",
                "project": services[1]["name"] if len(services) > 1 else "Service"
            },
            {
                "name": "Michael R.",
                "text": f"Couldn't be happier with the work. {biz_name} was respectful, on time, and the quality speaks for itself. Worth every penny.",
                "rating": 5,
                "date": "1 month ago",
                "project": services[2]["name"] if len(services) > 2 else "Service"
            }
        ],
        "formAction": "#",
        "mapEmbed": "https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d195370.23!2d-86.33!3d39.78!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x886b50ffa7796a03%3A0xd68e9df640b9ea7c!2sIndianapolis%2C+IN!5e0!3m2!1sen!2sus"
    }

    return config


# ──────────────────────────────────────
# Main
# ──────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Ace Growth Prospect Analyzer")
    parser.add_argument("--html", required=True, help="Path to fetched HTML file")
    parser.add_argument("--url", default="", help="Original URL")
    parser.add_argument("--research-out", required=True, help="Output path for research JSON")
    parser.add_argument("--audit-out", required=True, help="Output path for audit JSON")
    parser.add_argument("--site-config-out", required=True, help="Output path for site config JSON")
    parser.add_argument("--override-name", default="", help="Override business name")
    parser.add_argument("--city", default="Indianapolis", help="City for service areas")
    args = parser.parse_args()

    # Read HTML
    print("  Reading HTML...")
    try:
        with open(args.html, 'r', errors='replace') as f:
            html = f.read()
    except Exception as e:
        print(f"  ⚠️ Could not read HTML: {e}")
        html = "<html><head><title>Unknown</title></head><body></body></html>"

    # Phase 1: Research
    print("  Extracting business info...")
    research = extract_business_info(html, args.url)

    if args.override_name:
        research["businessName"] = args.override_name

    print(f"  Business: {research['businessName']}")
    print(f"  Phone: {research['phone']}")
    print(f"  Email: {research['email']}")
    print(f"  Address: {research['address']}")

    with open(args.research_out, 'w') as f:
        json.dump(research, f, indent=2)
    print(f"  ✅ Research saved: {args.research_out}")

    # Phase 2: Audit
    print("\n  Scoring website...")
    audit = generate_audit(research)

    with open(args.audit_out, 'w') as f:
        json.dump(audit, f, indent=2)
    print(f"  ✅ Audit saved: {args.audit_out}")

    # Phase 3: Site config
    print("\n  Generating site config...")
    config = generate_site_config(research, args.city)

    with open(args.site_config_out, 'w') as f:
        json.dump(config, f, indent=2)
    print(f"  ✅ Site config saved: {args.site_config_out}")


if __name__ == "__main__":
    main()
