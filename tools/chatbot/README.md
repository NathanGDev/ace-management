# 💬 Ace Growth — AI Chatbot Widget

A beautiful, embeddable chatbot widget for contractor websites. Captures leads 24/7, stores them locally, and sends them via webhook.

**No API keys. No monthly fees. One script tag.**

![Demo](https://acegrowth.net/demos/chatbot/)

---

## ⚡ Quick Start

### 1. Add the script to your website

```html
<!-- Before </body> -->
<script src="https://acegrowth.net/demos/chatbot/ace-chatbot.js"></script>
<script>
  AceChatbot.init({
    companyName: 'Your Company Name',
    phone: '(317) 555-1234',
    services: ['Kitchen Remodel', 'Bathroom Remodel', 'Roofing', 'Painting'],
    webhookUrl: 'https://your-webhook-url.com/leads',
  });
</script>
```

That's it. The chatbot appears as a gold bubble in the bottom-right corner.

---

## 🎨 Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `companyName` | string | `'Our Company'` | Company name shown in header & messages |
| `phone` | string | `'(555) 123-4567'` | Phone number for direct calls |
| `services` | array | 8 common services | List of services to show as buttons |
| `webhookUrl` | string | `''` | URL to POST lead data to |
| `accentColor` | string | `'#C49A6C'` | Primary accent color (gold) |
| `darkBg` | string | `'#1a1a2e'` | Main background color |
| `darkerBg` | string | `'#12121f'` | Darker background color |
| `textColor` | string | `'#f0ece4'` | Text color |
| `position` | string | `'right'` | Bubble position: `'right'` or `'left'` |
| `greeting` | string | auto | Custom greeting message |
| `afterHoursStart` | number | `18` | After hours start (24h format, e.g. 18 = 6pm) |
| `afterHoursEnd` | number | `7` | After hours end (24h format, e.g. 7 = 7am) |
| `timezone` | string | `'America/New_York'` | Timezone for after-hours detection |
| `showBranding` | bool | `true` | Show "Powered by Ace Growth" |

---

## 📞 Conversation Flow

1. **Greeting** — "Hey! 👋 Need a free estimate?"
2. **Name** — Collects customer name
3. **Phone** — Validates phone number
4. **Email** — Validates email format
5. **Service** — Beautiful button grid of services (+ "Other" option)
6. **Description** — Optional project details
7. **Confirmation** — Success message + after-hours notice if applicable

---

## 🔗 Webhook Data

When a lead completes the form, the widget POSTs JSON to your webhook:

```json
{
  "source": "ace-chatbot",
  "version": "1.0.0",
  "timestamp": "2025-01-15T14:30:00.000Z",
  "company": "Pro Contractors Inc.",
  "lead": {
    "id": "lead_1705312200_abc123",
    "name": "John Smith",
    "phone": "(317) 555-9876",
    "email": "john@example.com",
    "service": "Kitchen Remodel",
    "description": "Looking to remodel our 200 sq ft kitchen",
    "timestamp": "2025-01-15T14:30:00.000Z",
    "afterHours": false,
    "page": "https://procontractors.com/",
    "userAgent": "Mozilla/5.0..."
  }
}
```

### Webhook Ideas
- **Zapier** — Forward to email, Google Sheets, CRM
- **Make.com** — Send SMS notification via Twilio
- **Custom endpoint** — Your own server
- **n8n** — Self-hosted automation

---

## 🛠️ JavaScript API

```js
// Open the chat window
AceChatbot.open();

// Close the chat window
AceChatbot.close();

// Get all stored leads (from localStorage)
const leads = AceChatbot.getLeads();

// Clear stored leads
AceChatbot.clearLeads();

// Version
console.log(AceChatbot.version); // "1.0.0"
```

### Trigger from any button:
```html
<button onclick="AceChatbot.open()">Get Free Estimate</button>
```

---

## 💾 Lead Backup

All leads are automatically saved to `localStorage` under the key `ace_chatbot_leads`. This means:
- Leads are never lost, even if the webhook fails
- You can retrieve leads from the browser console: `AceChatbot.getLeads()`
- Leads persist across page refreshes

---

## 📱 Mobile Support

The widget is fully responsive:
- On desktop: 400px floating window
- On mobile (<480px): Full-screen overlay for the best UX

---

## 🌙 After Hours Detection

The widget automatically detects if it's after business hours (default: 6pm–7am) and:
- Shows "Away" status in the header
- Adds a reassuring message: "We're currently closed but your info is saved..."
- Uses the configured timezone for accurate detection

---

## 🎨 Customization Per Client

For each contractor client, customize:

```js
AceChatbot.init({
  companyName: 'Mike\'s Roofing',
  phone: '(317) 555-ROOF',
  services: ['Roof Replacement', 'Roof Repair', 'Gutter Installation', 'Storm Damage'],
  accentColor: '#2563eb',  // Blue branding
  greeting: 'Hey! 👋 Need a roof inspection? It\'s completely free!',
  webhookUrl: 'https://hooks.zapier.com/hooks/catch/xxxxx',
  timezone: 'America/Indianapolis',
});
```

---

## 📁 Files

| File | Description |
|------|-------------|
| `ace-chatbot.js` | The embeddable widget (single file, no dependencies) |
| `demo.html` | Full demo page showing the widget on a contractor site |
| `README.md` | This documentation |

---

## 🚀 Deployment

### For Ace Growth hosted clients:
1. Copy `ace-chatbot.js` to the client's website directory
2. Add the `<script>` tags with their config
3. Set up a webhook (Zapier, Make, etc.) for lead notifications
4. Test the conversation flow

### For self-hosted clients:
1. Give them `ace-chatbot.js`
2. They add the two `<script>` tags
3. Done!

---

## 💡 Sales Demo Tips

When showing this to contractors:

1. **Open the demo page** — it looks like a real contractor website
2. **Click the gold chat bubble** — watch the smooth animation
3. **Walk through the conversation** — name, phone, email, service selection
4. **Highlight the after-hours feature** — "Even at 2am, you're capturing leads"
5. **Show the service buttons** — "Customers don't have to type — just tap"
6. **Mention the webhook** — "Every lead goes straight to your phone as a text"
7. **Open console → `AceChatbot.getLeads()`** — "Nothing is ever lost"

---

*Built with ❤️ by [Ace Growth](https://acegrowth.net)*
