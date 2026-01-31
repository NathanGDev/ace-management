# ⭐ Ace Growth — Automated Review Request System

A simple, powerful system to automatically request Google reviews from customers after job completion. Tracks all requests, sends follow-ups, and works with Twilio (SMS) and any SMTP email.

**No monthly fees. No complex setup. Just results.**

---

## 🚀 How It Works

```
Job Complete → Run Script → Customer Gets SMS + Email → 3-Day Follow-up → More Reviews!
```

1. Contractor completes a job
2. You (or the contractor) runs `review-request.sh` with the customer's info
3. Customer receives a personalized SMS and/or email asking for a Google review
4. If `--schedule-followup` is used, a gentle reminder is sent 3 days later
5. Everything is tracked in a CSV for reporting

---

## ⚡ Quick Start

### 1. Setup

```bash
cd /root/ace-management/tools/review-automation

# Copy config template
cp config.env.example config.env

# Edit with your credentials
nano config.env

# Make scripts executable
chmod +x review-request.sh tracker.sh
```

### 2. Send a review request

```bash
./review-request.sh \
  --name "John Smith" \
  --phone "+13175551234" \
  --email "john@example.com" \
  --company "Pro Contractors Inc." \
  --review-link "https://g.page/r/YOUR-PLACE-ID/review" \
  --schedule-followup
```

### 3. Check status

```bash
./tracker.sh stats        # Summary statistics
./tracker.sh list         # All requests
./tracker.sh followup     # Process due follow-ups
```

---

## 📱 SMS Setup (Twilio)

### Free Option
1. Go to [twilio.com/try-twilio](https://www.twilio.com/try-twilio)
2. Sign up for a free account ($15 credit = ~1,000 SMS)
3. Get your Account SID, Auth Token, and a phone number
4. Add them to `config.env`

### Cost
- ~$0.0079 per SMS = **less than 1 cent per review request**
- $15 free credit = ~1,900 messages to start

### Alternatives (No Twilio)
- **Google Voice**: Manual but free
- **TextBelt**: `curl http://textbelt.com/text -d phone=5551234567 -d message="Your message"`
- **Email-to-SMS**: Most carriers support it:
  - AT&T: `number@txt.att.net`
  - Verizon: `number@vtext.com`
  - T-Mobile: `number@tmomail.net`

---

## 📧 Email Setup

### Gmail (Recommended)
1. Enable 2FA on your Google account
2. Go to [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords)
3. Create an App Password
4. Add to `config.env`:
   ```
   SMTP_HOST="smtp.gmail.com"
   SMTP_PORT="587"
   SMTP_USER="your@gmail.com"
   SMTP_PASS="your-app-password"
   FROM_EMAIL="your@gmail.com"
   ```

### Other Providers
- **SendGrid**: Free tier = 100 emails/day
- **Mailgun**: Free tier = 100 emails/day
- **Any SMTP**: Just change SMTP_HOST and SMTP_PORT

---

## 📋 Commands Reference

### `review-request.sh`

```bash
# Full options
./review-request.sh \
  --name "Customer Name"        # Required
  --phone "+13175551234"        # Phone (E.164 format)
  --email "email@example.com"   # Email address
  --company "Company Name"      # Company name (or use default)
  --review-link "URL"           # Google review link (Required)
  --method sms|email|both       # Contact method (default: both)
  --schedule-followup           # Auto-send reminder in 3 days
  --job-id "INV-001"            # Optional job reference

# Examples
./review-request.sh --name "Jane" --phone "+13175559876" --review-link "https://g.page/r/xxx/review"
./review-request.sh --name "Mike" --email "mike@gmail.com" --method email --schedule-followup
```

### `tracker.sh`

```bash
./tracker.sh list               # Show all requests
./tracker.sh list --pending     # Show pending follow-ups only
./tracker.sh stats              # Summary statistics
./tracker.sh search "Smith"     # Search by name, company, etc.
./tracker.sh followup           # Process and send due follow-ups
./tracker.sh mark-reviewed ID   # Mark a request as "reviewed"
./tracker.sh help               # Show help
```

---

## 🔗 Getting a Google Review Link

### For a Google Business Profile:
1. Go to [Google Business Profile](https://business.google.com/)
2. Click your business → "Get more reviews"
3. Copy the review link
4. Format: `https://g.page/r/YOUR-PLACE-ID/review`

### Shortcut:
Search for the business on Google Maps → Share → Copy link, then append `/review`

---

## 📁 File Structure

```
review-automation/
├── README.md                    # This file
├── config.env.example           # Config template
├── config.env                   # Your config (gitignored)
├── review-request.sh            # Main script — sends requests
├── tracker.sh                   # View/manage/search requests
├── templates/
│   ├── sms-template.txt         # SMS message template
│   └── email-template.html      # Beautiful HTML email template
└── data/                        # Auto-created
    ├── review-tracker.csv       # All request history
    └── followups/               # Scheduled follow-up files
```

---

## 🎨 Customizing Templates

### SMS Template (`templates/sms-template.txt`)
Available variables:
- `{{NAME}}` — First name
- `{{FULL_NAME}}` — Full name
- `{{COMPANY}}` — Company name
- `{{REVIEW_LINK}}` — Google review URL

### Email Template (`templates/email-template.html`)
Same variables, plus:
- `{{PHONE}}` — Company phone number
- Fully branded dark theme matching Ace Growth styling
- Mobile-responsive HTML email

---

## 🤖 Automation Ideas

### Cron job for follow-ups
```bash
# Run daily at 10am to check for due follow-ups
0 10 * * * /root/ace-management/tools/review-automation/tracker.sh followup
```

### Webhook integration
After a chatbot lead converts to a completed job, trigger:
```bash
./review-request.sh --name "$NAME" --phone "$PHONE" --company "$COMPANY" \
  --review-link "$LINK" --schedule-followup
```

### Batch processing
```bash
# Send to multiple customers from a CSV
while IFS=',' read -r name phone email; do
  ./review-request.sh --name "$name" --phone "$phone" --email "$email" \
    --company "Pro Contractors" --review-link "https://g.page/r/xxx/review" \
    --schedule-followup
  sleep 2  # Be nice to APIs
done < customers.csv
```

---

## 💡 Sales Pitch Points

When demoing to contractors:

1. **"Every completed job = review opportunity"** — Most contractors forget to ask
2. **"Automated follow-up"** — 3-day reminder doubles review rates
3. **"Professional templates"** — Beautiful emails, not sketchy texts
4. **"Tracking built in"** — Know exactly who was contacted and when
5. **"Costs less than a penny per request"** — Twilio SMS is $0.008 each
6. **"More reviews = more leads"** — Direct ROI they can see

### The Math:
- 10 jobs/month × 30% review rate = 3 new reviews/month
- 3 reviews/month = **36 new Google reviews per year**
- Each review ≈ 1-3 new leads → **36-108 leads from reviews alone**

---

*Built with ❤️ by [Ace Growth](https://acegrowth.net)*
