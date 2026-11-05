.pragma library
// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE DROP SHELF'S BOOKKEEPING (2026-11-04) — what a drop holds, and what
// dragging a held thing out carries. Pure, so oracle/tests/shelf.js pins it;
// the shelf itself is morpheus/DropShelf.qml.
//
// An item:  { id, kind, path, name, text, owned }
//   kind    "file" | "dir" | "text" | "image"
//   path    where it is: a file of this computer as it is (held by
//           reference, never moved or copied), or one the shelf wrote into
//           its runtime directory (`owned`: words, a web picture, picture
//           data) — gone at logout with that directory
//   text    a text item's words, carried out as they are

// a drop's urls and text, sorted: files of this computer, web addresses,
// and words when there is neither (a browser drags a picture's page link as
// text beside it, which is not words then)
function sorted(urls, text) {
  const out = { files: [], web: [], words: "" };
  const rest = [];
  for (const raw of (urls || [])) {
    const u = String(raw);
    if (/^file:\/\//i.test(u)) {
      let p = u.replace(/^file:\/\/[^\/]*/i, "");
      try { p = decodeURIComponent(p); } catch (e) { /* kept as written */ }
      if (p !== "" && out.files.indexOf(p) < 0) out.files.push(p);
    } else if (/^https?:\/\//i.test(u)) {
      if (out.web.indexOf(u) < 0) out.web.push(u);
    } else if (u.trim() !== "") rest.push(u);
  }
  if (out.files.length === 0 && out.web.length === 0)
    out.words = String(text || "").trim() !== "" ? String(text) : rest.join("\n");
  return out;
}

function baseName(p) {
  const s = String(p || "").replace(/\/+$/, "");
  const i = s.lastIndexOf("/");
  return i < 0 ? s : s.slice(i + 1);
}

// the words' first line, short: a text item's name
function textName(t) {
  const line = String(t || "").split("\n").map((l) => l.trim()).find((l) => l !== "") || "Text";
  return line.length > 60 ? line.slice(0, 59) + "…" : line;
}

const IMAGE = /\.(png|jpe?g|gif|webp|avif|bmp|svg|tiff?|heic|jxl|ico)$/i;
function isImage(p) { return IMAGE.test(String(p || "")); }

// items for files dropped, leaving out what is already held
function filesIn(items, paths, isDir, nextId) {
  const held = {};
  for (const it of items) if (it.path) held[it.path] = true;
  const out = [];
  let id = nextId;
  for (const p of paths) {
    if (held[p]) continue;
    held[p] = true;
    const dir = !!(isDir && isDir[p]);
    out.push({ id: id++, kind: dir ? "dir" : isImage(p) ? "image" : "file",
               path: p, name: baseName(p) || p, text: "", owned: false });
  }
  return out;
}

function fileUrl(p) {
  return "file://" + String(p || "").split("/").map(encodeURIComponent).join("/");
}

// what dragging items out carries. One text item: its words. Anything else:
// the files, as a uri-list (a text item among several goes as the file the
// shelf wrote it to), and their paths as text for what takes only text (a
// terminal)
function mimeOf(list) {
  const items = (list || []).filter((it) => it && (it.path || it.text));
  if (items.length === 1 && items[0].kind === "text")
    return { "text/plain": String(items[0].text) };
  const paths = items.map((it) => it.path).filter((p) => p);
  return { "text/uri-list": paths.map(fileUrl).join("\r\n") + "\r\n",
           "text/plain": paths.join("\n") };
}

// only a path inside the shelf's own directory is ever removed from disk
function ownedPath(p, dir) {
  const d = String(dir || "").replace(/\/+$/, "");
  const s = String(p || "");
  return d !== "" && s.startsWith(d + "/") && s.indexOf("/../") < 0 && !s.endsWith("/..");
}

// the stored list, read back: anything malformed left out
function parse(text) {
  let o = null;
  try { o = JSON.parse(String(text || "")); } catch (e) { return []; }
  const list = o && Array.isArray(o.items) ? o.items : [];
  return list.filter((it) => it && typeof it === "object" && typeof it.id === "number"
    && ["file", "dir", "text", "image"].indexOf(it.kind) >= 0
    && (typeof it.path === "string" && it.path !== ""))
    .map((it) => ({ id: it.id, kind: it.kind, path: it.path, name: String(it.name || baseName(it.path)),
                    text: String(it.text || ""), owned: !!it.owned }));
}
