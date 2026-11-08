.pragma library
// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE TWO ONE-LINERS EVERY LIBRARY NEEDS, once (audit 2026-11-08).
//
// A text as one shell word, and a text safe inside StyledText. They were
// written out again in ten .js libraries, because a library cannot see
// morpheus' Strings singleton without `.import qs.morpheus` — and that import
// resolves against the loaded config's root, so it fails in a harness and
// in any file loaded on its own. This one imports nothing: `.import
// "../morpheus/quote.js" as Quote` works from any library, in the shell, in a
// harness and in the node tests alike. Strings.shellQuote and
// Strings.escapeHtml are these.

// '…' with each ' as '\'' — the whole text one word, whatever is in it.
// null and undefined are the empty word.
function shellQuote(s) {
  return "'" + String(s ?? "").replace(/'/g, "'\\''") + "'";
}

// & < > as entities: the text shows as written, never as markup. Quotes are
// left alone (StyledText takes them as text outside a tag).
function escapeHtml(s) {
  return String(s ?? "")
    .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}
