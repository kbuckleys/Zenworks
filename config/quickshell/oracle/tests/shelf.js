// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// The drop shelf's bookkeeping (morpheus/shelf.js): what a drop holds and
// what a drag out carries.

"use strict";

module.exports = {
  module: "morpheus/shelf.js",
  cases: (S, t) => {
    t.eq("files of this computer, decoded", S.sorted(["file:///home/a/My%20Doc.pdf", "file://host/tmp/x"], "").files,
      ["/home/a/My Doc.pdf", "/tmp/x"]);
    t.eq("a browser's picture: its address, not its page link as words",
      S.sorted(["https://e.com/p.png"], "https://e.com/page"), { files: [], web: ["https://e.com/p.png"], words: "" });
    t.eq("words alone", S.sorted([], "hello\nthere").words, "hello\nthere");
    t.eq("a file twice is held once", S.sorted(["file:///a", "file:///a"], "").files, ["/a"]);
    t.eq("an item a file, an image, a directory",
      S.filesIn([], ["/a/x.txt", "/a/y.PNG", "/a/d"], { "/a/d": true }, 5).map((i) => [i.id, i.kind, i.name]),
      [[5, "file", "x.txt"], [6, "image", "y.PNG"], [7, "dir", "d"]]);
    t.eq("what is held is not held again",
      S.filesIn([{ id: 1, path: "/a/x" }], ["/a/x", "/a/z"], {}, 2).map((i) => i.path), ["/a/z"]);
    t.eq("a text item's name is its first line", S.textName("\n  first line \nsecond"), "first line");
    t.eq("and short", S.textName("x".repeat(80)).length, 60);
    t.eq("one text item carries its words", S.mimeOf([{ kind: "text", path: "/r/t.txt", text: "hi" }]), { "text/plain": "hi" });
    t.eq("files carry a uri-list and their paths",
      S.mimeOf([{ kind: "file", path: "/a b/c" }, { kind: "text", path: "/r/t.txt", text: "hi" }]),
      { "text/uri-list": "file:///a%20b/c\r\nfile:///r/t.txt\r\n", "text/plain": "/a b/c\n/r/t.txt" });
    t.eq("only the shelf's own files are removed",
      [S.ownedPath("/run/u/zenworks/shelf/t.txt", "/run/u/zenworks/shelf"),
       S.ownedPath("/home/a/t.txt", "/run/u/zenworks/shelf"),
       S.ownedPath("/run/u/zenworks/shelf/../../x", "/run/u/zenworks/shelf"),
       S.ownedPath("/run/u/zenworks/shelfx/t", "/run/u/zenworks/shelf"),
       S.ownedPath("/x", "")], [true, false, false, false, false]);
    t.eq("a stored list read back, the broken left out",
      S.parse('{"items":[{"id":1,"kind":"file","path":"/a"},{"id":"2","kind":"file","path":"/b"},{"id":3,"kind":"evil","path":"/c"},{"id":4,"kind":"text","path":""}]}')
        .map((i) => [i.id, i.name]), [[1, "a"]]);
    t.eq("not JSON is nothing", S.parse("{"), []);
  }
};
