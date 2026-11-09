// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// ── CONNECT TO SERVER ────────────────────────────────────────────────────
// The address, what to call it, who you are, and Connect (2026-10-21). An
// address is taken as typed in any of the usual ways (network.js
// normalize: smb://, \\server\share, user@host:path, https:// for
// WebDAV, a bare server/share). Also where a kept place goes when it has
// to ask: a password refused, or a question gvfs put (an SSH host key
// never seen), which is answered here with "Connect anyway".
//
// The work is terminus/Network.qml's. `term` is the terminus window, as in
// every sheet split out of it; its sheet slot is s12.

import QtQuick
import "../morpheus"
import "../morpheus/controls" as Controls
import "network.js" as N

Rectangle {
  id: conn
  property var term: null
  anchors.fill: parent
  z: 13
  visible: opacity > 0.01
  opacity: conn.open ? 1 : 0
  color: "transparent"
  Rectangle {
    anchors.fill: parent
    anchors.topMargin: term.tabStripRef.height + term.crumbBarRef.height
    color: term.cardScrim
  }
  Rectangle {
    width: term.sideRef.width
    height: term.tabStripRef.height + term.crumbBarRef.height
    color: term.cardScrim
  }
  Behavior on opacity {
    NumberAnimation {
      duration: conn.open ? connSheet.slideIn : connSheet.slideOut
      easing.type: Zenon.ease
    }
  }

  property bool open: false
  readonly property int textSize: 16
  // a kept place being edited or asked about; null for a new one
  property var place: null
  property bool remember: true
  property bool keep: true
  // what the last try said: "" · the refusal · gvfs' question
  property string said: ""
  property bool question: false
  // the question shown (gvfs' words) and the address it was asked for:
  // "Connect anyway" says yes to that question only, never to whatever a
  // retyped address (or a changed host key) asks next
  property string asked: ""
  property string askedUri: ""
  property int rev: 0

  readonly property string uri: { conn.rev; return N.normalize(addr.text); }
  readonly property bool isSmb: /^smb:/.test(conn.uri)
  readonly property bool working: !!term && term.networkRef.busy !== ""
  readonly property bool ready: conn.uri !== "" && !conn.working

  // row: a sidebar row or null; why: netplaces.py's answer that sent it here
  function ask(row, why) {
    conn.place = row && row.uri ? row : null;
    addr.text = row ? row.uri : "";
    name.text = row ? (row.name || "") : "";
    user.text = row ? (row.user || "") : "";
    domain.text = row ? (row.domain || "") : "";
    pass.text = "";
    conn.keep = !row || !!row.saved;
    conn.question = !!why && why.why === "question";
    conn.said = why ? N.failWords(why) : "";
    conn.rev++;
    conn.asked = conn.question ? String(why.message || "") : "";
    conn.askedUri = conn.question ? conn.uri : "";
    conn.open = true;
    claim.begin();
  }
  FocusRetry {
    id: claim
    interval: 40
    checkFirst: true
    readonly property var first: addr.text === "" ? addr : (user.text === "" && !conn.question ? user : pass)
    live: conn.open
    took: claim.first.focused
    onPlace: {
      connKeys.forceActiveFocus();
      claim.first.claim();
    }
  }
  function dismiss() {
    conn.open = false;
    pass.text = "";
    term.contentRef.forceActiveFocus();
  }
  function ring() { return conn.isSmb ? [addr, name, user, domain, pass] : [addr, name, user, pass]; }
  function focusFrom(cur, dir) {
    const r = conn.ring();
    const i = r.indexOf(cur);
    const next = r[((i < 0 ? 0 : i + dir) + r.length) % r.length];
    if (next) next.claim();
  }

  function commit() {
    if (!conn.ready) return;
    const p = { uri: conn.uri, name: name.text.trim(), user: user.text.trim(), domain: conn.isSmb ? domain.text.trim() : "" };
    const accept = conn.question && N.sameUri(conn.askedUri, p.uri) ? conn.asked : "";
    const place = conn.place;
    const keep = conn.keep;
    conn.said = "";
    conn.question = false;
    term.networkRef.connect(p, { password: pass.text, remember: conn.remember, accept: accept }, (r) => {
      // the sheet may be up for another place by now: what was asked is
      // answered from what was asked, and this sheet is only touched if it
      // is still that one
      const same = conn.open && conn.place === place;
      if (r && r.ok) {
        // an edited address replaces the old one
        if (place && place.saved && !N.sameUri(place.uri, p.uri)) term.networkRef.forget(place.uri);
        if (keep) term.networkRef.keep(p);
        if (same) conn.dismiss();
        return;
      }
      if (!same) return;
      conn.question = !!r && r.why === "question";
      conn.said = N.failWords(r);
      conn.asked = conn.question ? String(r.message || "") : "";
      conn.askedUri = conn.question ? p.uri : "";
      pass.text = "";
      if (conn.open) (conn.question ? addr : pass).claim();
    });
  }

  InputShield {
    keepTop: term.tabStripRef.height + term.crumbBarRef.height
    onClicked: conn.dismiss()
  }

  FocusScope {
    id: connKeys
    anchors.fill: parent
    Keys.onPressed: (e) => {
      if (e.key !== Qt.Key_Escape) return;
      e.accepted = true;
      conn.dismiss();
    }

    TermSheet {
      host: term
      note: "s12"
      id: connSheet
      leftInset: term.sideRef.width
      floating: false
      title: term.sheetTitle
      glyph: term.sheetGlyph
      titleInk: term.sheetTitleInk
      glyphInk: term.sheetGlyphInk
      shown: conn.open
      fromTop: term.tabStripRef.height + term.crumbBarRef.height
      cardW: 720
      cardH: connCol.implicitHeight

      Column {
        id: connCol
        width: parent.width
        topPadding: 8

        // the address, and what kind of place it is
        Item {
          width: parent.width
          height: 46
          BulkField {
            id: addr
            textSize: conn.textSize
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            // the full width, as every field under it (user, 2026-10-22);
            // what kind of place it is sits inside its right end
            trailRoom: kind.text !== "" ? kind.implicitWidth + 10 : 0
            mono: true
            ghost: "smb://server/share · user@host:/path · https://…"
            onTextChanged: {
              conn.rev++;
              // another address: the question shown was not its question
              if (conn.question && !N.sameUri(conn.askedUri, conn.uri)) {
                conn.question = false;
                conn.said = "";
              }
            }
            onTabbed: conn.focusFrom(addr, 1)
            onBackTabbed: conn.focusFrom(addr, -1)
            onAccepted: conn.commit()
          }
          Text {
            textFormat: Text.PlainText
            id: kind
            anchors.right: addr.right
            anchors.rightMargin: 10
            anchors.verticalCenter: addr.verticalCenter
            z: 1
            text: conn.uri !== "" ? N.kindWords(conn.uri) : addr.text.trim() !== "" ? "Not an address" : ""
            color: conn.uri !== "" ? Zenon.accentKey : Zenon.red
            font.family: Zenon.face
            font.weight: Zenon.weight
            font.pixelSize: conn.textSize - 2
          }
        }

        Item {
          width: parent.width
          height: 46
          BulkField {
            id: name
            textSize: conn.textSize
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            ghost: conn.uri !== "" ? "Name — " + N.label({ uri: conn.uri }) : "Name (optional)"
            onTabbed: conn.focusFrom(name, 1)
            onBackTabbed: conn.focusFrom(name, -1)
            onAccepted: conn.commit()
          }
        }

        Hairline { width: parent.width }

        // who you are; empty is a guest, where the server allows one
        Item {
          width: parent.width
          height: 52
          BulkField {
            id: user
            textSize: conn.textSize
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: (parent.width - 32 - (conn.isSmb ? 24 : 12)) / (conn.isSmb ? 3 : 2)
            ghost: "User (empty: guest)"
            onTabbed: conn.focusFrom(user, 1)
            onBackTabbed: conn.focusFrom(user, -1)
            onAccepted: conn.commit()
          }
          BulkField {
            id: domain
            visible: conn.isSmb
            textSize: conn.textSize
            anchors.left: user.right
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: user.width
            ghost: "Domain"
            onTabbed: conn.focusFrom(domain, 1)
            onBackTabbed: conn.focusFrom(domain, -1)
            onAccepted: conn.commit()
          }
          BulkField {
            id: pass
            textSize: conn.textSize
            masked: true
            anchors.left: conn.isSmb ? domain.right : user.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            ghost: "Password"
            onTabbed: conn.focusFrom(pass, 1)
            onBackTabbed: conn.focusFrom(pass, -1)
            onAccepted: conn.commit()
          }
        }

        Item {
          width: parent.width
          height: 40
          Row {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 22
            Controls.Check {
              label: "Remember the password"
              lit: conn.remember
              onToggled: conn.remember = !conn.remember
            }
            Controls.Check {
              label: "Keep in the sidebar"
              lit: conn.keep
              onToggled: conn.keep = !conn.keep
            }
          }
        }

        Hairline { width: parent.width }

        // what went wrong, or the question; and the answers
        Item {
          width: parent.width
          height: Math.max(48, saidText.implicitHeight + 20)
          Text {
            textFormat: Text.PlainText
            id: saidText
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: actions.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 4
            elide: Text.ElideRight
            text: conn.said !== "" ? conn.said
              : "Passwords stay with gvfs and the system keyring, never in Terminus"
            color: conn.said === "" ? Zenon.accentMuted : conn.question ? Zenon.yellow : Zenon.red
            font.family: Zenon.face
            font.weight: Zenon.weight
            font.pixelSize: conn.textSize - 3
          }
          Row {
            id: actions
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: Zenon.buttonGap
            DialogButton {
              label: "Cancel"
              onClicked: conn.dismiss()
            }
            BusyButton {
              label: conn.question ? "Connect anyway" : "Connect"
              ink: conn.question ? Zenon.yellow : Zenon.accent
              primary: true
              ready: conn.ready
              busy: conn.working
              busyText: "Connecting\u2026"
              onClicked: conn.commit()
            }
          }
        }
      }
    }
  }
}
