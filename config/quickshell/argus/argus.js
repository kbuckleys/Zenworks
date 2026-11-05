// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/

.pragma library
// ONE COPY FOR THE WHOLE SHELL (see morpheus/icons.js).
//
// ARGUS' PURE HALF: the times as written, the range kept sane, the file a
// cut is saved as, and the ffmpeg line for each format — so the editor only
// draws and asks, and oracle/tests/argus.js checks every command.

var FORMATS = [
  { id: "mp4", label: "MP4", ext: ".mp4" },
  { id: "gif", label: "GIF", ext: ".gif" },
  { id: "webm", label: "WebM", ext: ".webm" }
];
// a GIF's longest side, and how many frames a second; 0 is the original
var GIF_WIDTHS = [0, 960, 720, 480];
var GIF_FPS = [10, 15, 24, 30];
var MIN_LEN = 100;   // ms: shorter than this is not a clip

function formatOf(id) {
  for (var i = 0; i < FORMATS.length; ++i) if (FORMATS[i].id === id) return FORMATS[i];
  return FORMATS[0];
}

function defaults() {
  return Object.assign({ format: "mp4", exact: false, audio: true, gifWidth: 720, gifFps: 15, loop: true }, FRAME_DEFAULTS);
}
function parseSettings(text) {
  var d = defaults(), j;
  try { j = JSON.parse(String(text || "")); } catch (e) { return d; }
  if (!j || typeof j !== "object") return d;
  if (FORMATS.some(function (f) { return f.id === j.format; })) d.format = j.format;
  if (typeof j.exact === "boolean") d.exact = j.exact;
  if (typeof j.audio === "boolean") d.audio = j.audio;
  if (GIF_WIDTHS.indexOf(j.gifWidth) >= 0) d.gifWidth = j.gifWidth;
  if (GIF_FPS.indexOf(j.gifFps) >= 0) d.gifFps = j.gifFps;
  if (typeof j.loop === "boolean") d.loop = j.loop;
  return parseFrameSettings(j, d);
}
function serializeSettings(s) { return JSON.stringify(parseSettings(JSON.stringify(s)), null, 2) + "\n"; }

// ── TIMES ────────────────────────────────────────────────────────────────
// 83450 → "1:23.4": tenths, because a cut is placed finer than a second
function stamp(ms) {
  var t = Math.max(0, Math.round((Number(ms) || 0) / 100));
  var tenths = t % 10, s = Math.floor(t / 10) % 60, m = Math.floor(t / 600) % 60, h = Math.floor(t / 36000);
  var two = function (n) { return (n < 10 ? "0" : "") + n; };
  return (h > 0 ? h + ":" + two(m) : String(m)) + ":" + two(s) + "." + tenths;
}
// ffmpeg's: seconds, three places
function secs(ms) { return (Math.max(0, Number(ms) || 0) / 1000).toFixed(3); }

// The range, kept inside the clip and at least MIN_LEN long. `moved` says
// which end the user is holding, so that end gives way last.
function clampRange(inMs, outMs, dur, moved) {
  var d = Math.max(0, Number(dur) || 0);
  var a = Math.max(0, Math.min(d, Number(inMs) || 0));
  var b = Math.max(0, Math.min(d, outMs === undefined || outMs === null ? d : Number(outMs)));
  if (d <= MIN_LEN) return { inMs: 0, outMs: d };
  if (b - a < MIN_LEN) {
    if (moved === "out") { b = Math.max(b, MIN_LEN); a = b - MIN_LEN; }
    else { a = Math.min(a, d - MIN_LEN); b = a + MIN_LEN; }
  }
  return { inMs: Math.round(a), outMs: Math.round(b) };
}
function whole(inMs, outMs, dur) { return inMs <= 0 && outMs >= dur; }

