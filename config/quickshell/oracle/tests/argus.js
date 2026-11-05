// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// The pure half of argus' editor: times, the range, names, and every ffmpeg
// line it can run.

"use strict";

module.exports = {
  module: "argus/argus.js",
  cases: (A, t) => {
    // times
    t.eq("tenths", A.stamp(83450), "1:23.5");
    t.eq("zero", A.stamp(0), "0:00.0");
    t.eq("an hour", A.stamp(3723400), "1:02:03.4");
    t.eq("seconds for ffmpeg", A.secs(1500), "1.500");

    // the range
    t.eq("kept inside the clip", A.clampRange(-50, 99999, 10000), { inMs: 0, outMs: 10000 });
    t.eq("in pushed past out gives way", A.clampRange(9990, 9995, 10000, "in"), { inMs: 9900, outMs: 10000 });
    t.eq("out pulled before in gives way", A.clampRange(500, 520, 10000, "out"), { inMs: 420, outMs: 520 });
    t.eq("a clip shorter than the minimum is all of it", A.clampRange(10, 20, 80), { inMs: 0, outMs: 80 });
    t.eq("no out is the end", A.clampRange(0, undefined, 5000).outMs, 5000);
    t.eq("whole", A.whole(0, 5000, 5000), true);

    // names
    const src = "/home/u/Videos/Captures/2026-10-20-232145-DP-1.mp4";
    t.eq("beside the original", A.outPath(src, "mp4"), "/home/u/Videos/Captures/2026-10-20-232145-DP-1-cut.mp4");
    t.eq("a gif", A.outPath(src, "gif"), "/home/u/Videos/Captures/2026-10-20-232145-DP-1-cut.gif");
    const taken = new Set([A.outPath(src, "webm"), A.outPath(src, "webm").replace("-cut.", "-cut-2.")]);
    t.eq("taken names are stepped past", A.outPath(src, "webm", (p) => taken.has(p)), "/home/u/Videos/Captures/2026-10-20-232145-DP-1-cut-3.webm");
    t.eq("save as keeps the format's extension", A.withExt("/tmp/clip.mp4", "gif"), "/tmp/clip.gif");
    t.eq("…and adds one", A.withExt("/tmp/clip", "webm"), "/tmp/clip.webm");
    t.eq("a name the picker never asked about has free ones after it", A.variants("/tmp/clip-cut.mp4").slice(0, 3),
      ["/tmp/clip-cut.mp4", "/tmp/clip-cut-2.mp4", "/tmp/clip-cut-3.mp4"]);
    t.eq("…with no extension too", A.variants("/tmp/clip").slice(1, 2), ["/tmp/clip-2"]);

    // commands
    const o = { inMs: 1500, outMs: 4000, format: "mp4", exact: false, audio: true, gifWidth: 720, gifFps: 15, loop: true };
    const copy = A.ffmpegArgs(src, "/o.mp4", o);
    t.eq("ffmpeg first", copy[0], "ffmpeg");
    t.has("seeks before the input", copy.join(" "), "-ss 1.500 -t 2.500 -i " + src);
    t.has("a plain cut copies", copy.join(" "), "-c:v copy");
    t.has("…its audio too", copy.join(" "), "-c:a copy");
    t.has("progress on stdout", copy.join(" "), "-progress pipe:1");
    t.eq("the output last", copy[copy.length - 1], "/o.mp4");
    const exact = A.ffmpegArgs(src, "/o.mp4", Object.assign({}, o, { exact: true, audio: false }));
    t.has("an exact cut re-encodes", exact.join(" "), "-c:v libx264");
    t.has("no audio is -an", exact.join(" "), "-an");
    const gif = A.ffmpegArgs(src, "/o.gif", Object.assign({}, o, { format: "gif" }));
    t.has("gif palette", gif.join(" "), "palettegen");
    t.has("gif rate", gif.join(" "), "fps=15");
    t.has("gif never upscales, longest side", gif.join(" "), "scale='if(gte(iw,ih),min(720,iw),-1)':'if(gte(iw,ih),-1,min(720,ih))'");
    t.has("gif 128 colors", gif.join(" "), "max_colors=128");
    t.has("gif loops", gif.join(" "), "-loop 0");
    t.eq("gif has no audio flags", gif.indexOf("-an") < 0 && gif.indexOf("-c:a") < 0, true);
    const orig = A.ffmpegArgs(src, "/o.gif", Object.assign({}, o, { format: "gif", gifWidth: 0, loop: false }));
    t.eq("original size is not scaled", orig.join(" ").indexOf(",scale=") < 0, true);
    t.has("once", orig.join(" "), "-loop -1");
    const sq = A.squeezeArgs("/o dir/a.gif");
    t.eq("squeeze runs gifsicle on the file as an argument", sq[sq.length - 1], "/o dir/a.gif");
    t.has("squeeze is lossy, in place", sq[2], "gifsicle -O2 --lossy=60 -b");
    t.has("squeeze skips without gifsicle", sq[2], "command -v gifsicle >/dev/null || exit 0");
    const span = A.estimateSpan({ inMs: 1000, outMs: 9000 });
    t.eq("an estimate samples the middle two seconds", [span.inMs, span.outMs, span.scale], [4000, 6000, 4]);
    t.eq("a short cut is sampled whole", A.estimateSpan({ inMs: 0, outMs: 1500 }).scale, 1);
    const est = A.estimateArgs(src, Object.assign({}, o, { format: "gif", inMs: 1000, outMs: 9000 }));
    t.has("the estimate makes the sample with the save's own command", est.join(" "), "-ss 4.000 -t 2.000 -i " + src);
    t.has("…squeezed the same way", est[2], "gifsicle -O2 --lossy=60 -b \"$g\"");
    t.eq("…into its own temporary file", est.indexOf("") < 0 && /mktemp/.test(est[2]), true);
    t.eq("megabytes", [A.megabytes(838860), A.megabytes(13 * 1048576 + 400000)], ["0.8 MB", "13 MB"]);
    const webm = A.ffmpegArgs(src, "/o.webm", Object.assign({}, o, { format: "webm" }));
    t.has("webm is vp9", webm.join(" "), "libvpx-vp9");
    t.has("…with opus", webm.join(" "), "libopus");
    // the crop: even, clamped, null for the whole picture; MP4 copy turns into an encode
    t.eq("crop rounds to even", A.cropOf({ x: 11, y: 7, w: 301, h: 201 }, 1920, 1080), { x: 10, y: 6, w: 300, h: 200 });
    t.eq("crop of everything is none", A.cropOf({ x: 0, y: 0, w: 1920, h: 1080 }, 1920, 1080), null);
    t.eq("crop clamped inside", A.cropOf({ x: 1900, y: 0, w: 400, h: 100 }, 1920, 1080), { x: 1900, y: 0, w: 20, h: 100 });
    const c = { x: 10, y: 6, w: 300, h: 200 };
    const cc = A.ffmpegArgs(src, "/o.mp4", Object.assign({}, o, { crop: c }));
    t.has("a cropped mp4 is encoded", cc.join(" "), "libx264");
    t.has("…through the crop filter", cc.join(" "), "-vf crop=300:200:10:6");
    t.has("a cropped gif crops first", A.ffmpegArgs(src, "/o.gif", Object.assign({}, o, { format: "gif", crop: c })).join(" "), "crop=300:200:10:6,fps=");
    t.has("a cropped webm", A.ffmpegArgs(src, "/o.webm", Object.assign({}, o, { format: "webm", crop: c })).join(" "), "-vf crop=300:200:10:6");
    t.eq("ratio of 1:1", A.ratioValue("1:1"), 1);
    // every argument a plain string, so Process gets it untouched
    t.eq("all strings", [copy, exact, gif, webm].every((a) => a.every((x) => typeof x === "string")), true);

    // progress
    t.eq("progress", A.progressOf("frame=10\nout_time_us=1250000\nprogress=continue\n", 2500), 0.5);
    t.eq("the last block wins", A.progressOf("out_time_us=1\nout_time_us=2500000\n", 2500), 1);
    t.eq("none yet", A.progressOf("frame=1\n", 2500), 0);

    // settings
    t.eq("defaults", A.parseSettings(""), A.defaults());
    t.eq("unknown widths fall back", A.parseSettings('{"gifWidth":123}').gifWidth, 720);
    t.eq("round trip", A.parseSettings(A.serializeSettings({ format: "gif", gifFps: 24 })).gifFps, 24);

    // the filmstrip
    const strip = A.stripArgs(src, "/tmp/s", 12000, 12);
    t.has("one frame a second for 12 in 12 s", strip.join(" "), "fps=1.0000,scale=-2:96");
    t.has("into the dir", strip.join(" "), "/tmp/s/f%02d.jpg");

    // ── frames, as pictures ──
    t.eq("a frame's time", A.frameStamp(83450), "01m23.450s");
    t.eq("…an hour in", A.frameStamp(3723004), "1h02m03.004s");
    t.eq("…as wide as the hour-long video's others", A.frameStamp(5000, true), "0h00m05.000s");
    t.eq("a frame beside the original", A.framePath(src, 83450, "png"), "/home/u/Videos/Captures/2026-10-20-232145-DP-1-01m23.450s.png");
    t.eq("…as WebP", A.framePath(src, 0, "webp").replace(/.*-/, ""), "00m00.000s.webp");
    t.eq("odd formats are PNG", A.frameFormatOf("tiff").ext, ".png");
    t.eq("a run's directory", A.framesDir("/tmp/out/", src), "/tmp/out/2026-10-20-232145-DP-1-frames");
    const fo = Object.assign(A.defaults(), { inMs: 5300, outMs: 9300 });
    t.eq("one a second for 4 s", A.framesEstimate(Object.assign({}, fo, { framesMode: "secs", framesSecs: 1 }), 30), 4);
    t.eq("all at 30 fps", A.framesEstimate(Object.assign({}, fo, { framesMode: "all" }), 30), 120);
    t.eq("1 in 10", A.framesEstimate(Object.assign({}, fo, { framesMode: "nth", framesNth: 10 }), 30), 12);
    t.eq("a count is the count", A.framesEstimate(Object.assign({}, fo, { framesMode: "count", framesCount: 25 }), 30), 25);
    const one = A.frameArgs(src, "/o.png", { seekSec: 2.5, format: "png" });
    t.has("half a millisecond early, before -i", one.join(" "), "-ss 2.499500 -i " + src);
    t.has("one picture, not a sequence", one.join(" "), "-frames:v 1 -update 1 /o.png");
    t.has("JPEG quality", A.frameArgs(src, "/o.jpg", { seekSec: 0, format: "jpg" }).join(" "), "-q:v 2 /o.jpg");
    t.has("a cropped frame", A.frameArgs(src, "/o.png", { seekSec: 0, format: "png", crop: c }).join(" "), "-vf crop=300:200:10:6");
    const run = A.framesArgs("/v/a%b.mkv", "/out/100%", Object.assign({}, fo, { framesMode: "secs", framesSecs: 2, format: "webp", startSec: 1.5 }));
    t.has("a % is not the counter", run[run.length - 1], "/out/100%%/a%%b-%09d.webp");
    t.has("the file's start moved to 0, in ms", run.join(" "), "settb=1/1000,setpts=PTS-1.500000/TB,trim=start=5.300:end=9.300");
    t.has("the first frame of each 2 s step", run.join(" "), "floor((t-5.300)/2.000000)");
    t.has("named by their time", run.join(" "), "-copyts -ss 5.300 -i /v/a%b.mkv");
    t.has("…in ms", run.join(" "), "-enc_time_base 1/1000 -frame_pts 1");
    t.has("every 10th", A.framesArgs(src, "/o", Object.assign({}, fo, { framesMode: "nth", framesNth: 10 })).join(" "), "select='not(mod(n\\,10))'");
    t.has("a count stops at it", A.framesArgs(src, "/o", Object.assign({}, fo, { framesMode: "count", framesCount: 25 })).join(" "), "-frames:v 25");
    t.eq("the rename's arguments", A.framesRenameArgs("/o/x-frames", "/v/x.mp4", "jpg", true).slice(3), ["sh", "/o/x-frames", "x", ".jpg", "1"]);
    t.eq("frames written so far", A.framesDone("frame=42"), 42);
    t.eq("…not another key", A.framesDone("fps=30"), -1);
    t.eq("frame settings fall back", A.parseSettings('{"frameFormat":"bmp","framesSecs":3}').frameFormat, "png");
    t.eq("…and round trip", A.parseSettings(A.serializeSettings({ framesMode: "count", framesCount: 50 })).framesCount, 50);
    t.eq("frame commands all strings", [one, run, A.pickArgs(src, 1.5)].every((a) => a.every((x) => typeof x === "string")), true);

    // ── recording preferences ──
    t.eq("the line argus.lua reads", A.recPrefsLine({ recCountdown: 3, recAudio: "both", recBigPointer: true, recCamera: false }),
      "countdown=3 audio=both pointer=1 camera=0");
    t.eq("odd values fall back", A.recPrefsLine({ recCountdown: 99, recAudio: "loud" }), "countdown=10 audio=system pointer=0 camera=0");
    t.eq("nothing is how it was", A.recPrefsLine(null), "countdown=0 audio=system pointer=0 camera=0");
    t.eq("bottom right", A.cornerAnchors("bottomRight"), { top: false, bottom: true, left: false, right: true });
    t.eq("top left", A.cornerAnchors("topLeft"), { top: true, bottom: false, left: true, right: false });
  }
};
