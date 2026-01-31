/**
 * Ace Growth — AI Chatbot Widget for Contractors
 * Version 1.0.0
 * 
 * Embed with one script tag:
 *   <script src="ace-chatbot.js"></script>
 *   <script>
 *     AceChatbot.init({ companyName: "Your Company", ... });
 *   </script>
 * 
 * © 2025 Ace Growth (acegrowth.net)
 */
(function () {
  'use strict';

  const VERSION = '1.0.0';
  const STORAGE_KEY = 'ace_chatbot_leads';

  /* ─── Default Config ─── */
  const defaults = {
    companyName: 'Our Company',
    phone: '(555) 123-4567',
    services: ['Kitchen Remodel', 'Bathroom Remodel', 'Roofing', 'Siding', 'Windows & Doors', 'Flooring', 'Painting', 'General Contracting'],
    webhookUrl: '',
    accentColor: '#C49A6C',
    darkBg: '#1a1a2e',
    darkerBg: '#12121f',
    textColor: '#f0ece4',
    position: 'right',
    greeting: null,
    afterHoursStart: 18,
    afterHoursEnd: 7,
    timezone: 'America/New_York',
    bubbleIcon: null,
    showBranding: true,
  };

  let config = {};
  let chatState = {
    step: 'greeting',
    data: { name: '', phone: '', email: '', service: '', description: '' },
    messages: [],
    open: false,
    minimized: true,
    typing: false,
  };

  /* ─── Utilities ─── */
  function isAfterHours() {
    try {
      const now = new Date();
      const formatter = new Intl.DateTimeFormat('en-US', {
        hour: 'numeric',
        hour12: false,
        timeZone: config.timezone,
      });
      const hour = parseInt(formatter.format(now), 10);
      return hour >= config.afterHoursStart || hour < config.afterHoursEnd;
    } catch {
      const hour = new Date().getHours();
      return hour >= config.afterHoursStart || hour < config.afterHoursEnd;
    }
  }

  function generateId() {
    return 'lead_' + Date.now() + '_' + Math.random().toString(36).substr(2, 6);
  }

  function escapeHtml(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
  }

  function saveLeadToStorage(lead) {
    try {
      const existing = JSON.parse(localStorage.getItem(STORAGE_KEY) || '[]');
      existing.push(lead);
      localStorage.setItem(STORAGE_KEY, JSON.stringify(existing));
    } catch (e) {
      console.warn('[AceChatbot] localStorage save failed:', e);
    }
  }

  async function sendWebhook(lead) {
    if (!config.webhookUrl) return;
    try {
      await fetch(config.webhookUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          source: 'ace-chatbot',
          version: VERSION,
          timestamp: new Date().toISOString(),
          company: config.companyName,
          lead: lead,
        }),
      });
    } catch (e) {
      console.warn('[AceChatbot] Webhook failed:', e);
    }
  }

  /* ─── Inject Styles ─── */
  function injectStyles() {
    const accent = config.accentColor;
    const dark = config.darkBg;
    const darker = config.darkerBg;
    const text = config.textColor;
    const pos = config.position === 'left' ? 'left: 24px;' : 'right: 24px;';
    const posChat = config.position === 'left' ? 'left: 24px;' : 'right: 24px;';

    const style = document.createElement('style');
    style.id = 'ace-chatbot-styles';
    style.textContent = `
      @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');

      /* Reset for widget scope */
      #ace-chatbot-root * {
        box-sizing: border-box;
        margin: 0;
        padding: 0;
        font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      }

      /* ─── Bubble Button ─── */
      #ace-chat-bubble {
        position: fixed;
        bottom: 24px;
        ${pos}
        width: 64px;
        height: 64px;
        border-radius: 50%;
        background: linear-gradient(135deg, ${accent}, ${accent}dd);
        border: none;
        cursor: pointer;
        box-shadow: 0 4px 24px rgba(196, 154, 108, 0.4), 0 0 0 0 rgba(196, 154, 108, 0.3);
        z-index: 999998;
        display: flex;
        align-items: center;
        justify-content: center;
        transition: all 0.3s cubic-bezier(0.34, 1.56, 0.64, 1);
        animation: ace-pulse 3s infinite;
      }
      #ace-chat-bubble:hover {
        transform: scale(1.1);
        box-shadow: 0 6px 32px rgba(196, 154, 108, 0.5);
      }
      #ace-chat-bubble.ace-hidden { 
        transform: scale(0); 
        opacity: 0; 
        pointer-events: none; 
      }
      #ace-chat-bubble svg {
        width: 28px;
        height: 28px;
        fill: ${darker};
        transition: transform 0.3s ease;
      }
      #ace-chat-bubble:hover svg { transform: rotate(-10deg) scale(1.05); }

      #ace-bubble-badge {
        position: absolute;
        top: -2px;
        right: -2px;
        width: 20px;
        height: 20px;
        background: #ef4444;
        border-radius: 50%;
        border: 2px solid white;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 11px;
        font-weight: 700;
        color: white;
        animation: ace-badge-pop 0.4s cubic-bezier(0.34, 1.56, 0.64, 1);
      }

      @keyframes ace-pulse {
        0%, 100% { box-shadow: 0 4px 24px rgba(196, 154, 108, 0.4), 0 0 0 0 rgba(196, 154, 108, 0.3); }
        50% { box-shadow: 0 4px 24px rgba(196, 154, 108, 0.4), 0 0 0 12px rgba(196, 154, 108, 0); }
      }
      @keyframes ace-badge-pop {
        0% { transform: scale(0); }
        100% { transform: scale(1); }
      }

      /* ─── Chat Window ─── */
      #ace-chat-window {
        position: fixed;
        bottom: 100px;
        ${posChat}
        width: 400px;
        max-width: calc(100vw - 32px);
        height: 580px;
        max-height: calc(100vh - 130px);
        background: ${dark};
        border-radius: 20px;
        box-shadow: 0 20px 60px rgba(0,0,0,0.5), 0 0 0 1px rgba(196, 154, 108, 0.15);
        z-index: 999999;
        display: flex;
        flex-direction: column;
        overflow: hidden;
        transform: scale(0.85) translateY(20px);
        opacity: 0;
        pointer-events: none;
        transition: all 0.35s cubic-bezier(0.34, 1.56, 0.64, 1);
      }
      #ace-chat-window.ace-open {
        transform: scale(1) translateY(0);
        opacity: 1;
        pointer-events: all;
      }

      /* ─── Header ─── */
      .ace-chat-header {
        background: linear-gradient(135deg, ${darker}, ${dark});
        padding: 20px;
        border-bottom: 1px solid rgba(196, 154, 108, 0.2);
        position: relative;
        overflow: hidden;
      }
      .ace-chat-header::before {
        content: '';
        position: absolute;
        top: -50%;
        right: -20%;
        width: 150px;
        height: 150px;
        background: radial-gradient(circle, rgba(196, 154, 108, 0.08) 0%, transparent 70%);
        border-radius: 50%;
      }
      .ace-header-top {
        display: flex;
        align-items: center;
        justify-content: space-between;
        position: relative;
        z-index: 1;
      }
      .ace-header-info {
        display: flex;
        align-items: center;
        gap: 12px;
      }
      .ace-avatar {
        width: 42px;
        height: 42px;
        border-radius: 50%;
        background: linear-gradient(135deg, ${accent}, ${accent}aa);
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 18px;
        box-shadow: 0 2px 12px rgba(196, 154, 108, 0.3);
      }
      .ace-header-text h3 {
        color: ${text};
        font-size: 15px;
        font-weight: 600;
        letter-spacing: -0.01em;
      }
      .ace-header-status {
        display: flex;
        align-items: center;
        gap: 6px;
        margin-top: 2px;
      }
      .ace-status-dot {
        width: 8px;
        height: 8px;
        border-radius: 50%;
        background: #22c55e;
        box-shadow: 0 0 6px rgba(34, 197, 94, 0.5);
        animation: ace-status-pulse 2s infinite;
      }
      .ace-status-dot.ace-offline {
        background: #f59e0b;
        box-shadow: 0 0 6px rgba(245, 158, 11, 0.5);
      }
      @keyframes ace-status-pulse {
        0%, 100% { opacity: 1; }
        50% { opacity: 0.5; }
      }
      .ace-header-status span {
        color: ${text}99;
        font-size: 12px;
        font-weight: 500;
      }
      .ace-close-btn {
        background: rgba(255,255,255,0.08);
        border: none;
        width: 32px;
        height: 32px;
        border-radius: 10px;
        cursor: pointer;
        display: flex;
        align-items: center;
        justify-content: center;
        transition: all 0.2s ease;
      }
      .ace-close-btn:hover {
        background: rgba(255,255,255,0.15);
        transform: rotate(90deg);
      }
      .ace-close-btn svg {
        width: 16px;
        height: 16px;
        stroke: ${text}99;
        fill: none;
        stroke-width: 2;
      }

      /* ─── Messages Area ─── */
      .ace-chat-messages {
        flex: 1;
        overflow-y: auto;
        padding: 20px;
        display: flex;
        flex-direction: column;
        gap: 12px;
        scroll-behavior: smooth;
        background: ${dark};
      }
      .ace-chat-messages::-webkit-scrollbar { width: 4px; }
      .ace-chat-messages::-webkit-scrollbar-track { background: transparent; }
      .ace-chat-messages::-webkit-scrollbar-thumb { background: ${accent}40; border-radius: 4px; }

      /* ─── Message Bubbles ─── */
      .ace-msg {
        max-width: 85%;
        padding: 12px 16px;
        border-radius: 18px;
        font-size: 14px;
        line-height: 1.5;
        color: ${text};
        animation: ace-msg-in 0.3s cubic-bezier(0.34, 1.56, 0.64, 1);
        word-wrap: break-word;
      }
      @keyframes ace-msg-in {
        0% { opacity: 0; transform: translateY(10px) scale(0.95); }
        100% { opacity: 1; transform: translateY(0) scale(1); }
      }
      .ace-msg-bot {
        align-self: flex-start;
        background: ${darker};
        border: 1px solid rgba(196, 154, 108, 0.1);
        border-bottom-left-radius: 6px;
      }
      .ace-msg-user {
        align-self: flex-end;
        background: linear-gradient(135deg, ${accent}, ${accent}cc);
        color: ${darker};
        font-weight: 500;
        border-bottom-right-radius: 6px;
      }
      .ace-msg-bot a {
        color: ${accent};
        text-decoration: underline;
      }

      /* ─── Typing Indicator ─── */
      .ace-typing {
        align-self: flex-start;
        display: flex;
        gap: 5px;
        padding: 14px 18px;
        background: ${darker};
        border-radius: 18px;
        border: 1px solid rgba(196, 154, 108, 0.1);
        border-bottom-left-radius: 6px;
      }
      .ace-typing-dot {
        width: 8px;
        height: 8px;
        background: ${accent}88;
        border-radius: 50%;
        animation: ace-typing-bounce 1.4s infinite both;
      }
      .ace-typing-dot:nth-child(2) { animation-delay: 0.2s; }
      .ace-typing-dot:nth-child(3) { animation-delay: 0.4s; }
      @keyframes ace-typing-bounce {
        0%, 60%, 100% { transform: translateY(0); opacity: 0.4; }
        30% { transform: translateY(-6px); opacity: 1; }
      }

      /* ─── Input Area ─── */
      .ace-chat-input-area {
        padding: 16px 20px;
        background: ${darker};
        border-top: 1px solid rgba(196, 154, 108, 0.12);
      }
      .ace-input-wrapper {
        display: flex;
        gap: 8px;
        align-items: flex-end;
      }
      .ace-chat-input {
        flex: 1;
        background: rgba(255,255,255,0.06);
        border: 1px solid rgba(196, 154, 108, 0.15);
        border-radius: 14px;
        padding: 12px 16px;
        color: ${text};
        font-size: 14px;
        outline: none;
        transition: border-color 0.2s ease;
        resize: none;
        min-height: 44px;
        max-height: 88px;
        font-family: inherit;
      }
      .ace-chat-input::placeholder { color: ${text}55; }
      .ace-chat-input:focus { border-color: ${accent}88; }

      .ace-send-btn {
        width: 44px;
        height: 44px;
        border: none;
        border-radius: 14px;
        background: linear-gradient(135deg, ${accent}, ${accent}cc);
        cursor: pointer;
        display: flex;
        align-items: center;
        justify-content: center;
        transition: all 0.2s ease;
        flex-shrink: 0;
      }
      .ace-send-btn:hover { transform: scale(1.05); box-shadow: 0 4px 16px rgba(196, 154, 108, 0.35); }
      .ace-send-btn:disabled { opacity: 0.4; cursor: not-allowed; transform: none; }
      .ace-send-btn svg { width: 18px; height: 18px; fill: ${darker}; }

      /* ─── Service Dropdown / Select Buttons ─── */
      .ace-service-grid {
        display: flex;
        flex-wrap: wrap;
        gap: 8px;
        margin-top: 8px;
      }
      .ace-service-btn {
        background: rgba(196, 154, 108, 0.1);
        border: 1px solid rgba(196, 154, 108, 0.25);
        border-radius: 12px;
        padding: 8px 14px;
        color: ${text};
        font-size: 13px;
        font-weight: 500;
        cursor: pointer;
        transition: all 0.2s ease;
        font-family: inherit;
      }
      .ace-service-btn:hover {
        background: ${accent};
        color: ${darker};
        border-color: ${accent};
        transform: translateY(-1px);
        box-shadow: 0 4px 12px rgba(196, 154, 108, 0.3);
      }

      /* ─── Quick Reply Chips ─── */
      .ace-quick-replies {
        display: flex;
        flex-wrap: wrap;
        gap: 8px;
        margin-top: 8px;
      }
      .ace-quick-btn {
        background: transparent;
        border: 1px solid ${accent}55;
        border-radius: 20px;
        padding: 6px 14px;
        color: ${accent};
        font-size: 13px;
        font-weight: 500;
        cursor: pointer;
        transition: all 0.2s ease;
        font-family: inherit;
      }
      .ace-quick-btn:hover {
        background: ${accent};
        color: ${darker};
        transform: translateY(-1px);
      }

      /* ─── Success State ─── */
      .ace-success-msg {
        text-align: center;
        padding: 8px 0;
      }
      .ace-success-icon {
        font-size: 48px;
        margin-bottom: 8px;
        display: block;
        animation: ace-success-pop 0.5s cubic-bezier(0.34, 1.56, 0.64, 1);
      }
      @keyframes ace-success-pop {
        0% { transform: scale(0); }
        100% { transform: scale(1); }
      }

      /* ─── Branding ─── */
      .ace-branding {
        text-align: center;
        padding: 8px;
        background: ${darker};
      }
      .ace-branding a {
        color: ${text}44;
        font-size: 11px;
        text-decoration: none;
        font-weight: 500;
        transition: color 0.2s;
      }
      .ace-branding a:hover { color: ${accent}88; }

      /* ─── Mobile Responsive ─── */
      @media (max-width: 480px) {
        #ace-chat-window {
          width: 100vw;
          height: 100vh;
          max-height: 100vh;
          bottom: 0;
          right: 0;
          left: 0;
          border-radius: 0;
        }
        #ace-chat-bubble {
          bottom: 16px;
          right: 16px;
          width: 56px;
          height: 56px;
        }
        #ace-chat-bubble svg {
          width: 24px;
          height: 24px;
        }
      }

      /* ─── Preloader shimmer ─── */
      .ace-shimmer {
        background: linear-gradient(90deg, transparent 0%, rgba(196, 154, 108, 0.06) 50%, transparent 100%);
        background-size: 200% 100%;
        animation: ace-shimmer 1.5s infinite;
      }
      @keyframes ace-shimmer {
        0% { background-position: -200% 0; }
        100% { background-position: 200% 0; }
      }
    `;
    document.head.appendChild(style);
  }

  /* ─── Build DOM ─── */
  function buildWidget() {
    const root = document.createElement('div');
    root.id = 'ace-chatbot-root';

    // Chat bubble
    root.innerHTML = `
      <button id="ace-chat-bubble" aria-label="Open chat">
        <svg viewBox="0 0 24 24"><path d="M20 2H4c-1.1 0-2 .9-2 2v18l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm0 14H6l-2 2V4h16v12z"/></svg>
        <div id="ace-bubble-badge">1</div>
      </button>

      <div id="ace-chat-window">
        <div class="ace-chat-header">
          <div class="ace-header-top">
            <div class="ace-header-info">
              <div class="ace-avatar">🏠</div>
              <div class="ace-header-text">
                <h3>${escapeHtml(config.companyName)}</h3>
                <div class="ace-header-status">
                  <div class="ace-status-dot ${isAfterHours() ? 'ace-offline' : ''}"></div>
                  <span>${isAfterHours() ? 'Away — we\'ll reply ASAP' : 'Online — typically replies instantly'}</span>
                </div>
              </div>
            </div>
            <button class="ace-close-btn" aria-label="Close chat">
              <svg viewBox="0 0 24 24"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
            </button>
          </div>
        </div>
        <div class="ace-chat-messages" id="ace-messages"></div>
        <div class="ace-chat-input-area">
          <div class="ace-input-wrapper">
            <textarea class="ace-chat-input" id="ace-input" placeholder="Type your message..." rows="1"></textarea>
            <button class="ace-send-btn" id="ace-send" aria-label="Send">
              <svg viewBox="0 0 24 24"><path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z"/></svg>
            </button>
          </div>
        </div>
        ${config.showBranding ? '<div class="ace-branding"><a href="https://acegrowth.net" target="_blank" rel="noopener">⚡ Powered by Ace Growth</a></div>' : ''}
      </div>
    `;

    document.body.appendChild(root);
    bindEvents();
    // Start the conversation
    setTimeout(() => showGreeting(), 600);
  }

  /* ─── Event Binding ─── */
  function bindEvents() {
    const bubble = document.getElementById('ace-chat-bubble');
    const closeBtn = document.querySelector('.ace-close-btn');
    const input = document.getElementById('ace-input');
    const sendBtn = document.getElementById('ace-send');

    bubble.addEventListener('click', toggleChat);
    closeBtn.addEventListener('click', toggleChat);

    sendBtn.addEventListener('click', handleSend);
    input.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        handleSend();
      }
    });

    // Auto-resize textarea
    input.addEventListener('input', () => {
      input.style.height = 'auto';
      input.style.height = Math.min(input.scrollHeight, 88) + 'px';
    });
  }

  function toggleChat() {
    const win = document.getElementById('ace-chat-window');
    const bubble = document.getElementById('ace-chat-bubble');
    chatState.open = !chatState.open;

    if (chatState.open) {
      win.classList.add('ace-open');
      bubble.classList.add('ace-hidden');
      const badge = document.getElementById('ace-bubble-badge');
      if (badge) badge.style.display = 'none';
      setTimeout(() => {
        document.getElementById('ace-input')?.focus();
      }, 400);
    } else {
      win.classList.remove('ace-open');
      bubble.classList.remove('ace-hidden');
    }
  }

  /* ─── Message Rendering ─── */
  function addMessage(text, sender, extra) {
    const container = document.getElementById('ace-messages');
    const msg = document.createElement('div');
    msg.className = `ace-msg ace-msg-${sender}`;

    if (extra === 'html') {
      msg.innerHTML = text;
    } else {
      msg.textContent = text;
    }

    container.appendChild(msg);
    chatState.messages.push({ text, sender, time: Date.now() });
    scrollToBottom();
    return msg;
  }

  function addServiceButtons() {
    const container = document.getElementById('ace-messages');
    const wrapper = document.createElement('div');
    wrapper.className = 'ace-service-grid';
    wrapper.style.animation = 'ace-msg-in 0.3s cubic-bezier(0.34, 1.56, 0.64, 1)';

    config.services.forEach((service) => {
      const btn = document.createElement('button');
      btn.className = 'ace-service-btn';
      btn.textContent = service;
      btn.addEventListener('click', () => {
        chatState.data.service = service;
        addMessage(service, 'user');
        wrapper.remove();
        advanceStep();
      });
      wrapper.appendChild(btn);
    });

    // Add "Other" option
    const otherBtn = document.createElement('button');
    otherBtn.className = 'ace-service-btn';
    otherBtn.textContent = '✏️ Other';
    otherBtn.addEventListener('click', () => {
      chatState.step = 'service_other';
      wrapper.remove();
      showBotMessage("No problem! Just type what you need help with.");
      enableInput('Describe what you need...');
    });
    wrapper.appendChild(otherBtn);

    container.appendChild(wrapper);
    scrollToBottom();
  }

  function addQuickReplies(options) {
    const container = document.getElementById('ace-messages');
    const wrapper = document.createElement('div');
    wrapper.className = 'ace-quick-replies';
    wrapper.style.animation = 'ace-msg-in 0.3s cubic-bezier(0.34, 1.56, 0.64, 1)';

    options.forEach(({ label, value }) => {
      const btn = document.createElement('button');
      btn.className = 'ace-quick-btn';
      btn.textContent = label;
      btn.addEventListener('click', () => {
        addMessage(label, 'user');
        wrapper.remove();
        if (typeof value === 'function') value();
      });
      wrapper.appendChild(btn);
    });

    container.appendChild(wrapper);
    scrollToBottom();
  }

  function showTyping() {
    const container = document.getElementById('ace-messages');
    const typing = document.createElement('div');
    typing.className = 'ace-typing';
    typing.id = 'ace-typing-indicator';
    typing.innerHTML = '<div class="ace-typing-dot"></div><div class="ace-typing-dot"></div><div class="ace-typing-dot"></div>';
    container.appendChild(typing);
    scrollToBottom();
  }

  function hideTyping() {
    const el = document.getElementById('ace-typing-indicator');
    if (el) el.remove();
  }

  function showBotMessage(text, extra) {
    return new Promise((resolve) => {
      showTyping();
      const delay = Math.min(600 + text.length * 12, 1800);
      setTimeout(() => {
        hideTyping();
        addMessage(text, 'bot', extra);
        resolve();
      }, delay);
    });
  }

  function scrollToBottom() {
    const container = document.getElementById('ace-messages');
    if (container) {
      setTimeout(() => {
        container.scrollTop = container.scrollHeight;
      }, 50);
    }
  }

  function enableInput(placeholder) {
    const input = document.getElementById('ace-input');
    const sendBtn = document.getElementById('ace-send');
    input.disabled = false;
    input.placeholder = placeholder || 'Type your message...';
    sendBtn.disabled = false;
    input.focus();
  }

  function disableInput() {
    const input = document.getElementById('ace-input');
    const sendBtn = document.getElementById('ace-send');
    input.disabled = true;
    sendBtn.disabled = true;
  }

  /* ─── Conversation Flow ─── */
  async function showGreeting() {
    const greeting = config.greeting || "Hey! 👋 Need a free estimate? I can help you get started right now.";
    await showBotMessage(greeting);

    addQuickReplies([
      { label: '✅ Yes, get me an estimate!', value: () => { chatState.step = 'ask_name'; advanceStep(); } },
      { label: `📞 Call ${config.phone}`, value: () => { window.open('tel:' + config.phone.replace(/\D/g, ''), '_self'); } },
    ]);
  }

  async function advanceStep() {
    disableInput();

    switch (chatState.step) {
      case 'ask_name':
        await showBotMessage("Awesome! Let's get you that estimate. What's your name?");
        chatState.step = 'get_name';
        enableInput('Your name...');
        break;

      case 'get_phone':
        await showBotMessage(`Nice to meet you, ${chatState.data.name}! 😊 What's the best phone number to reach you?`);
        chatState.step = 'get_phone_input';
        enableInput('(555) 123-4567');
        break;

      case 'get_email':
        await showBotMessage("And your email? (We'll send the estimate details there)");
        chatState.step = 'get_email_input';
        enableInput('your@email.com');
        break;

      case 'get_service':
        await showBotMessage("What type of project are you looking at?");
        chatState.step = 'get_service_select';
        disableInput();
        setTimeout(() => addServiceButtons(), 300);
        break;

      case 'get_description':
        await showBotMessage("Tell us a bit more about the project — size, timeline, anything that helps! (Or type \"skip\" to move on)");
        chatState.step = 'get_description_input';
        enableInput('Describe your project...');
        break;

      case 'complete':
        await submitLead();
        break;
    }
  }

  function handleSend() {
    const input = document.getElementById('ace-input');
    const text = input.value.trim();
    if (!text) return;

    addMessage(text, 'user');
    input.value = '';
    input.style.height = 'auto';

    processInput(text);
  }

  function processInput(text) {
    switch (chatState.step) {
      case 'get_name':
        chatState.data.name = text;
        chatState.step = 'get_phone';
        advanceStep();
        break;

      case 'get_phone_input':
        // Basic phone validation
        const cleanPhone = text.replace(/\D/g, '');
        if (cleanPhone.length < 7) {
          showBotMessage("Hmm, that doesn't look like a valid number. Try again? Include area code if possible.");
          enableInput('(555) 123-4567');
          return;
        }
        chatState.data.phone = text;
        chatState.step = 'get_email';
        advanceStep();
        break;

      case 'get_email_input':
        // Basic email validation
        if (!text.includes('@') || !text.includes('.')) {
          showBotMessage("That doesn't look like a valid email. Can you double-check?");
          enableInput('your@email.com');
          return;
        }
        chatState.data.email = text;
        chatState.step = 'get_service';
        advanceStep();
        break;

      case 'service_other':
        chatState.data.service = text;
        chatState.step = 'get_description';
        advanceStep();
        break;

      case 'get_service_select':
        chatState.data.service = text;
        chatState.step = 'get_description';
        advanceStep();
        break;

      case 'get_description_input':
        chatState.data.description = text.toLowerCase() === 'skip' ? '' : text;
        chatState.step = 'complete';
        advanceStep();
        break;
    }
  }

  async function submitLead() {
    disableInput();

    const lead = {
      id: generateId(),
      ...chatState.data,
      timestamp: new Date().toISOString(),
      afterHours: isAfterHours(),
      page: window.location.href,
      userAgent: navigator.userAgent,
    };

    // Save to localStorage
    saveLeadToStorage(lead);

    // Send webhook
    sendWebhook(lead);

    // Show success
    const afterHoursMsg = isAfterHours()
      ? `\n\n🌙 We're currently closed but your info is saved — you'll hear from us first thing in the morning!`
      : '';

    const successHtml = `
      <div class="ace-success-msg">
        <span class="ace-success-icon">🎉</span>
        <strong>You're all set, ${escapeHtml(chatState.data.name)}!</strong>
      </div>
    `;

    await showBotMessage(successHtml, 'html');
    await showBotMessage(
      `Got it! Someone from ${config.companyName} will call you within 1 business day. For urgent needs, call us directly at ${config.phone}.${afterHoursMsg}`
    );

    addQuickReplies([
      { label: `📞 Call ${config.phone} Now`, value: () => { window.open('tel:' + config.phone.replace(/\D/g, ''), '_self'); } },
      { label: '✅ Sounds good!', value: async () => { await showBotMessage("Thanks! Have a great day! 😊"); } },
    ]);
  }

  /* ─── Public API ─── */
  window.AceChatbot = {
    init: function (userConfig) {
      config = Object.assign({}, defaults, userConfig);
      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => {
          injectStyles();
          buildWidget();
        });
      } else {
        injectStyles();
        buildWidget();
      }
    },
    open: function () {
      if (!chatState.open) toggleChat();
    },
    close: function () {
      if (chatState.open) toggleChat();
    },
    getLeads: function () {
      try {
        return JSON.parse(localStorage.getItem(STORAGE_KEY) || '[]');
      } catch {
        return [];
      }
    },
    clearLeads: function () {
      localStorage.removeItem(STORAGE_KEY);
    },
    version: VERSION,
  };
})();