// ── NAMES ────────────────────────────────────────────────────────────────
function dirOf(p) { var s = String(p || ""); var i = s.lastIndexOf("/"); return i > 0 ? s.slice(0, i) : "/"; }
function baseOf(p) { var s = String(p || "").replace(/.*\//, ""); var i = s.lastIndexOf("."); return i > 0 ? s.slice(0, i) : s; }
// beside the original: "2026-10-20-232145-DP-1.mp4" → "…-DP-1-cut.mp4";
// taken already ("taken(path)" true) → "-cut-2", "-cut-3"…
function outPath(src, format, taken) {
  var f = formatOf(format);
  var stem = dirOf(src) + "/" + baseOf(src) + "-cut";
  var p = stem + f.ext;
  for (var n = 2; taken && taken(p) && n < 1000; ++n) p = stem + "-" + n + f.ext;
  return p;
}
// A path and the names that follow it, for when it is taken: "a.mp4",
// "a-2.mp4" … "a-59.mp4". For a name the file picker never asked about —
// Save as's, once withExt has changed its extension (2026-10-23: "clip.mov"
// as MP4 overwrote an existing "clip.mp4" without a word).
function variants(path) {
  const s = String(path || "");
  const m = /^(.*?)(\.[A-Za-z0-9]{2,5})?$/.exec(s);
  const out = [s];
  for (let n = 2; n < 60; ++n) out.push(m[1] + "-" + n + (m[2] || ""));
  return out;
}
// whatever was typed into Save as, with this format's extension
function withExt(path, format) {
  var f = formatOf(format), s = String(path || "");
  return /\.[A-Za-z0-9]{2,5}$/.test(s.replace(/.*\//, "")) ? s.replace(/\.[A-Za-z0-9]{2,5}$/, f.ext) : s + f.ext;
}

// ── THE COMMANDS ─────────────────────────────────────────────────────────
// o: { inMs, outMs, format, exact, audio, gifWidth, gifFps, loop }
// Seeking BEFORE -i (fast, on keyframes for a copy; exact for a re-encode,
// which decodes from the keyframe before and drops what precedes `in`).
// ── THE CROP (2026-10-21) ────────────────────────────────────────────────
// { x, y, w, h } in the video's pixels, or null for all of it. Even numbers:
// yuv420p (MP4, WebM) halves the color planes and refuses an odd size.
var CROP_RATIOS = [
  { id: "free", label: "Free", value: 0 },
  { id: "1:1", label: "1:1", value: 1 },
  { id: "4:5", label: "4:5", value: 4 / 5 },
  { id: "16:9", label: "16:9", value: 16 / 9 },
  { id: "9:16", label: "9:16", value: 9 / 16 }
];
function ratioValue(id) {
  for (var i = 0; i < CROP_RATIOS.length; i++) if (CROP_RATIOS[i].id === id) return CROP_RATIOS[i].value;
  return 0;
}
function even(v) { return Math.max(0, Math.floor(Number(v) / 2) * 2); }
// null when the box is (near enough) the whole picture
function cropOf(r, vw, vh) {
  if (!r || !(vw > 0) || !(vh > 0)) return null;
  var x = even(Math.max(0, Math.min(vw - 2, r.x))), y = even(Math.max(0, Math.min(vh - 2, r.y)));
  var w = even(Math.max(2, Math.min(vw - x, r.w))), h = even(Math.max(2, Math.min(vh - y, r.h)));
  if (x === 0 && y === 0 && w >= even(vw) && h >= even(vh)) return null;
  return { x: x, y: y, w: w, h: h };
}
function cropFilter(c) { return c ? "crop=" + c.w + ":" + c.h + ":" + c.x + ":" + c.y : ""; }

function ffmpegArgs(src, out, o) {
  var len = Math.max(MIN_LEN, o.outMs - o.inMs);
  var head = ["ffmpeg", "-hide_banner", "-nostdin", "-y", "-progress", "pipe:1", "-nostats"];
  var cut = ["-ss", secs(o.inMs), "-t", secs(len), "-i", src];
  var audio = function (codec) { return o.audio ? codec : ["-an"]; };
  var crop = cropFilter(o.crop || null);
  var vf = crop ? ["-vf", crop] : [];
  if (o.format === "gif") {
    // the cap is on the longest side, so a tall crop is not 720 wide and
    // 1280 high; never upscaled
    var w = o.gifWidth > 0 ? String(o.gifWidth) : "";
    var scale = w ? ",scale='if(gte(iw,ih),min(" + w + ",iw),-1)':'if(gte(iw,ih),-1,min(" + w + ",ih))':flags=lanczos" : "";
    // 128 colors and bayer 5 (2026-11-04): a quarter smaller on film, an
    // eighth on a screen, and closer to the source by SSIM than 256 at bayer 4
    var graph = (crop ? crop + "," : "") + "fps=" + o.gifFps + scale + ",split[a][b];"
      + "[a]palettegen=stats_mode=diff:max_colors=128[p];[b][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle";
    return head.concat(cut, ["-filter_complex", graph, "-loop", o.loop ? "0" : "-1", out]);
  }
  if (o.format === "webm")
    return head.concat(cut, vf, ["-c:v", "libvpx-vp9", "-b:v", "0", "-crf", "33", "-row-mt", "1",
                             "-deadline", "good", "-cpu-used", "4", "-pix_fmt", "yuv420p"],
                       audio(["-c:a", "libopus", "-b:a", "128k"]), [out]);
  // mp4: copied as it is (instant, cuts on the nearest keyframe), or exact —
  // and a crop is always an encode: a copied stream cannot be cut down
  if (!o.exact && !crop)
    return head.concat(cut, ["-c:v", "copy"], audio(["-c:a", "copy"]),
                       ["-avoid_negative_ts", "make_zero", "-movflags", "+faststart", out]);
  return head.concat(cut, vf, ["-c:v", "libx264", "-preset", "veryfast", "-crf", "20", "-pix_fmt", "yuv420p"],
                     audio(["-c:a", "aac", "-b:a", "160k"]), ["-movflags", "+faststart", out]);
}

// A saved GIF, squeezed in place by gifsicle (2026-11-04): its lossy LZW
// halves a screen recording and takes a quarter or more off camera footage,
// with no difference to see; -O2 is as small as -O3 here at a third of the
// time. `exec`, so a stop's SIGTERM reaches gifsicle, not a waiting shell;
// with no gifsicle it is a step that does nothing
var SQUEEZE = "gifsicle -O2 --lossy=60 -b";
function squeezeArgs(gif) {
  return ["sh", "-c", "command -v gifsicle >/dev/null || exit 0; exec " + SQUEEZE + " \"$1\"", "sh", gif];
}

// ── HOW BIG A GIF WILL BE (2026-11-04) ───────────────────────────────────
// A GIF's size is all in its content (a still screen is tiny, a handheld
// camera huge), so it is measured, not guessed: up to ESTIMATE_MS from the
// middle of the kept part, made with the very same command and squeeze,
// and its bytes scaled up to the whole length. argv: the output is made
// here, a temporary file; the answer is its size on stdout.
var ESTIMATE_MS = 2000;
function estimateSpan(o) {
  var len = Math.max(MIN_LEN, o.outMs - o.inMs), take = Math.min(len, ESTIMATE_MS);
  var at = o.inMs + (len - take) / 2;
  return { inMs: at, outMs: at + take, scale: len / take };
}
function estimateArgs(src, o) {
  var span = estimateSpan(o);
  var f = ffmpegArgs(src, "", Object.assign({}, o, { inMs: span.inMs, outMs: span.outMs }));
  f.pop();   // the "" output: the temporary file goes there
  return ["sh", "-c", "g=$(mktemp --suffix=.gif) || exit 1; "
    + "if \"$@\" \"$g\" >/dev/null 2>&1; then "
    + "command -v gifsicle >/dev/null && " + SQUEEZE + " \"$g\" 2>/dev/null; stat -c %s \"$g\"; fi; rm -f \"$g\"", "sh"].concat(f);
}
// bytes → "0.8 MB", "13 MB"
function megabytes(bytes) {
  var mb = (Number(bytes) || 0) / 1048576;
  return (mb >= 10 ? String(Math.round(mb)) : mb.toFixed(1)) + " MB";
}

// `-progress pipe:1`: key=value lines, a block at a time; the last
// out_time_us (or out_time_ms, which is microseconds too) over the length
function progressOf(text, lenMs) {
  var lines = String(text || "").split("\n"), us = -1;
  for (var i = lines.length - 1; i >= 0; --i) {
    var m = /^out_time_(?:us|ms)=(\d+)/.exec(lines[i]);
    if (m) { us = Number(m[1]); break; }
  }
  if (us < 0 || !(lenMs > 0)) return 0;
  return Math.max(0, Math.min(1, us / 1000 / lenMs));
}

// The filmstrip: `count` frames spread over the clip, small, into `dir`
function stripArgs(src, dir, durMs, count) {
  var n = Math.max(1, count | 0);
  var rate = n / Math.max(0.1, (Number(durMs) || 0) / 1000);
  return ["ffmpeg", "-hide_banner", "-nostdin", "-loglevel", "error", "-y", "-i", src,
          "-vf", "fps=" + rate.toFixed(4) + ",scale=-2:96", "-frames:v", String(n), "-q:v", "5",
          dir + "/f%02d.jpg"];
}

// ── FRAMES, AS PICTURES (2026-11-01) ─────────────────────────────────────
// The frame under the playhead, or a run of them out of the kept part, as
// image files: PNG (lossless, the default), JPEG or WebP, as picasso writes.
// Named after the video and where in it they are: "clip-01m23.450s.png".
var FRAME_FORMATS = [
  { id: "png", label: "PNG", ext: ".png" },
  { id: "jpg", label: "JPEG", ext: ".jpg" },
  { id: "webp", label: "WebP", ext: ".webp" }
];
// which frames of the kept part: all, one every N seconds, every Nth, or N in all
var FRAME_MODES = [["all", "All"], ["secs", "Seconds"], ["nth", "Frames"], ["count", "Count"]];
var FRAME_SECS = [0.5, 1, 2, 5];
var FRAME_NTH = [2, 5, 10, 30];
var FRAME_COUNTS = [10, 25, 50, 100];
var FRAME_DEFAULTS = { frameFormat: "png", framesMode: "secs", framesSecs: 1, framesNth: 10, framesCount: 25 };
function frameFormatOf(id) {
  for (var i = 0; i < FRAME_FORMATS.length; ++i) if (FRAME_FORMATS[i].id === id) return FRAME_FORMATS[i];
  return FRAME_FORMATS[0];
}
function parseFrameSettings(j, d) {
  if (FRAME_FORMATS.some(function (f) { return f.id === j.frameFormat; })) d.frameFormat = j.frameFormat;
  if (FRAME_MODES.some(function (m) { return m[0] === j.framesMode; })) d.framesMode = j.framesMode;
  if (FRAME_SECS.indexOf(j.framesSecs) >= 0) d.framesSecs = j.framesSecs;
  if (FRAME_NTH.indexOf(j.framesNth) >= 0) d.framesNth = j.framesNth;
  if (FRAME_COUNTS.indexOf(j.framesCount) >= 0) d.framesCount = j.framesCount;
  return d;
}

// 83450 → "01m23.450s"; "1h01m23.450s" once `hours` (a video an hour or
// longer: every name in a run the same width, so they sort as they play)
function frameStamp(ms, hours) {
  var t = Math.max(0, Math.round(Number(ms) || 0));
  var pad = function (n, w) { var s = String(n); while (s.length < w) s = "0" + s; return s; };
  var h = Math.floor(t / 3600000), m = Math.floor(t / 60000) % 60, s = Math.floor(t / 1000) % 60;
  return (hours || h > 0 ? h + "h" : "") + pad(m, 2) + "m" + pad(s, 2) + "." + pad(t % 1000, 3) + "s";
}
// beside the original: "/v/clip.mp4" at 83450 → "/v/clip-01m23.450s.png"
function framePath(src, ms, format, hours) {
  return dirOf(src) + "/" + baseOf(src) + "-" + frameStamp(ms, hours) + frameFormatOf(format).ext;
}
// the directory a run goes into, inside the one picked: "<picked>/clip-frames"
function framesDir(picked, src) { return String(picked || "").replace(/\/+$/, "") + "/" + baseOf(src) + "-frames"; }

// How many a run makes, near enough (a screen recording's frame rate
// varies, so "all" is a guess from the stated one)
function framesEstimate(o, fps) {
  var len = Math.max(0, (o.outMs - o.inMs) / 1000);
  if (o.framesMode === "secs") return Math.max(1, Math.ceil(len / o.framesSecs - 1e-6));
  if (o.framesMode === "count") return o.framesCount;
  var all = Math.max(1, Math.round(len * (Number(fps) || 0)));
  return o.framesMode === "nth" ? Math.ceil(all / o.framesNth) : all;
}

function encodeArgs(format) {
  if (format === "jpg") return ["-q:v", "2"];
  if (format === "webp") return ["-c:v", "libwebp", "-quality", "90"];
  return [];
}

// THE FRAME SHOWING AT `atSec` (the file's own time, its start_time
// included). A plain `-ss` lands on the first frame AT or after a time,
// which is the NEXT frame whenever the playhead sits between two — and a
// screen recording's frames can be seconds apart. So: the packets from the
// keyframe before it, until one is decoded past it (dts only grows), and
// the latest that shows by then. argv: the video is $1, the time $2.
function pickArgs(src, atSec) {
  return ["sh", "-c",
    "ffprobe -v error -select_streams v:0 -read_intervals \"$2%\" -show_entries packet=pts_time,dts_time "
    + "-of compact=p=0:nk=0 -i \"$1\" | awk -v p=\"$2\" '"
    + "{ pt = \"\"; dt = \"\"; n = split($0, kv, \"|\"); for (i = 1; i <= n; i++) { split(kv[i], e, \"=\"); "
    + "if (e[1] == \"pts_time\") pt = e[2]; else if (e[1] == \"dts_time\") dt = e[2] } "
    + "if (pt != \"\" && pt != \"N/A\" && pt + 0 <= p + 0 && (best == \"\" || pt + 0 > best + 0)) best = pt; "
    + "if (dt != \"\" && dt != \"N/A\" && dt + 0 > p + 0) exit } "
    + "END { if (best != \"\") print best }'",
    "sh", src, Number(atSec).toFixed(6)];
}
// That frame to `out`, full size (a crop still applies). `seekSec` is from
// the start of the video; half a millisecond early, so rounding cannot step
// past it onto the next.
function frameArgs(src, out, o) {
  var crop = cropFilter(o.crop || null);
  return ["ffmpeg", "-hide_banner", "-nostdin", "-loglevel", "error", "-y",
          "-ss", Math.max(0, Number(o.seekSec) - 0.0005).toFixed(6), "-i", src]
    .concat(crop ? ["-vf", crop] : [], ["-frames:v", "1", "-update", "1"], encodeArgs(o.format), [out]);
}

// A run of them into `dir`. The video's own timestamps are kept (-copyts)
// and moved to start at 0 (its start_time, `startSec`), in milliseconds, so
// each file is numbered by where it sits: "clip-000083450.png", which
// framesRenameArgs then turns into "clip-01m23.450s.png".
function framesArgs(src, dir, o) {
  var a = Number(o.inMs) / 1000, b = Number(o.outMs) / 1000;
  var f = ["settb=1/1000", "setpts=PTS-" + (Number(o.startSec) || 0).toFixed(6) + "/TB"];
  var crop = cropFilter(o.crop || null);
  var cap = [];
  if (o.framesMode === "secs" || o.framesMode === "count") {
    // the first frame in each step of S seconds from the in point: its own
    // time, never a copy (fps= hands a step the LAST frame that rounds to
    // it, half a step late)
    var S = o.framesMode === "secs" ? Number(o.framesSecs) : Math.max(0.001, b - a) / o.framesCount;
    var slot = function (v) { return "floor((" + v + "-" + a.toFixed(3) + ")/" + S.toFixed(6) + ")"; };
    f.push("trim=start=" + a.toFixed(3) + ":end=" + b.toFixed(3),
           "select='isnan(prev_selected_t)+gt(" + slot("t") + "\\," + slot("prev_selected_t") + ")'");
    if (o.framesMode === "count") cap = ["-frames:v", String(o.framesCount)];
  } else {
    f.push("trim=start=" + a.toFixed(3) + ":end=" + b.toFixed(3));
    if (o.framesMode === "nth") f.push("select='not(mod(n\\," + o.framesNth + "))'");
  }
  if (crop) f.push(crop);
  // a % in a name (the directory's too) would be read as the counter
  var pattern = (dir + "/" + baseOf(src)).replace(/%/g, "%%") + "-%09d" + frameFormatOf(o.format).ext;
  return ["ffmpeg", "-hide_banner", "-nostdin", "-loglevel", "error", "-y", "-progress", "pipe:1", "-nostats",
          "-copyts", "-ss", secs(o.inMs), "-i", src, "-an", "-sn", "-vf", f.join(","),
          "-fps_mode", "passthrough", "-enc_time_base", "1/1000", "-frame_pts", "1"]
    .concat(cap, encodeArgs(o.format), [pattern]);
}
// "clip-000083450.png" → "clip-01m23.450s.png", every one in `dir`: the
// directory is $1, the name before the number $2, the extension $3, and $4
// is 1 for a video an hour or longer (see frameStamp)
function framesRenameArgs(dir, src, format, hours) {
  return ["sh", "-c",
    "cd \"$1\" || exit 1; for f in \"$2\"-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\"$3\"; do "
    + "[ -e \"$f\" ] || continue; n=${f#\"$2\"-}; n=${n%\"$3\"}; n=$(printf '%s' \"$n\" | sed 's/^0*//'); n=${n:-0}; "
    + "h=$((n / 3600000)); m=$((n / 60000 % 60)); s=$((n / 1000 % 60)); ms=$((n % 1000)); "
    + "if [ \"$4\" = 1 ] || [ $h -gt 0 ]; then t=$(printf '%dh%02dm%02d.%03ds' $h $m $s $ms); else t=$(printf '%02dm%02d.%03ds' $m $s $ms); fi; "
    + "mv -n -- \"$f\" \"$2-$t$3\"; done",
    "sh", dir, baseOf(src), frameFormatOf(format).ext, hours ? "1" : "0"];
}
// the latest "frame=" in a -progress block: how many are written so far
function framesDone(line) { var m = /^frame=(\d+)/.exec(String(line || "")); return m ? Number(m[1]) : -1; }

// ── RECORDING PREFERENCES ────────────────────────────────────────────────
// What argus.lua asks for before it records (`qs ipc call Argus recPrefs`):
// one line of key=value words its shell reads with a case, nothing quoted.
// Anything odd falls back to how it recorded before these existed.
var REC_AUDIO = ["none", "system", "mic", "both"];
function recPrefsLine(o) {
  var cd = Math.max(0, Math.min(10, Math.round(Number(o && o.recCountdown) || 0)));
  var au = REC_AUDIO.indexOf(o && o.recAudio) >= 0 ? o.recAudio : "system";
  return "countdown=" + cd + " audio=" + au + " pointer=" + (o && o.recBigPointer ? 1 : 0) + " camera=" + (o && o.recCamera ? 1 : 0);
}
// the camera bubble's anchors for a corner
function cornerAnchors(c) {
  return { top: c === "topLeft" || c === "topRight", bottom: c !== "topLeft" && c !== "topRight",
           left: c === "topLeft" || c === "bottomLeft", right: c !== "topLeft" && c !== "bottomLeft" };
}
