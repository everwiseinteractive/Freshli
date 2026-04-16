/* Freshli i18n engine — client-side localisation.
 * Works by reading data-i18n="section.key" attributes on DOM elements,
 * looking up translations in window.__freshliTranslations[lang], and
 * injecting the value as innerHTML (so translated HTML tags/entities render).
 *
 * Language picker: inject a dropdown into the nav. Persist to localStorage.
 * Auto-detect navigator.language on first visit. Falls back to English.
 * RTL applied automatically for Arabic.
 */
(function () {
  'use strict';

  var SUPPORTED = [
    { code: 'en',    name: 'English',    flag: '🇬🇧', native: 'English' },
    { code: 'fr',    name: 'French',     flag: '🇫🇷', native: 'Français' },
    { code: 'es',    name: 'Spanish',    flag: '🇪🇸', native: 'Español' },
    { code: 'de',    name: 'German',     flag: '🇩🇪', native: 'Deutsch' },
    { code: 'it',    name: 'Italian',    flag: '🇮🇹', native: 'Italiano' },
    { code: 'pt',    name: 'Portuguese', flag: '🇧🇷', native: 'Português' },
    { code: 'ja',    name: 'Japanese',   flag: '🇯🇵', native: '日本語' },
    { code: 'ko',    name: 'Korean',     flag: '🇰🇷', native: '한국어' },
    { code: 'zh',    name: 'Chinese',    flag: '🇨🇳', native: '中文' },
    { code: 'ar',    name: 'Arabic',     flag: '🇸🇦', native: 'العربية' }
  ];
  var RTL_LANGS = ['ar', 'he', 'fa', 'ur'];
  var STORAGE_KEY = 'freshliLang';
  var DEFAULT_LANG = 'en';

  /* -------- Language detection -------- */
  function detectLanguage() {
    // 1. URL query param (?lang=xx)
    try {
      var params = new URLSearchParams(window.location.search);
      var q = params.get('lang');
      if (q && isSupported(q)) return q;
    } catch (_) {}

    // 2. localStorage
    try {
      var stored = localStorage.getItem(STORAGE_KEY);
      if (stored && isSupported(stored)) return stored;
    } catch (_) {}

    // 3. navigator.language — take first 2 chars
    var nav = (navigator.language || navigator.userLanguage || 'en').toLowerCase();
    var base = nav.split('-')[0];
    if (isSupported(base)) return base;

    // 4. Fallback
    return DEFAULT_LANG;
  }

  function isSupported(code) {
    return SUPPORTED.some(function (l) { return l.code === code; });
  }

  function getLangMeta(code) {
    return SUPPORTED.find(function (l) { return l.code === code; }) || SUPPORTED[0];
  }

  /* -------- Translation lookup -------- */
  function lookup(key, lang) {
    var bundle = (window.__freshliTranslations && window.__freshliTranslations[lang]) || null;
    var fallback = window.__freshliTranslations && window.__freshliTranslations[DEFAULT_LANG];
    var parts = key.split('.');
    var result = resolve(bundle, parts);
    if (result === undefined || result === null || result === '') {
      result = resolve(fallback, parts);
    }
    return (typeof result === 'string') ? result : null;
  }

  function resolve(obj, parts) {
    if (!obj) return undefined;
    var cur = obj;
    for (var i = 0; i < parts.length; i++) {
      if (cur == null || typeof cur !== 'object') return undefined;
      cur = cur[parts[i]];
    }
    return cur;
  }

  /* -------- DOM application -------- */
  function applyTranslations(lang) {
    var meta = getLangMeta(lang);

    // html lang + dir attributes
    document.documentElement.setAttribute('lang', lang);
    var dir = (RTL_LANGS.indexOf(lang) !== -1) ? 'rtl' : 'ltr';
    document.documentElement.setAttribute('dir', dir);
    document.body && document.body.setAttribute('data-lang', lang);

    // Translate text/innerHTML targets
    document.querySelectorAll('[data-i18n]').forEach(function (el) {
      var key = el.getAttribute('data-i18n');
      var val = lookup(key, lang);
      if (val != null) el.innerHTML = val;
    });

    // Translate attribute targets: data-i18n-attr="placeholder:key,title:key2"
    document.querySelectorAll('[data-i18n-attr]').forEach(function (el) {
      var spec = el.getAttribute('data-i18n-attr');
      spec.split(',').forEach(function (pair) {
        var bits = pair.split(':');
        if (bits.length !== 2) return;
        var attr = bits[0].trim();
        var key = bits[1].trim();
        var val = lookup(key, lang);
        if (val != null) el.setAttribute(attr, val);
      });
    });

    // Update <title> via data-i18n-title on <html> or <body>
    var titleKey = document.documentElement.getAttribute('data-i18n-title') ||
                   (document.body && document.body.getAttribute('data-i18n-title'));
    if (titleKey) {
      var t = lookup(titleKey, lang);
      if (t) document.title = t.replace(/<[^>]+>/g, '');
    }

    // Update picker label
    var label = document.querySelector('.freshli-lang-current-label');
    if (label) label.textContent = meta.flag + ' ' + meta.native;

    // Update aria-label on picker
    var picker = document.querySelector('.freshli-lang-picker');
    if (picker) {
      var navLangLabel = lookup('nav.language', lang) || 'Language';
      picker.setAttribute('aria-label', navLangLabel);
    }

    // Dispatch event for any page-specific code
    window.dispatchEvent(new CustomEvent('freshli:langchange', { detail: { lang: lang } }));
  }

  /* -------- Language picker UI -------- */
  function injectStyles() {
    if (document.getElementById('freshli-i18n-styles')) return;
    var css = `
      .freshli-lang-picker { position: relative; display: inline-flex; align-items: center; margin-left: 16px; }
      .freshli-lang-picker button.freshli-lang-toggle {
        display: inline-flex; align-items: center; gap: 6px;
        background: rgba(34, 197, 94, 0.08); border: 1px solid rgba(34, 197, 94, 0.2);
        color: #166534; font-weight: 600; font-size: 13px;
        padding: 8px 12px; border-radius: 100px; cursor: pointer;
        font-family: inherit; transition: all 0.2s ease;
      }
      .freshli-lang-picker button.freshli-lang-toggle:hover {
        background: rgba(34, 197, 94, 0.14); transform: translateY(-1px);
      }
      .freshli-lang-picker button.freshli-lang-toggle::after {
        content: '▾'; font-size: 10px; opacity: 0.6; margin-left: 2px;
      }
      .freshli-lang-menu {
        position: absolute; top: calc(100% + 8px); right: 0; z-index: 200;
        min-width: 200px; max-height: 70vh; overflow-y: auto;
        background: rgba(255,255,255,0.98); backdrop-filter: blur(24px) saturate(180%);
        -webkit-backdrop-filter: blur(24px) saturate(180%);
        border: 1px solid rgba(0,0,0,0.08); border-radius: 16px;
        box-shadow: 0 12px 48px rgba(0,0,0,0.15), 0 2px 8px rgba(0,0,0,0.05);
        padding: 6px; opacity: 0; visibility: hidden; transform: translateY(-4px);
        transition: opacity 0.18s ease, transform 0.18s ease, visibility 0.18s;
      }
      .freshli-lang-picker.open .freshli-lang-menu {
        opacity: 1; visibility: visible; transform: translateY(0);
      }
      .freshli-lang-menu button {
        display: flex; align-items: center; gap: 10px;
        width: 100%; text-align: left; background: transparent; border: 0;
        padding: 10px 12px; border-radius: 10px; cursor: pointer;
        font-family: inherit; font-size: 14px; color: #1F2937; font-weight: 500;
        transition: background 0.12s ease;
      }
      .freshli-lang-menu button:hover { background: rgba(34, 197, 94, 0.08); }
      .freshli-lang-menu button.active { background: rgba(34, 197, 94, 0.14); color: #166534; font-weight: 700; }
      .freshli-lang-menu button .flag { font-size: 18px; }
      .freshli-lang-menu button .native { flex: 1; }
      .freshli-lang-menu button .check { opacity: 0; color: #22C55E; font-weight: 900; }
      .freshli-lang-menu button.active .check { opacity: 1; }

      html[dir="rtl"] .freshli-lang-picker { margin-left: 0; margin-right: 16px; }
      html[dir="rtl"] .freshli-lang-menu { right: auto; left: 0; text-align: right; }
      html[dir="rtl"] .freshli-lang-menu button { text-align: right; }
      html[dir="rtl"] body { text-align: right; }
      html[dir="rtl"] nav .inner { flex-direction: row-reverse; }

      @media (max-width: 640px) {
        .freshli-lang-picker { margin-left: 8px; }
        .freshli-lang-picker button.freshli-lang-toggle { padding: 7px 10px; font-size: 12px; }
        .freshli-lang-menu { right: -8px; min-width: 180px; }
      }
    `;
    var style = document.createElement('style');
    style.id = 'freshli-i18n-styles';
    style.textContent = css;
    document.head.appendChild(style);
  }

  function buildPicker(currentLang) {
    var picker = document.createElement('div');
    picker.className = 'freshli-lang-picker';
    picker.setAttribute('aria-label', 'Language');
    var meta = getLangMeta(currentLang);

    var toggle = document.createElement('button');
    toggle.type = 'button';
    toggle.className = 'freshli-lang-toggle';
    toggle.setAttribute('aria-haspopup', 'listbox');
    toggle.setAttribute('aria-expanded', 'false');
    toggle.innerHTML = '<span class="freshli-lang-current-label">' + meta.flag + ' ' + escapeHtml(meta.native) + '</span>';

    var menu = document.createElement('div');
    menu.className = 'freshli-lang-menu';
    menu.setAttribute('role', 'listbox');

    SUPPORTED.forEach(function (lang) {
      var btn = document.createElement('button');
      btn.type = 'button';
      btn.setAttribute('role', 'option');
      btn.setAttribute('data-lang-code', lang.code);
      if (lang.code === currentLang) btn.classList.add('active');
      btn.innerHTML =
        '<span class="flag">' + lang.flag + '</span>' +
        '<span class="native">' + escapeHtml(lang.native) + '</span>' +
        '<span class="check">✓</span>';
      btn.addEventListener('click', function () {
        setLanguage(lang.code);
        picker.classList.remove('open');
        toggle.setAttribute('aria-expanded', 'false');
      });
      menu.appendChild(btn);
    });

    toggle.addEventListener('click', function (e) {
      e.stopPropagation();
      var isOpen = picker.classList.toggle('open');
      toggle.setAttribute('aria-expanded', String(isOpen));
    });

    document.addEventListener('click', function (e) {
      if (!picker.contains(e.target)) {
        picker.classList.remove('open');
        toggle.setAttribute('aria-expanded', 'false');
      }
    });

    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape') {
        picker.classList.remove('open');
        toggle.setAttribute('aria-expanded', 'false');
      }
    });

    picker.appendChild(toggle);
    picker.appendChild(menu);
    return picker;
  }

  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  function mountPicker(currentLang) {
    // Prefer an explicit slot (<div data-lang-picker></div>), otherwise place
    // inside the <nav .inner> next to the existing CTA/back link.
    var slot = document.querySelector('[data-lang-picker]');
    var picker = buildPicker(currentLang);
    if (slot) {
      slot.innerHTML = '';
      slot.appendChild(picker);
      return;
    }
    var navInner = document.querySelector('nav .inner');
    if (navInner) {
      navInner.appendChild(picker);
      return;
    }
    // Last resort: stick at top-right of body
    picker.style.position = 'fixed';
    picker.style.top = '16px';
    picker.style.right = '16px';
    picker.style.zIndex = '1000';
    document.body.appendChild(picker);
  }

  /* -------- Public API -------- */
  function setLanguage(code) {
    if (!isSupported(code)) code = DEFAULT_LANG;
    try { localStorage.setItem(STORAGE_KEY, code); } catch (_) {}

    // If translation bundle for this language hasn't loaded yet, try to load it.
    if (!(window.__freshliTranslations && window.__freshliTranslations[code])) {
      loadBundle(code, function () {
        applyTranslations(code);
        refreshPickerActive(code);
      });
    } else {
      applyTranslations(code);
      refreshPickerActive(code);
    }
  }

  function refreshPickerActive(code) {
    document.querySelectorAll('.freshli-lang-menu button[data-lang-code]').forEach(function (b) {
      b.classList.toggle('active', b.getAttribute('data-lang-code') === code);
    });
  }

  function loadBundle(code, cb) {
    var basePath = getBasePath();
    var script = document.createElement('script');
    script.src = basePath + 'i18n/' + code + '.js';
    script.async = true;
    script.onload = function () { if (cb) cb(); };
    script.onerror = function () {
      console.warn('[freshli-i18n] failed to load', code, '- falling back to English');
      if (cb) cb();
    };
    document.head.appendChild(script);
  }

  function getBasePath() {
    // Works whether the page is at / or /some/path/
    var path = window.location.pathname;
    if (path.indexOf('.html') !== -1 || path.endsWith('/')) {
      return path.replace(/[^/]*$/, '');
    }
    return '/';
  }

  /* -------- Init -------- */
  function init() {
    injectStyles();
    var lang = detectLanguage();
    mountPicker(lang);

    // If English bundle isn't loaded yet, trust that it is loaded as a
    // <script src="i18n/en.js"> on the page. If not present, load it.
    var hasEn = window.__freshliTranslations && window.__freshliTranslations.en;
    if (!hasEn) {
      loadBundle('en', function () {
        if (lang !== 'en' && !(window.__freshliTranslations[lang])) {
          loadBundle(lang, function () { applyTranslations(lang); });
        } else {
          applyTranslations(lang);
        }
      });
    } else {
      if (lang !== 'en' && !(window.__freshliTranslations[lang])) {
        loadBundle(lang, function () { applyTranslations(lang); });
      } else {
        applyTranslations(lang);
      }
    }
  }

  // Expose public API
  window.Freshli = window.Freshli || {};
  window.Freshli.i18n = {
    setLanguage: setLanguage,
    getLanguage: function () { return document.documentElement.getAttribute('lang') || DEFAULT_LANG; },
    supportedLanguages: SUPPORTED.map(function (l) { return { code: l.code, name: l.name, native: l.native, flag: l.flag }; }),
    translate: function (key) { return lookup(key, this.getLanguage()); },
    reapply: function () { applyTranslations(this.getLanguage()); }
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
