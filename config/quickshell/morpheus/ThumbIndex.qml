// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE SHELL'S THUMBNAIL POOL, READ: `map` is thumbs.js' index for indexHit,
// empty until there is one. Picasso's viewer and Clio's Moments both held this.

import QtQuick
import Quickshell.Io
import "thumbs.js" as Thumbs

Item {
  id: index
  property var map: ({})
  function reload() { file.reload(); }
  FileView {
    id: file
    path: Thumbs.indexPath()
    blockLoading: true
    printErrors: false
    onTextChanged: {
      let o = null;
      try { o = JSON.parse(String(file.text() || "{}")); } catch (e) { o = null; }
      index.map = (o && typeof o === "object" && !Array.isArray(o)) ? o : ({});
    }
  }
}
