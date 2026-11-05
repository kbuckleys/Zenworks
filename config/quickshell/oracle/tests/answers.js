// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// Cynosure's smart answers: what a line in plain words is asking, and the
// answers arithmetic gives. Each case is a way someone actually says it.

"use strict";

module.exports = {
  module: "cynosure/answers.js",
  cases: (A, t) => {
    const wx = (q) => { const w = A.parseWeather(q); return w && [w.place, w.day, w.focus].join("|"); };
    // ── the weather ───────────────────────────────────────────────────────
    t.eq("a place, then the word", wx("cairo weather"), "cairo||weather");
    t.eq("the word, then in a place", wx("weather in Paris tomorrow"), "paris|tomorrow|weather");
    t.eq("here, when no place is named", wx("weather"), "||weather");
    t.eq("rain, here", wx("will it rain today?"), "||rain");
    t.eq("rain somewhere, by a weekday", wx("is it raining in new york on friday"), "new york|friday|rain");
    t.eq("the sun", wx("sunset in tokyo"), "tokyo||sun");
    t.eq("how hot, somewhere", wx("how hot is it in dubai"), "dubai||temp");
    t.eq("a word that might be weather is not enough alone", wx("cold brew"), null);
    t.eq("nor is an app", wx("firefox"), null);
    t.eq("tomorrow is one day on", A.dayOffset("tomorrow", new Date(2026, 10, 1)), 1);
    t.eq("a weekday is its next one", A.dayOffset("friday", new Date(2026, 10, 1)), 5);
    t.eq("today's weekday is today", A.dayOffset("sunday", new Date(2026, 10, 1)), 0);

    // ── everything else ──────────────────────────────────────────────────
    const kind = (q) => { const a = A.parseAsk(q); return a ? a.kind : null; };
    t.eq("what time is it", kind("what time is it?"), "time");
    t.eq("time", kind("time"), "time");
    t.eq("the date", kind("what's the date"), "date");
    t.eq("what day is it", kind("what day is it"), "date");
    t.eq("week number", kind("week number"), "week");
    t.eq("but not the word week alone", kind("week"), null);
    t.eq("a coin", kind("flip a coin"), "coin");
    t.eq("dice", A.parseAsk("roll 2d6"), { kind: "dice", n: 2, sides: 6 });
    t.eq("a die", A.parseAsk("roll a die"), { kind: "dice", n: 1, sides: 6 });
    t.eq("d20", A.parseAsk("d20"), { kind: "dice", n: 1, sides: 20 });
    t.eq("a number between", A.parseAsk("random number between 50 and 1"), { kind: "random", lo: 1, hi: 50 });
    t.eq("a uuid", kind("uuid"), "uuid");
    t.eq("my ip", kind("my ip"), "ip");
    t.eq("battery", kind("battery"), "battery");
    t.eq("uptime", kind("how long has it been up"), "uptime");
    t.eq("what a word means", A.parseAsk("what does serendipity mean"), { kind: "define", word: "serendipity" });
    t.eq("an app is not a question", kind("firefox"), null);
    t.eq("nor is a command", kind("lock screen"), null);

    // ── answers ──────────────────────────────────────────────────────────
    const d = new Date(2026, 10, 1, 14, 5);
    t.eq("the time, 24-hour", A.answerOf({ kind: "time" }, d, true).big, "14:05");
    t.eq("the time, 12-hour", A.answerOf({ kind: "time" }, d, false).big, "2:05 pm");
    t.eq("the date", A.answerOf({ kind: "date" }, d, true).big, "Sunday 1 November 2026");
    t.eq("the week", A.answerOf({ kind: "week" }, d, true).big, "Week 44");
    t.eq("a coin", A.answerOf({ kind: "coin" }, d, true, () => 0.2).big, "Heads");
    t.eq("dice add up", A.answerOf({ kind: "dice", n: 2, sides: 6 }, d, true, () => 0.5).big, "8");
    t.eq("a number in its range", A.answerOf({ kind: "random", lo: 1, hi: 10 }, d, true, () => 0.99).big, "10");
    t.ok("a uuid looks like one", /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
      .test(A.answerOf({ kind: "uuid" }, d, true).big));
    t.eq("addresses read", A.parseAddrs("2: wlan0    inet 192.168.1.4/24 brd 192.168.1.255 scope global"),
      [{ dev: "wlan0", addr: "192.168.1.4" }]);
    t.eq("the battery read", A.parseBattery("84 Charging"), { big: "84%", small: "Charging", level: 0.84 });
    t.eq("uptime in words", A.uptimeText(93784), "1 day, 2 hours");
    t.eq("a place found", A.parseGeocode('{"results":[{"latitude":30,"longitude":31,"name":"Cairo","country":"Egypt"}]}'),
      { lat: 30, lon: 31, name: "Cairo, Egypt" });
    t.eq("a place not found", A.parseGeocode('{}'), null);

    // ── more answers ─────────────────────────────────────────────────────
    const ans = (q) => A.answerOf(A.parseAsk(q), d, true, () => 0.5);
    t.eq("a color by hex", ans("#ff8800").small, "rgb(255, 136, 0) · hsl(32, 100%, 50%)");
    t.eq("a color by rgb", ans("rgb(255, 136, 0)").big, "#FF8800");
    t.eq("a color by hsl", ans("hsl(0, 100%, 50%)").big, "#FF0000");
    t.eq("base64 there", ans("base64 héllo").big, "aMOpbGxv");
    t.eq("and back", ans("base64 decode aMOpbGxv").big, "héllo");
    t.eq("not base64 is said so", ans("base64 decode !!!").big, "Not base64");
    t.eq("url encoded", ans("url encode a b&c").big, "a%20b%26c");
    t.eq("url decoded", ans("url decode a%20b").big, "a b");
    t.eq("words counted", ans("count the quick fox").big, "3 words");
    t.eq("a timestamp's date", ans("epoch 0000000000".replace("0000000000", "1700000000")).small, "1700000000 seconds since 1970");
    t.eq("the moon, by a known full one", A.moonPhase(new Date(Date.UTC(2026, 9, 26, 4))).name, "Full moon");
    t.eq("a hash is the machine's", A.parseAsk("sha256 hello"), { kind: "hash", algo: "sha256", text: "hello" });
    t.eq("memory read", A.memAnswer(16777216, 8388608),
      { big: "8 GB of 16 GB", small: "50% in use · 8 GB free" });
    t.eq("disk read", A.parseDf("Filesystem 1024-blocks Used Available Capacity Mounted\n/dev/x 104857600 52428800 52428800 50% /").big, "50 GB free");
    t.eq("cpu read", A.cpuAnswer(49.6, 1.234, 16), { big: "50% busy", small: "Load 1.23 · 16 threads" });
    t.eq("disk level", A.parseDf("Filesystem 1024-blocks Used Available Capacity Mounted\n/dev/x 104857600 52428800 52428800 50% /").level, 0.5);
    t.eq("which network", A.parseAsk("which wifi am i on").kind, "wifi");
    const forms = A.colorForms("#ff8800");
    t.eq("a color's forms, hex first", forms[0], ["Hex", "#FF8800"]);
    t.eq("as rgb()", forms[1][1], "rgb(255, 136, 0)");
    t.eq("as Hyprland writes it", forms.find((f) => f[0] === "Hyprland")[1], "rgb(ff8800)");
    t.eq("white in oklch", A.colorForms("#ffffff").find((f) => f[0] === "OKLCH")[1], "oklch(100% 0 0)");
    t.eq("what's playing", A.parseAsk("what's playing").kind, "playing");

    // ── commands that take an argument ───────────────────────────────────
    const c = (q) => A.parseCommand(q);
    // a break is a five-minute timer unless said (2026-11-02)
    t.eq("take a break", c("take a break"), { kind: "timer", minutes: 5, label: "Break" });
    t.eq("for longer", c("take a break for 10 min").minutes, 10);
    // screen time is asked of Kairos (2026-11-02)
    t.eq("screen time", A.parseAsk("screen time"), { kind: "screentime", span: "today", app: "" });
    t.eq("this week", A.parseAsk("my screen time this week").span, "week");
    t.eq("an app", A.parseAsk("how long have i been on firefox today"), { kind: "screentime", span: "today", app: "firefox" });
    t.eq("uptime is still uptime", A.parseAsk("how long have i been on").kind, "uptime");
    // the window you were in, put somewhere (2026-11-02)
    t.eq("left half", c("left half"), { kind: "snap", where: "left" });
    t.eq("move the window to the right half", c("move window to the right half").where, "right");
    t.eq("maximize", c("maximize").where, "max");
    t.eq("next screen", c("move to the next monitor").where, "next");
    t.eq("a size", c("size 1280x720"), { kind: "snap", where: "size", w: 1280, h: 720 });
    t.eq("resize with a times sign", c("resize window to 800 \u00D7 600").h, 600);
    t.eq("a bare product is the calculator's", c("1280x720"), null);
    // a screenshot after a wait (2026-11-02); the plain three are verbs
    t.eq("screenshot 5", JSON.stringify(c("screenshot 5")), JSON.stringify({ kind: "shot", mode: "screen", delay: 5 }));
    t.eq("a window in 3s", JSON.stringify(c("screenshot a window in 3s")), JSON.stringify({ kind: "shot", mode: "window", delay: 3 }));
    t.eq("an area is a region", c("take a screenshot of the area after 10 seconds").mode, "region");
    t.eq("no wait, no command", c("screenshot"), null);
    t.eq("the wait is capped", c("screenshot 99").delay, 60);
    t.eq("the volume", c("volume 30"), { kind: "volume", pct: 30 });
    t.eq("set it to", c("set volume to 45%"), { kind: "volume", pct: 45 });
    t.eq("up", c("volume up"), { kind: "volume", step: 10 });
    t.eq("mute", c("mute"), { kind: "mute", on: true });
    t.eq("brightness", c("brightness 50"), { kind: "brightness", pct: 50 });
    t.eq("dimmer", c("dimmer"), { kind: "brightness", step: -10 });
    t.eq("wi-fi off", c("wifi off"), { kind: "wifi", on: false });
    t.eq("turn on bluetooth", c("turn on bluetooth"), { kind: "bluetooth", on: true });
    t.eq("night light", c("night light on"), { kind: "night", on: true });
    t.eq("do not disturb", c("dnd on"), { kind: "dnd", on: true });
    t.eq("next song", c("next"), { kind: "media", act: "next" });
    t.eq("a workspace", c("workspace 3"), { kind: "workspace", n: 3 });
    t.eq("the window moved", [c("move to workspace 3"), c("send window to 4"), c("move window to ws 2")].map((x) => x && x.kind + x.n),
      ["moveWs3", "moveWs4", "moveWs2"]);
    t.eq("the camera", c("camera"), { kind: "camera" });
    t.eq("an app ended", c("kill firefox"), { kind: "kill", name: "firefox", force: false });
    t.eq("or forced", c("force quit steam"), { kind: "kill", name: "steam", force: true });
    t.eq("a timer", c("timer 25m"), { kind: "timer", minutes: 25, label: "Timer" });
    t.eq("with a name", c("timer 1h30m tea"), { kind: "timer", minutes: 90, label: "Tea" });
    t.eq("in words", c("timer 10 minutes eggs"), { kind: "timer", minutes: 10, label: "Eggs" });
    t.eq("said the other way", c("5 minute timer"), { kind: "timer", minutes: 5, label: "Timer" });
    t.eq("seconds round up", c("countdown 90s"), { kind: "timer", minutes: 2, label: "Timer" });
    t.eq("a pomodoro, its own length", c("pomodoro"), { kind: "timer", minutes: 0, label: "Pomodoro" });
    t.eq("an address", c("github.com/kbuckleys"), { kind: "url", url: "https://github.com/kbuckleys" });
    t.eq("an app is not a command", c("firefox"), null);
    t.eq("nor a word that only starts one", c("volume"), null);
    t.eq("minutes in words", A.minutesText(90), "1 h 30 min");
    // the calendar
    const k = (q) => A.parseAsk(q);
    t.eq("next meeting", k("next meeting"), { kind: "cal", span: "next" });
    t.eq("what's next", k("what's next?"), { kind: "cal", span: "next" });
    t.eq("what's on friday", k("what's on friday"), { kind: "cal", span: "friday" });
    t.eq("agenda alone is today", k("agenda"), { kind: "cal", span: "today" });
    t.eq("am i free tomorrow", k("am i free tomorrow"), { kind: "cal", span: "tomorrow" });
    t.eq("meetings this week", k("meetings this week"), { kind: "cal", span: "week" });
    t.eq("calendar alone is the app", k("calendar"), null);
    const wed = new Date(2026, 9, 28, 10, 0);   // a Wednesday
    t.eq("friday's dates", A.calRange({ span: "friday" }, wed), { from: "2026-10-30", to: "2026-10-31" });
    const evs = JSON.stringify({ events: [
      { title: "Standup", date: "2026-10-28", start: "09:00", end: "09:15", endDate: "2026-10-28", allDay: false },
      { title: "Dentist", date: "2026-10-28", start: "10:30", end: "11:00", endDate: "2026-10-28", allDay: false, location: "Clinic" }] });
    t.eq("the next one not yet started", A.calAnswer(evs, { span: "next" }, wed),
      { big: "Dentist", small: "in 30 min \u00B7 Today 10:30 \u2013 11:00 \u00B7 Clinic", day: "2026-10-28" });
    t.eq("a day's list", A.calAnswer(evs, { span: "today" }, wed).big, "09:00 Standup  \u00B7  10:30 Dentist");
    t.eq("khal's error, in words", A.calAnswer('{"error":"critical: Cannot find a config file."}', { span: "today" }, wed).small,
      "Set one up in Chronos");
    t.eq("a free day", A.calAnswer('{"events":[]}', { span: "friday" }, wed).big, "Nothing on");
    // windows, apps, the screen and the rest of Raycast's own (2026-11-03)
    t.eq("thirds", [c("left third"), c("center third"), c("right two thirds")].map((x) => x.where), ["left3", "center3", "right23"]);
    t.eq("quarters", [c("top left quarter"), c("bottom right")].map((x) => x.where), ["tl", "br"]);
    t.eq("center, restore, almost", [c("center"), c("restore"), c("almost maximize")].map((x) => x.where), ["center", "restore", "almost"]);
    t.eq("larger, smaller, widths", [c("larger"), c("smaller"), c("maximize width"), c("maximize height"), c("previous screen")].map((x) => x.where),
      ["grow", "shrink", "maxW", "maxH", "prev"]);
    t.eq("restart an app", c("restart firefox"), { kind: "restart", name: "firefox" });
    t.eq("quit all is not an app called all", [c("quit all apps").kind, c("close all windows").kind], ["quitAll", "quitAll"]);
    t.eq("end focus is not an app called focus", c("end focus"), { kind: "focusEnd" });
    t.eq("a focus session", c("focus 1h writing"), { kind: "focus", minutes: 60, label: "Writing" });
    t.eq("focus alone is 25 min", c("focus"), { kind: "focus", minutes: 25, label: "Focus" });
    t.eq("set aside", c("focus block discord"), { kind: "focusBlock", name: "discord", on: true });
    t.eq("auto quit", [c("auto quit slack after 2h"), c("auto quit slack off")], [{ kind: "autoQuit", name: "slack", minutes: 120 },
      { kind: "autoQuit", name: "slack", minutes: 0 }]);
    t.eq("layouts", [c("save layout coding").kind, c("layout coding").kind, c("forget layout coding").kind], ["layoutSave", "layoutUse", "layoutDrop"]);
    t.eq("the screen's words", [c("ocr").kind, c("copy text from screen").kind, c("scan qr").kind, c("qr scan").kind], ["ocr", "ocr", "scanqr", "scanqr"]);
    t.eq("the rest", ["empty trash", "eject", "show desktop", "screens off", "clear clipboard", "join meeting", "fullscreen"].map((q) => c(q).kind),
      ["emptyTrash", "eject", "desktop", "screensOff", "clearClips", "joinMeeting", "fullscreen"]);
    t.eq("a QR code of the words", k("qr https://example.com/a?b=C"), { kind: "qr", text: "https://example.com/a?b=C" });
    t.eq("qr scan is not a code of 'scan'", k("qr scan"), null);
    t.eq("speed test", [k("speed test").kind, k("how fast is my internet").kind], ["speed", "speed"]);
    t.eq("speed read", A.parseSpeed("12500000 0.050 0.010 2500000"), { big: "100 Mbps down", small: "20 Mbps up \u00B7 40 ms ping" });
    t.eq("no speed is null", A.parseSpeed("0 0 0 0"), null);
    const at10 = new Date(2026, 10, 3, 10, 0);
    const iso = (h, m) => new Date(2026, 10, 3, h, m).toISOString();
    t.eq("the next call's link, its full stop left off", A.nextMeeting([
      { title: "Done", start: iso(8, 0), end: iso(9, 0), location: "https://zoom.us/j/1" },
      { title: "Lunch", start: iso(10, 30), end: iso(11, 0), location: "Cafe" },
      { title: "Standup", start: iso(11, 0), end: iso(11, 15), description: "Join: https://meet.google.com/abc-defg-hij." }], at10),
      { title: "Standup", url: "https://meet.google.com/abc-defg-hij" });
    t.eq("no call, no meeting", A.nextMeeting([{ title: "Lunch", start: iso(12, 0), end: iso(13, 0), location: "Cafe" }], at10), null);
    // contacts, confetti, the clear words, light and dark (2026-11-03)
    t.eq("a contact as typed", c("new contact Ada Lovelace ada@Example.org +44 20 7946 0958"),
      { kind: "newContact", name: "Ada Lovelace", email: "ada@Example.org", phone: "+44 20 7946 0958" });
    t.eq("a contact by name alone", c("add contact Grace"), { kind: "newContact", name: "Grace", email: "", phone: "" });
    t.eq("no name, no contact", c("new contact ada@example.org"), null);
    t.eq("confetti", [c("confetti").kind, c("celebrate").kind, c("tada!").kind], ["confetti", "confetti", "confetti"]);
    t.eq("the clear words", [c("clear layouts").kind, c("clear window places").kind], ["layoutsClear", "placesClear"]);
    t.eq("dark and light", [c("dark mode"), c("light mode")].map((x) => x && x.kind), ["appearance", "appearance"]);
  }
};
