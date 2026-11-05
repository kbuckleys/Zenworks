// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/

.pragma library
// ONE COPY FOR THE WHOLE SHELL (see morpheus/icons.js). No imports: the node
// tests load it as it is.

// ── CYNOSURE'S SMART ANSWERS (2026-11-01) ──────────────────────────────────
// A line in plain words answered in the list itself, as a card above it, the
// calculator's way: the weather somewhere, the time, the battery, a coin
// flipped. This file only READS the line — what was asked, and of where —
// and works out the answers that need nothing but arithmetic; the card and
// the asking of the world (a forecast, the battery) are CynosurePopup's.

const WEEKDAYS = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"];
const MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August",
  "September", "October", "November", "December"];

function clean(q) {
  return String(q || "").trim().toLowerCase().replace(/[?!.]+$/, "").replace(/\s+/g, " ");
}

// ── THE WEATHER ────────────────────────────────────────────────────────────
// "cairo weather", "weather in paris tomorrow", "will it rain", "is it
// raining in london", "sunset", "how hot is it in dubai". Back: where (""
// is here), which day ("" today, "tomorrow", a weekday), and what about it
// (`focus`: weather, rain, sun, temp, wind); null when it is not about the
// weather at all — a word that only might be ("cold" in "cold brew") is not
// enough without a weather word proper.
const WX_WORDS = /\b(weather|forecast|temperature|rain|raining|rainy|umbrella|snow|snowing|sunrise|sunset|humidity|humid|windy|wind)\b/;
const WX_HOW = /^how (hot|cold|warm|windy|humid) (is it|will it be)\b/;
const WX_FILLER = new Set(("weather forecast temperature temp rain raining rainy umbrella snow snowing sunrise "
  + "sunset humidity humid windy wind hot cold warm what whats what's how is it it's its will be going to "
  + "the in for at of do does i need an a like outside right now there any chance today tonight tomorrow "
  + "this week weekend me when s gonna will's on by near").split(" "));

function parseWeather(q) {
  const s = clean(q);
  if (s === "" || !(WX_WORDS.test(s) || WX_HOW.test(s))) return null;
  const words = s.replace(/[,']/g, " ").split(" ").filter((w) => w !== "");
  let day = "";
  for (const w of words) {
    if (w === "tomorrow") day = "tomorrow";
    else if (WEEKDAYS.indexOf(w) >= 0) day = w;
  }
  const focus = /\b(rain|raining|rainy|umbrella|snow|snowing)\b/.test(s) ? "rain"
    : /\b(sunrise|sunset)\b/.test(s) ? "sun"
    : /\b(temperature|hot|cold|warm)\b/.test(s) ? "temp"
    : /\b(wind|windy)\b/.test(s) ? "wind" : "weather";
  const place = words.filter((w) => !WX_FILLER.has(w) && WEEKDAYS.indexOf(w) < 0).join(" ");
  return { place, day, focus };
}

// days from today to `day` ("" today, "tomorrow", a weekday's next one, today
// itself when it is that weekday)
function dayOffset(day, now) {
  if (!day) return 0;
  if (day === "tomorrow") return 1;
  const i = WEEKDAYS.indexOf(day);
  if (i < 0) return 0;
  return (i - (now || new Date()).getDay() + 7) % 7;
}

// ── EVERYTHING ELSE ────────────────────────────────────────────────────────
// Back: { kind, … } or null. The ones only arithmetic answers (the time, a
// coin, dice, a number, a uuid) are answered by answerOf; the battery, the
// addresses and the uptime are asked of the machine by the popup; a word's
// meaning goes on to lexi.
// "what's on friday", "agenda", "am i free tomorrow", "meetings this week":
// the opening words that may stand alone (m[1]) — "calendar", "events" and
// "meetings" only with a day after them, or they would hide the apps
const CAL_DAYS = "today|tonight|tomorrow|this week|the week|" + WEEKDAYS.join("|");
const CAL_ASK = new RegExp("^(?:(what(?:'?s| is) on|what do i have|am i (?:free|busy)|(?:my )?(?:agenda|schedule))"
  + "|(?:my )?(?:calendar|events|meetings|appointments))(?: (?:my )?(?:calendar|schedule))?(?: (?:for|on))?"
  + "(?: (" + CAL_DAYS + "))?$");
function calSpan(day) {
  if (!day || day === "today" || day === "tonight") return "today";
  if (/week/.test(day)) return "week";
  return day;
}
function isoDay(d) {
  return d.getFullYear() + "-" + two(d.getMonth() + 1) + "-" + two(d.getDate());
}
function addDays(d, n) {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate() + n);
}
// the dates to ask khal for: { from, to } (to not included)
function calRange(ask, now) {
  const d = now || new Date();
  const span = ask.span;
  if (span === "next") return { from: isoDay(d), to: isoDay(addDays(d, 60)) };
  if (span === "week") return { from: isoDay(d), to: isoDay(addDays(d, 7)) };
  const off = span === "today" ? 0 : dayOffset(span, d);
  return { from: isoDay(addDays(d, off)), to: isoDay(addDays(d, off + 1)) };
}
function calWhen(e) {
  if (e.allDay) return "All day";
  return e.end && e.endDate === e.date && e.end !== e.start ? e.start + " \u2013 " + e.end : e.start;
}
function calDayName(iso, now) {
  const p = String(iso).split("-").map(Number);
  const day = new Date(p[0], p[1] - 1, p[2]);
  const diff = Math.round((day - new Date(now.getFullYear(), now.getMonth(), now.getDate())) / 86400000);
  if (diff === 0) return "Today";
  if (diff === 1) return "Tomorrow";
  return cap(WEEKDAYS[day.getDay()]) + (diff < 7 ? "" : " " + day.getDate() + " " + MONTHS[day.getMonth()]);
}
function calMs(e) {
  const p = String(e.date).split("-").map(Number);
  const t = e.allDay ? [0, 0] : String(e.start || "00:00").split(":").map(Number);
  return new Date(p[0], p[1] - 1, p[2], t[0] || 0, t[1] || 0).getTime();
}
// cal.py list's JSON, as the card: { big, small, day } (day: the ISO date
// the calendar window opens on)
function calAnswer(text, ask, now) {
  const d = now || new Date();
  let events;
  try {
    const j = JSON.parse(String(text || ""));
    // khal's own words are for a terminal: no config yet is the usual one
    if (j.error) return { big: "No calendar", small: /config/i.test(String(j.error))
      ? "Set one up in Chronos" : "Chronos' calendar could not be read" };
    events = Array.isArray(j.events) ? j.events : [];
  } catch (e) { return { big: "No calendar", small: "Chronos' calendar could not be read" }; }
  events = events.slice().sort((a, b) => calMs(a) - calMs(b) || (a.allDay ? -1 : 1));
  if (ask.span === "next") {
    const today = isoDay(d);
    // timed ones not yet started; all-day ones from tomorrow on
    const e = events.find((x) => x.allDay ? x.date > today : calMs(x) >= d.getTime());
    if (!e) return { big: "Nothing coming up", small: "Nothing on your calendar for two months", day: today };
    const mins = Math.round((calMs(e) - d.getTime()) / 60000);
    const soon = !e.allDay && mins < 120 ? "in " + minutesText(mins) + " \u00B7 " : "";
    return { big: e.title, small: soon + calDayName(e.date, d) + " " + calWhen(e)
      + (e.location ? " \u00B7 " + e.location : ""), day: e.date };
  }
  const r = calRange(ask, d);
  const name = ask.span === "week" ? "This week" : calDayName(r.from, d);
  if (!events.length) return { big: "Nothing on", small: name + " is free", day: r.from };
  const shown = events.slice(0, 3).map((e) => (e.allDay ? "" : e.start + " ") + e.title
    + (ask.span === "week" ? " (" + calDayName(e.date, d) + ")" : ""));
  return { big: shown.join("  \u00B7  "),
    small: name + " \u00B7 " + events.length + (events.length === 1 ? " event" : " events")
      + (events.length > 3 ? ", " + (events.length - 3) + " more" : ""), day: r.from };
}

function parseAsk(q) {
  const s = clean(q);
  if (s === "") return null;
  let m;
  if (/^(what('?s| is)( the)? )?(current |local )?time( is it)?( now| here)?$/.test(s) || s === "what time is it")
    return { kind: "time" };
  if (/^(what('?s| is)( the)? )?(today'?s )?date( today)?$/.test(s) || /^what day is (it|today)$/.test(s)
      || s === "today's date" || s === "what's today")
    return { kind: "date" };
  if (/^(what('?s| is)( the)? )?(which )?week( number)?( is it)?( today)?$/.test(s) && s !== "week")
    return { kind: "week" };
  // the calendar (chronos' khal): what is next, what is on a day or the week
  if (/^(what('?s| is) )?(my )?next (meeting|event|appointment|thing on my calendar)$/.test(s)
      || /^what('?s| is) next( on my calendar)?$/.test(s))
    return { kind: "cal", span: "next" };
  if ((m = CAL_ASK.exec(s)) && (m[1] || m[2]))
    return { kind: "cal", span: calSpan(m[2]) };
  if (/^(flip|toss)( a)? coin$/.test(s) || s === "coin flip" || s === "coin toss" || s === "heads or tails")
    return { kind: "coin" };
  if ((m = /^(roll )?(a |an |(\d+) ?)?(dice|die|d(\d+))$/.exec(s)) && (m[1] || m[5] || m[4] === "dice" || m[2]))
    return { kind: "dice", n: Math.min(20, parseInt(m[3] || "1", 10)), sides: Math.min(1000, parseInt(m[5] || "6", 10)) };
  if ((m = /^roll (\d+)?d(\d+)$/.exec(s)))
    return { kind: "dice", n: Math.min(20, parseInt(m[1] || "1", 10)), sides: Math.min(1000, parseInt(m[2], 10)) };
  if ((m = /^(a )?random( number| integer)?( between| from)? (-?\d+) ?(and|to|-) ?(-?\d+)$/.exec(s)))
    return { kind: "random", lo: Math.min(+m[4], +m[6]), hi: Math.max(+m[4], +m[6]) };
  if (/^(a )?random( number| integer)$/.test(s)) return { kind: "random", lo: 1, hi: 100 };
  if (/^((a |new )?uuid|guid)$/.test(s)) return { kind: "uuid" };
  if (/^(what('?s| is) )?(my )?(local )?ip( address(es)?)?$/.test(s) && /\bip\b/.test(s)) return { kind: "ip" };
  if (/^(how much )?battery( level| left| status| life)?( is left)?$/.test(s) || s === "how much battery")
    return { kind: "battery" };
  if (s === "uptime" || /^how long (have i been|has (it|this|the computer) been) (up|on|running)$/.test(s))
    return { kind: "uptime" };
  // what is in the line itself: a color, something to encode or hash, words
  // to count — read from the line as typed, not lowercased
  const raw = String(q || "").trim();
  if ((m = /^#([0-9a-f]{3}|[0-9a-f]{6})$/i.exec(raw))) return { kind: "color", hex: m[1] };
  if ((m = /^rgba?\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*(?:,\s*[\d.]+\s*)?\)$/i.exec(raw)))
    return { kind: "color", rgb: [+m[1], +m[2], +m[3]] };
  if ((m = /^hsla?\(\s*(\d{1,3})\s*,\s*(\d{1,3})%\s*,\s*(\d{1,3})%\s*(?:,\s*[\d.]+\s*)?\)$/i.exec(raw)))
    return { kind: "color", hsl: [+m[1], +m[2], +m[3]] };
  if ((m = /^base64 decode (.+)$/i.exec(raw)) || (m = /^decode base64 (.+)$/i.exec(raw)))
    return { kind: "b64dec", text: m[1] };
  if ((m = /^base64(?: encode)? (.+)$/i.exec(raw)) || (m = /^encode base64 (.+)$/i.exec(raw)))
    return { kind: "b64enc", text: m[1] };
  if ((m = /^url ?decode (.+)$/i.exec(raw))) return { kind: "urldec", text: m[1] };
  if ((m = /^url ?encode (.+)$/i.exec(raw))) return { kind: "urlenc", text: m[1] };
  if ((m = /^(md5|sha1|sha256|sha512) (.+)$/i.exec(raw))) return { kind: "hash", algo: m[1].toLowerCase(), text: m[2] };
  if ((m = /^count (.+)$/i.exec(raw))) return { kind: "count", text: m[1] };
  // a QR code of the rest (2026-11-03; "qr scan" reads one: parseCommand)
  if ((m = /^qr(?: ?code)? (.+)$/i.exec(raw)) && !/^(scan|read)$/i.test(m[1].trim())) return { kind: "qr", text: m[1] };
  // how fast the connection is: Cloudflare's speed endpoints through curl
  if (/^(?:run (?:a )?)?(?:internet |network |connection )?speed ?test$|^how fast is (?:my|the) (?:internet|connection)$/.test(s))
    return { kind: "speed" };
  if (/^lorem( ipsum)?$/.test(s)) return { kind: "lorem" };
  if (/^(unix|epoch)( time| timestamp)?( now)?$|^(current )?timestamp$/.test(s)) return { kind: "unix" };
  if ((m = /^(?:epoch|unix|timestamp) (\d{9,13})$/.exec(s)) || (m = /^(\d{10}|\d{13})$/.exec(s)))
    return { kind: "fromunix", secs: m[1].length === 13 ? Math.floor(+m[1] / 1000) : +m[1] };
  if (/^(what('?s| is) the )?moon( phase)?( tonight| today)?$/.test(s)) return { kind: "moon" };
  if (/^(how much )?(memory|ram)( used| free| left| usage)?$/.test(s)) return { kind: "memory" };
  if (/^(how much )?(disk|storage)( space| left| free| usage)?$|^how full is (my|the) disk$/.test(s)) return { kind: "disk" };
  if (/^(cpu|load|cpu load|cpu usage)$/.test(s)) return { kind: "cpu" };
  if (/^(kernel|kernel version|linux version)$/.test(s)) return { kind: "kernel" };
  if (/^(hostname|computer name|my hostname)$/.test(s)) return { kind: "hostname" };
  if (/^(wifi|wi-fi|which (wifi|wi-fi|network)( am i on)?|my network|network name|ssid)$/.test(s)) return { kind: "wifi" };
  if (/^(what('?s| is) playing|now playing|current song|what song is this|song)$/.test(s)) return { kind: "playing" };
  // screen time, from Kairos (2026-11-02): "screen time", "screen time this
  // week", "how long on firefox today"
  if ((m = /^(?:my |what(?:'?s| is) my )?screen ?time(?: (today|yesterday|this week|the week|week))?$/.exec(s)))
    return { kind: "screentime", span: /week/.test(m[1] || "") ? "week" : m[1] || "today", app: "" };
  if ((m = /^how (?:long|much time)(?: have i (?:been|spent))?(?: (?:on|in|using) (.+?))(?: (today|yesterday|this week))?$/.exec(s)))
    return { kind: "screentime", span: /week/.test(m[2] || "") ? "week" : m[2] || "today", app: m[1] };
  if ((m = /^what does (\S+) mean$/.exec(s)) || (m = /^(?:the )?meaning of (\S+)$/.exec(s))
      || (m = /^(\S+) meaning$/.exec(s)) || (m = /^define:(\S+)$/.exec(s)))
    return { kind: "define", word: m[1] };
  return null;
}

function two(n) { return (n < 10 ? "0" : "") + n; }

// ISO week number
function isoWeek(d) {
  const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
  const day = t.getUTCDay() || 7;
  t.setUTCDate(t.getUTCDate() + 4 - day);
  const y0 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
  return Math.ceil(((t - y0) / 86400000 + 1) / 7);
}

function cap(s) { return s.charAt(0).toUpperCase() + s.slice(1); }

// The answers arithmetic gives: { big, small } (the card's two lines), or
// null for the kinds the machine has to be asked. `rnd` is Math.random,
// handed in so the tests can fix it.
function answerOf(ask, now, h24, rnd) {
  if (!ask) return null;
  const d = now || new Date();
  const r = rnd || Math.random;
  switch (ask.kind) {
  case "time": {
    const h = d.getHours();
    const big = h24 ? two(h) + ":" + two(d.getMinutes())
      : ((h % 12) || 12) + ":" + two(d.getMinutes()) + (h < 12 ? " am" : " pm");
    return { big, small: cap(WEEKDAYS[d.getDay()]) + " " + d.getDate() + " " + MONTHS[d.getMonth()] };
  }
  case "date":
    return { big: cap(WEEKDAYS[d.getDay()]) + " " + d.getDate() + " " + MONTHS[d.getMonth()] + " " + d.getFullYear(),
      small: "Week " + isoWeek(d) };
  case "week":
    return { big: "Week " + isoWeek(d), small: d.getFullYear() + "" };
  case "coin":
    return { big: r() < 0.5 ? "Heads" : "Tails", small: "A coin, flipped" };
  case "dice": {
    const rolls = [];
    for (let i = 0; i < ask.n; ++i) rolls.push(1 + Math.floor(r() * ask.sides));
    const sum = rolls.reduce((a, b) => a + b, 0);
    return { big: String(ask.n > 1 ? sum : rolls[0]),
      small: ask.n + "d" + ask.sides + (ask.n > 1 ? " · " + rolls.join(" + ") : "") };
  }
  case "random":
    return { big: String(ask.lo + Math.floor(r() * (ask.hi - ask.lo + 1))),
      small: "Between " + ask.lo + " and " + ask.hi };
  case "color": {
    const rgb = ask.rgb || (ask.hsl ? hslToRgb(ask.hsl) : hexToRgb(ask.hex));
    const hex = "#" + rgb.map((v) => two16(v)).join("").toUpperCase();
    const hsl = rgbToHsl(rgb);
    return { big: hex, small: "rgb(" + rgb.join(", ") + ") · hsl(" + hsl[0] + ", " + hsl[1] + "%, " + hsl[2] + "%)",
      color: hex };
  }
  case "b64enc": return { big: b64encode(ask.text), small: "Base64 of \u201C" + short(ask.text) + "\u201D" };
  case "b64dec": {
    const t = b64decode(ask.text);
    return t === null ? { big: "Not base64", small: short(ask.text) } : { big: t, small: "Decoded from base64" };
  }
  case "urlenc": return { big: encodeURIComponent(ask.text), small: "Encoded for a URL" };
  case "urldec": {
    let t = null;
    try { t = decodeURIComponent(ask.text); } catch (e) {}
    return t === null ? { big: "Not URL-encoded", small: short(ask.text) } : { big: t, small: "Decoded from a URL" };
  }
  case "count": {
    const t = ask.text;
    const words = t.trim() === "" ? 0 : t.trim().split(/\s+/).length;
    return { big: words + (words === 1 ? " word" : " words"), small: Array.from(t).length + " characters" };
  }
  case "lorem":
    return { big: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
      small: "Filler text" };
  case "unix":
    return { big: String(Math.floor(d.getTime() / 1000)), small: "Seconds since 1970, now" };
  case "fromunix": {
    const t = new Date(ask.secs * 1000);
    return { big: cap(WEEKDAYS[t.getDay()]) + " " + t.getDate() + " " + MONTHS[t.getMonth()] + " " + t.getFullYear()
      + ", " + two(t.getHours()) + ":" + two(t.getMinutes()), small: ask.secs + " seconds since 1970" };
  }
  case "moon": {
    const p = moonPhase(d);
    return { big: p.name, small: Math.round(p.lit * 100) + "% lit", glyph: p.glyph };
  }
  case "uuid": {
    const hex = (n) => { let o = ""; for (let i = 0; i < n; ++i) o += Math.floor(r() * 16).toString(16); return o; };
    const v = (8 + Math.floor(r() * 4)).toString(16);
    return { big: hex(8) + "-" + hex(4) + "-4" + hex(3) + "-" + v + hex(3) + "-" + hex(12), small: "A random UUID" };
  }
  }
  return null;
}

function short(t) { const s = String(t); return s.length > 40 ? s.slice(0, 39) + "\u2026" : s; }
function two16(v) { const h = Math.max(0, Math.min(255, Math.round(v))).toString(16); return h.length < 2 ? "0" + h : h; }
function hexToRgb(h) {
  const x = h.length === 3 ? h.split("").map((c) => c + c).join("") : h;
  return [parseInt(x.slice(0, 2), 16), parseInt(x.slice(2, 4), 16), parseInt(x.slice(4, 6), 16)];
}
function rgbToHsl(rgb) {
  const [r, g, b] = rgb.map((v) => Math.min(255, v) / 255);
  const mx = Math.max(r, g, b), mn = Math.min(r, g, b), l = (mx + mn) / 2;
  let h = 0, s = 0;
  if (mx !== mn) {
    const d = mx - mn;
    s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
    h = mx === r ? (g - b) / d + (g < b ? 6 : 0) : mx === g ? (b - r) / d + 2 : (r - g) / d + 4;
    h *= 60;
  }
  return [Math.round(h), Math.round(s * 100), Math.round(l * 100)];
}
function hslToRgb(hsl) {
  const h = (hsl[0] % 360) / 360, s = Math.min(100, hsl[1]) / 100, l = Math.min(100, hsl[2]) / 100;
  if (s === 0) return [l, l, l].map((v) => Math.round(v * 255));
  const q = l < 0.5 ? l * (1 + s) : l + s - l * s, p = 2 * l - q;
  const f = (t) => { t = (t + 1) % 1; return t < 1 / 6 ? p + (q - p) * 6 * t : t < 1 / 2 ? q : t < 2 / 3 ? p + (q - p) * (2 / 3 - t) * 6 : p; };
  return [f(h + 1 / 3), f(h), f(h - 1 / 3)].map((v) => Math.round(v * 255));
}
// ── A COLOR IN EVERY FORM (2026-11-03) ──────────────────────────────────
// "colors": what a picked color is in each form you might paste it as —
// [name, text]; the first is the hex. Hyprland's and Qt's are the suite's
// own config forms.
function colorForms(hex) {
  const h = String(hex || "").replace(/^#/, "");
  const rgb = hexToRgb(h);
  const [r, g, b] = rgb;
  const hsl = rgbToHsl(rgb);
  const mx = Math.max(r, g, b) / 255, mn = Math.min(r, g, b) / 255;
  const hsv = [hsl[0], Math.round(mx === 0 ? 0 : (mx - mn) / mx * 100), Math.round(mx * 100)];
  const k = 1 - mx;
  const cmyk = k >= 1 ? [0, 0, 0, 100] : [r, g, b].map((v) => Math.round((1 - v / 255 - k) / (1 - k) * 100)).concat([Math.round(k * 100)]);
  const ok = oklch(rgb);
  const f3 = (v) => Math.round(v / 255 * 1000) / 1000;
  return [
    ["Hex", "#" + h.toUpperCase()],
    ["RGB", "rgb(" + rgb.join(", ") + ")"],
    ["HSL", "hsl(" + hsl[0] + ", " + hsl[1] + "%, " + hsl[2] + "%)"],
    ["HSB", "hsb(" + hsv[0] + ", " + hsv[1] + "%, " + hsv[2] + "%)"],
    ["OKLCH", "oklch(" + ok[0] + "% " + ok[1] + " " + ok[2] + ")"],
    ["CMYK", "cmyk(" + cmyk.map((v) => v + "%").join(", ") + ")"],
    ["Hyprland", "rgb(" + h.toLowerCase() + ")"],
    ["Qt", "Qt.rgba(" + f3(r) + ", " + f3(g) + ", " + f3(b) + ", 1)"]
  ];
}
// sRGB → OKLab → LCh: lightness in %, chroma to three places, hue in degrees
function oklch(rgb) {
  const lin = rgb.map((v) => { const c = v / 255; return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); });
  const l = Math.cbrt(0.4122214708 * lin[0] + 0.5363325363 * lin[1] + 0.0514459929 * lin[2]);
  const m = Math.cbrt(0.2119034982 * lin[0] + 0.6806995451 * lin[1] + 0.1073969566 * lin[2]);
  const s = Math.cbrt(0.0883024619 * lin[0] + 0.2817188376 * lin[1] + 0.6299787005 * lin[2]);
  const L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s;
  const A = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
  const B = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;
  const C = Math.sqrt(A * A + B * B);
  let H = Math.atan2(B, A) * 180 / Math.PI;
  if (H < 0) H += 360;
  return [Math.round(L * 1000) / 10, Math.round(C * 1000) / 1000, C < 0.0005 ? 0 : Math.round(H * 10) / 10];
}

// base64 of the text's UTF-8, and back (no Qt.btoa: the tests run in node)
const B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
function utf8(t) { return unescape(encodeURIComponent(t)); }
function b64encode(t) {
  const s = utf8(t);
  let o = "";
  for (let i = 0; i < s.length; i += 3) {
    const a = s.charCodeAt(i), b = s.charCodeAt(i + 1), c = s.charCodeAt(i + 2);
    const n = (a << 16) | ((b || 0) << 8) | (c || 0);
    o += B64[n >> 18 & 63] + B64[n >> 12 & 63] + (i + 1 < s.length ? B64[n >> 6 & 63] : "=") + (i + 2 < s.length ? B64[n & 63] : "=");
  }
  return o;
}
function b64decode(t) {
  const s = String(t).replace(/\s+/g, "");
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(s) || s.length % 4 === 1) return null;
  let bin = "";
  let buf = 0, bits = 0;
  for (const ch of s.replace(/=+$/, "")) {
    buf = (buf << 6) | B64.indexOf(ch); bits += 6;
    if (bits >= 8) { bits -= 8; bin += String.fromCharCode((buf >> bits) & 255); }
  }
  try { return decodeURIComponent(escape(bin)); } catch (e) { return null; }
}
// the moon's age in its 29.53-day month, from a known new moon (6 Jan 2000)
function moonPhase(d) {
  const syn = 29.530588853;
  const age = (((d.getTime() - Date.UTC(2000, 0, 6, 18, 14)) / 86400000) % syn + syn) % syn;
  const lit = (1 - Math.cos(2 * Math.PI * age / syn)) / 2;
  const names = ["New moon", "Waxing crescent", "First quarter", "Waxing gibbous", "Full moon",
    "Waning gibbous", "Last quarter", "Waning crescent"];
  const glyphs = ["\uE38D", "\uE390", "\uE394", "\uE397", "\uE39B", "\uE39E", "\uE3A2", "\uE3A5"];
  const i = Math.floor((age / syn) * 8 + 0.5) % 8;
  return { name: names[i], lit, glyph: glyphs[i] };
}

// The card's heading for a kind
function titleOf(kind) {
  return { time: "Time", date: "Date", week: "Week", coin: "Coin", dice: "Dice", random: "Random number",
    uuid: "UUID", ip: "Network", screentime: "Screen time", battery: "Battery", uptime: "Uptime", weather: "Weather", color: "Color",
    b64enc: "Base64", b64dec: "Base64", urlenc: "URL", urldec: "URL", hash: "Hash", count: "Count",
    lorem: "Lorem ipsum", unix: "Unix time", fromunix: "Unix time", moon: "Moon", memory: "Memory",
    disk: "Disk", cpu: "CPU", kernel: "Kernel", hostname: "Hostname", wifi: "Wi-Fi", playing: "Now playing",
    cal: "Calendar", qr: "QR code", speed: "Speed test" }[kind] || "Answer";
}

// ── more of the machine's answers ───────────────────────────────────────────
// KiB, as /proc/meminfo has them — Sysmon's, live while the card is up
function memAnswer(total, avail) {
  if (!total) return null;
  const used = total - avail;
  return { big: gib(used) + " of " + gib(total), small: Math.round(used / total * 100) + "% in use · " + gib(avail) + " free" };
}
function gib(kb) { const g = kb / 1048576; return (g >= 10 ? Math.round(g) : Math.round(g * 10) / 10) + " GB"; }
// df -kP / (the second line)
function parseDf(text) {
  const line = String(text || "").trim().split("\n")[1] || "";
  const f = line.split(/\s+/);
  if (f.length < 6) return null;
  const size = +f[1], used = +f[2], avail = +f[3];
  return { big: gib(avail) + " free", small: gib(used) + " of " + gib(size) + " used · " + f[4] + " full",
    level: size > 0 ? used / size : 0 };
}
// Sysmon's: how busy (0..100), the one-minute load, and the threads
function cpuAnswer(pct, load, threads) {
  const n = threads || 1;
  return { big: Math.round(pct) + "% busy",
    small: (load === null || load === undefined ? "" : "Load " + (Math.round(load * 100) / 100) + " · ")
      + n + (n === 1 ? " thread" : " threads") };
}

// ── the machine's answers, read off what it printed ────────────────────────
// `ip -4 -o addr show scope global`: "2: wlan0    inet 192.168.1.4/24 …"
function parseAddrs(text) {
  const out = [];
  for (const line of String(text || "").split("\n")) {
    const m = /^\d+:\s+(\S+)\s+inet6?\s+([0-9a-f.:]+)\//i.exec(line.trim());
    if (m) out.push({ dev: m[1], addr: m[2] });
  }
  return out;
}

// /sys/class/power_supply/BAT*/{capacity,status}, printed "84 Charging"
function parseBattery(text) {
  const m = /^(\d+)\s+(\S+)/.exec(String(text || "").trim());
  if (!m) return null;
  const st = m[2].toLowerCase();
  return { big: m[1] + "%", small: st === "charging" ? "Charging" : st === "full" ? "Full"
    : st === "discharging" ? "On battery" : cap(st), level: Math.min(100, +m[1]) / 100 };
}

// /proc/uptime's first number, in seconds
function uptimeText(secs) {
  const s = Math.floor(Number(secs) || 0);
  const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
  const parts = [];
  if (d) parts.push(d + (d === 1 ? " day" : " days"));
  if (h) parts.push(h + (h === 1 ? " hour" : " hours"));
  if (!d && m) parts.push(m + (m === 1 ? " minute" : " minutes"));
  return parts.length ? parts.join(", ") : "Less than a minute";
}

// the next meeting worth joining (2026-11-03): from cal.py's events (start
// and end as ISO strings), the first not yet over, all-day ones aside, with
// a call's link in its url, location or description. → { title, url } or null
const CALL_LINK = /https:\/\/(?:[\w-]+\.)*(?:zoom\.us|meet\.google\.com|teams\.microsoft\.com|teams\.live\.com|whereby\.com|meet\.jit\.si|webex\.com|discord\.gg|gather\.town|around\.co)\/[^\s<>"')]*/i;
function nextMeeting(events, now) {
  const t = now.getTime();
  const list = (events || []).filter((e) => !e.allDay && Date.parse(e.end || e.start) > t)
    .sort((a, b) => Date.parse(a.start) - Date.parse(b.start));
  for (const e of list) {
    const m = CALL_LINK.exec([e.url, e.location, e.description].filter((x) => x).join(" "));
    // a sentence's own full stop is not the link's
    if (m) return { title: e.title || "", url: m[0].replace(/[.,;:!?]+$/, "") };
  }
  return null;
}

// curl's own measures: "<down B/s> <connect s> <lookup s> <up B/s>"
function parseSpeed(text) {
  const f = String(text || "").trim().split(/\s+/).map(Number);
  if (f.length < 4 || !(f[0] > 0)) return null;
  const mbps = (b) => { const v = b * 8 / 1e6; return (v >= 100 ? Math.round(v) : Math.round(v * 10) / 10) + " Mbps"; };
  const ping = Math.max(0, Math.round((f[1] - f[2]) * 1000));
  return { big: mbps(f[0]) + " down", small: (f[3] > 0 ? mbps(f[3]) + " up \u00B7 " : "") + ping + " ms ping" };
}

// ── open-meteo's place search ──────────────────────────────────────────────
function geocodeUrl(place) {
  return "https://geocoding-api.open-meteo.com/v1/search?count=1&language=en&format=json&name="
    + encodeURIComponent(place);
}
function parseGeocode(text) {
  try {
    const j = JSON.parse(text);
    const r = (j.results || [])[0];
    if (!r) return null;
    return { lat: r.latitude, lon: r.longitude,
      name: r.name + (r.country ? ", " + r.country : "") };
  } catch (e) { return null; }
}

// ── COMMANDS THAT TAKE AN ARGUMENT (2026-11-01) ─────────────────────────────
// "volume 30", "brightness up", "timer 25m tea", "wifi off", "kill firefox",
// "workspace 3", "next", a URL: what to do and to what. Back: { kind, … } or
// null; the popup says it in a row first in the list and does it on return
// (a process ended asks first).
function parseCommand(q) {
  const s = clean(q);
  if (s === "") return null;
  let m;
  const pct = (n) => Math.max(0, Math.min(100, parseInt(n, 10)));
  if ((m = /^(?:set )?(?:the )?(?:volume|vol|sound)(?: to)? (\d{1,3})%?$/.exec(s))) return { kind: "volume", pct: pct(m[1]) };
  if ((m = /^(?:turn )?(?:the )?(?:volume|vol|sound) (up|down)$|^(louder|quieter)$/.exec(s)))
    return { kind: "volume", step: (m[1] || m[2]) === "up" || m[2] === "louder" ? 10 : -10 };
  if (/^(mute|silence)( the)?( sound| volume| audio)?$/.test(s)) return { kind: "mute", on: true };
  if (/^unmute( the)?( sound| volume| audio)?$/.test(s)) return { kind: "mute", on: false };
  if ((m = /^(?:set )?(?:the )?(?:brightness|bright|screen)(?: to)? (\d{1,3})%?$/.exec(s))) return { kind: "brightness", pct: Math.max(1, pct(m[1])) };
  if ((m = /^(?:turn )?(?:the )?(?:brightness|screen) (up|down)$|^(brighter|dimmer)$/.exec(s)))
    return { kind: "brightness", step: (m[1] || m[2]) === "up" || m[2] === "brighter" ? 10 : -10 };
  if ((m = /^(?:turn )?(wi-?fi|wireless|bluetooth|bt|night light|nightlight|do not disturb|dnd)(?: (on|off))$/.exec(s))
      || (m = /^turn (on|off) (?:the )?(wi-?fi|wireless|bluetooth|bt|night light|nightlight|do not disturb|dnd)$/.exec(s))) {
    const what = /^(on|off)$/.test(m[1]) ? m[2] : m[1];
    const on = (/^(on|off)$/.test(m[1]) ? m[1] : m[2]) === "on";
    const kind = /fi|wireless/.test(what) ? "wifi" : /blue|^bt$/.test(what) ? "bluetooth"
      : /night/.test(what) ? "night" : "dnd";
    return { kind, on };
  }
  if (/^(play|resume)( music| the music)?$/.test(s)) return { kind: "media", act: "play" };
  if (/^(pause|stop)( music| the music)?$/.test(s)) return { kind: "media", act: "pause" };
  if (/^(next|skip)( song| track)?$/.test(s)) return { kind: "media", act: "next" };
  if (/^(previous|prev|back)( song| track)$|^previous$/.test(s)) return { kind: "media", act: "previous" };
  if ((m = /^(?:go to |switch to )?(?:workspace|ws|desktop) (\d{1,2})$/.exec(s))) return { kind: "workspace", n: +m[1] };
  // the window you were in, taken there (2026-11-04): "move to workspace 3",
  // "send window to 3", "move window to ws 3"
  if ((m = /^(?:move|send|put)(?: (?:this |the )?window)? to (?:workspace |ws |desktop )?(\d{1,2})$/.exec(s))) return { kind: "moveWs", n: +m[1] };
  // the rest of Raycast's own (2026-11-03): before "quit <app>", which would
  // read "quit all apps" as an app called apps
  if (/^(?:quit|close) (?:all|every|everything)(?: (?:the )?(?:apps|applications|windows))?$/.test(s)) return { kind: "quitAll" };
  if (/^empty (?:the )?(?:trash|bin|wastebasket)$/.test(s)) return { kind: "emptyTrash" };
  if (/^(?:confetti|celebrate|hooray|ta-?da)!*$/.test(s)) return { kind: "confetti" };
  if (/^(?:camera|mirror|webcam|selfie)$/.test(s)) return { kind: "camera" };
  // a contact: its name, and any email and phone number among the words (as typed, not lowered)
  if ((m = /^(?:new|add|make)(?: a)? contact (.+)$/i.exec(String(q || "").trim()))) {
    const words = m[1].split(/\s+/);
    const email = words.find((w) => /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(w)) || "";
    const rest = words.filter((w) => w !== email);
    const at = rest.findIndex((w) => /^\+?[\d(][\d().-]*$/.test(w) && w.replace(/\D/g, "").length >= 2);
    const phone = at >= 0 ? rest.slice(at).join(" ") : "";
    const name = (at >= 0 ? rest.slice(0, at) : rest).join(" ");
    if (name !== "") return { kind: "newContact", name, email, phone };
  }
  if ((m = /^(?:turn on |switch to |use )?(dark|light)(?: mode| theme| appearance)$|^(?:turn on |switch to |use )?(dark|light) mode$/.exec(s)))
    return { kind: "appearance", light: (m[1] || m[2]) === "light" };
  if (/^(?:toggle|switch|flip) (?:the )?(?:appearance|dark mode|light mode|theme mode)$/.test(s)) return { kind: "appearance", toggle: true };
  if (/^eject(?: all| every)?(?: (?:the )?(?:drives?|disks?|usbs?|volumes?))?$/.test(s)) return { kind: "eject" };
  if (/^show (?:the )?desktop$|^(?:go to )?(?:an )?empty workspace$/.test(s)) return { kind: "desktop" };
  if (/^(?:turn )?(?:the )?(?:screens?|displays?|monitors?) off$|^(?:sleep|blank) (?:the )?(?:screens?|displays?|monitors?)$/.test(s))
    return { kind: "screensOff" };
  if (/^(?:clear|wipe|forget|empty) (?:the )?clipboard(?: history)?$/.test(s)) return { kind: "clearClips" };
  if (/^join (?:the |my )?(?:next )?(?:meeting|call|video call)$/.test(s)) return { kind: "joinMeeting" };
  if (/^(?:make (?:the )?(?:window )?)?(?:larger|bigger)$|^(?:grow|enlarge) (?:the )?window$/.test(s)) return { kind: "snap", where: "grow" };
  if (/^(?:make (?:the )?(?:window )?)?smaller$|^shrink (?:the )?window$/.test(s)) return { kind: "snap", where: "shrink" };
  if (/^maximi[sz]e (?:the )?(?:window(?:'s)? )?width$/.test(s)) return { kind: "snap", where: "maxW" };
  if (/^maximi[sz]e (?:the )?(?:window(?:'s)? )?height$/.test(s)) return { kind: "snap", where: "maxH" };
  if (/^(?:toggle )?full ?screen(?: (?:the )?window)?$/.test(s)) return { kind: "fullscreen" };
  if (/^(?:move (?:the )?(?:window )?)?(?:to )?(?:the )?previous (?:screen|monitor|display)$/.test(s)) return { kind: "snap", where: "prev" };
  // a focus session ended, not an app called focus quit
  if (/^(?:end|stop|quit|cancel) (?:the |my )?focus(?: session)?$|^focus (?:off|end|stop)$/.test(s)) return { kind: "focusEnd" };
  if ((m = /^(force )?(?:kill|quit|close|end) (?:all )?([\w.+-]{2,})$/.exec(s))) return { kind: "kill", name: m[2], force: !!m[1] };
  if ((m = /^(?:restart|relaunch|reopen) ([\w.+-]{2,})$/.exec(s))) return { kind: "restart", name: m[1] };
  // focus sessions and apps quit unused (Kairos, 2026-11-03)
  const SPAN = "(\\d+) ?(m|min|mins|minutes?|h|hr|hrs|hours?)";
  const spanMin = (n, u) => +n * (/^h/.test(u) ? 60 : 1);
  if ((m = /^focus (block|allow|unblock|set aside) ([\w.+-]{2,})$/.exec(s)))
    return { kind: "focusBlock", name: m[2], on: m[1] === "block" || m[1] === "set aside" };
  if ((m = new RegExp("^(?:start (?:a )?)?focus(?: session)?(?: for)?(?: " + SPAN + ")?(?: (?:on )?(.+))?$").exec(s)))
    return { kind: "focus", minutes: m[1] ? spanMin(m[1], m[2]) : 25,
      label: m[3] ? m[3].charAt(0).toUpperCase() + m[3].slice(1) : "Focus" };
  if ((m = /^auto ?quit ([\w.+-]{2,}) off$|^(?:never|don'?t) auto ?quit ([\w.+-]{2,})$/.exec(s)))
    return { kind: "autoQuit", name: m[1] || m[2], minutes: 0 };
  if ((m = new RegExp("^auto ?quit ([\\w.+-]{2,})(?: (?:after|when unused for|unused for) " + SPAN + ")?$").exec(s)))
    return { kind: "autoQuit", name: m[1], minutes: m[2] ? spanMin(m[2], m[3]) : 30 };
  // window layouts (2026-11-03): saved, put back, forgotten
  // forgetting them: every layout, and where windows were before they were
  // put somewhere ("restore"'s memory)
  if (/^(?:clear|forget|delete|remove) (?:all )?(?:the |my )?(?:window )?layouts$/.test(s)) return { kind: "layoutsClear" };
  if (/^(?:clear|forget|reset) (?:all )?(?:the )?window (?:places|placements|positions|restores?)$|^(?:clear|forget) (?:all )?(?:window )?restores?$/.test(s))
    return { kind: "placesClear" };
  if ((m = /^save (?:the |this )?(?:window )?layout(?: as)? (.+)$/.exec(s))) return { kind: "layoutSave", name: m[1] };
  if ((m = /^(?:forget|delete|remove) (?:the )?(?:window )?layout (.+)$/.exec(s))) return { kind: "layoutDrop", name: m[1] };
  if ((m = /^(?:use |restore |apply )?(?:the )?(?:window )?layout (.+)$/.exec(s))) return { kind: "layoutUse", name: m[1] };
  // the words, or the QR code, in a region of the screen (Picasso's overlay)
  if (/^(?:ocr|(?:copy|grab|read) (?:the )?text(?: from| on| off)?(?: (?:the )?screen)?)$/.test(s)) return { kind: "ocr" };
  if (/^(?:scan|read) (?:a |the )?(?:qr|bar ?code)(?: code)?$|^qr (?:scan|read)$/.test(s)) return { kind: "scanqr" };
  // the window you were in, put somewhere (2026-11-02): "left half",
  // "maximize", "next screen", "size 1280x720"
  if ((m = /^(?:(?:move|put|snap) )?(?:the )?(?:window )?(?:to )?(?:the )?(left|right|top|bottom) half$/.exec(s)))
    return { kind: "snap", where: m[1] };
  if (/^(?:maximi[sz]e|fill the screen)(?: (?:the )?window)?$/.test(s)) return { kind: "snap", where: "max" };
  // thirds, quarters, the middle, back as it was (2026-11-03)
  const SNAP_PRE = "^(?:(?:move|put|snap) )?(?:the )?(?:window )?(?:to )?(?:the )?";
  if ((m = new RegExp(SNAP_PRE + "(left|first|center|centre|middle|right|last) third$").exec(s)))
    return { kind: "snap", where: { left: "left3", first: "left3", right: "right3", last: "right3" }[m[1]] || "center3" };
  if ((m = new RegExp(SNAP_PRE + "(left|first|right|last) two thirds$").exec(s)))
    return { kind: "snap", where: /left|first/.test(m[1]) ? "left23" : "right23" };
  if ((m = new RegExp(SNAP_PRE + "(top|upper|bottom|lower) (left|right)(?: quarter)?$").exec(s)))
    return { kind: "snap", where: (/top|upper/.test(m[1]) ? "t" : "b") + (m[2] === "left" ? "l" : "r") };
  if (new RegExp(SNAP_PRE + "(?:center|centre|middle) half$").test(s)) return { kind: "snap", where: "centerHalf" };
  if (/^almost maximi[sz]e(?: (?:the )?window)?$/.test(s)) return { kind: "snap", where: "almost" };
  if (/^(?:center|centre)(?: (?:the )?window)?$/.test(s)) return { kind: "snap", where: "center" };
  if (/^(?:restore|unsnap|put back)(?: (?:the )?window)?$/.test(s)) return { kind: "snap", where: "restore" };
  if (/^(?:move (?:the )?(?:window )?)?(?:to )?(?:the )?(?:next|other) (?:screen|monitor|display)$/.test(s))
    return { kind: "snap", where: "next" };
  if ((m = /^(?:resize|size)(?: (?:the )?window)?(?: to)? (\d{2,5}) ?[x×* ] ?(\d{2,5})$/.exec(s)))
    return { kind: "snap", where: "size", w: +m[1], h: +m[2] };
  // "screenshot 5", "screenshot a window in 3s": Picasso's shot, after a
  // wait (the plain three are verbs of their own)
  if ((m = /^(?:take (?:a )?)?(?:screenshot|screen shot|shot)(?: (?:of )?(?:the |a )?(screen|window|region|area|selection))?(?: (?:in|after))? (\d{1,2}) ?(?:s|secs?|seconds?)?$/.exec(s))) {
    const delay = Math.max(1, Math.min(60, +m[2]));
    return { kind: "shot", mode: !m[1] || m[1] === "screen" ? "screen" : m[1] === "window" ? "window" : "region", delay };
  }
  const t = parseTimer(s);
  if (t) return t;
  const raw = String(q || "").trim();
  if (/^(https?:\/\/\S+|www\.\S+\.\S+)$/i.test(raw)
      || /^[a-z0-9-]+(\.[a-z0-9-]+)*\.(com|org|net|io|dev|app|me|co|uk|de|eg|edu|gov|info|xyz|ai|gg|tv|so|sh)(\/\S*)?$/i.test(raw))
    return { kind: "url", url: /^https?:\/\//i.test(raw) ? raw : "https://" + raw };
  return null;
}

// "timer 25m", "timer 1h30m tea", "25 minute timer", "pomodoro", "countdown
// 90s": whole minutes (a timer counts minutes), at least one, and the
// words after it its name
const UNIT_MIN = { h: 60, hr: 60, hrs: 60, hour: 60, hours: 60, m: 1, min: 1, mins: 1, minute: 1, minutes: 1,
  s: 1 / 60, sec: 1 / 60, secs: 1 / 60, second: 1 / 60, seconds: 1 / 60 };
function parseTimer(s) {
  // a break, Kairos' word for getting up (2026-11-02): five minutes unless said
  const brk = /^(?:take|start) a break(?: (?:for )?(\d+) ?(?:m|min|mins|minutes?))?$/.exec(s);
  if (brk) return { kind: "timer", minutes: brk[1] ? Math.max(1, +brk[1]) : 5, label: "Break" };
  let m = /^(?:set (?:a )?|start (?:a )?)?(timer|pomodoro|countdown)(?: for)?(?: (.*))?$/.exec(s);
  let rest;
  if (m) rest = m[2] || "";
  else if ((m = /^(\d+) ?(h|hr|hours?|m|min|mins|minutes?|s|secs?|seconds?) (?:timer|countdown)(?: (.*))?$/.exec(s)))
    rest = m[1] + " " + m[2] + (m[3] ? " " + m[3] : "");
  else return null;
  let mins = 0;
  const words = rest.split(" ").filter((w) => w !== "");
  let i = 0;
  for (; i < words.length; ++i) {
    const w = words[i];
    let d = /^(\d+)$/.exec(w);
    if (d) {
      const unit = UNIT_MIN[words[i + 1]];
      if (unit) { mins += +d[1] * unit; i++; continue; }
      mins += +d[1];
      continue;
    }
    const parts = w.match(/^(\d+(?:h|hr|m|min|s))+$/) ? w.match(/\d+(?:h|hr|min|m|s)/g) : null;
    if (parts) {
      for (const p of parts) { const x = /^(\d+)(\D+)$/.exec(p); mins += +x[1] * UNIT_MIN[x[2]]; }
      continue;
    }
    break;
  }
  const label = words.slice(i).join(" ");
  const pomodoro = /pomodoro/.test(s);
  if (mins === 0 && !pomodoro && !/^(?:set (?:a )?|start (?:a )?)?(timer|countdown)$/.test(s)) return null;
  return { kind: "timer", minutes: mins > 0 ? Math.max(1, Math.ceil(mins)) : 0,
    label: label !== "" ? label.charAt(0).toUpperCase() + label.slice(1) : pomodoro ? "Pomodoro" : "Timer" };
}

// a length of minutes in words: 90 → "1 h 30 min"
function minutesText(n) {
  const h = Math.floor(n / 60), m = n % 60;
  return (h ? h + " h" : "") + (h && m ? " " : "") + (m || !h ? m + " min" : "");
}
