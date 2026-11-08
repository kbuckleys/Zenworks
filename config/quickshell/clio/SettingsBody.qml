// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// CLIO'S SETTINGS — Apple's Notes and Journal settings, those that apply:
// how a new note starts, the order, the date headings, ticked items
// sinking, the text size, the fonts; the journal's reminder (a time, the
// days); the password and how soon locked notes close again; the stickies
// shown.

import QtQuick
import "../morpheus"
import "../morpheus/controls" as Controls
import "../terminus"
import "notes.js" as N

Column {
  id: sb
  property var win: null
  signal closed()
  readonly property var mgr: sb.win ? sb.win.mgr : null
  padding: 22
  spacing: 14
  readonly property int gap: 36
  readonly property real colW: Math.floor((sb.width - 44 - sb.gap) / 2)
  // the one open dropdown (terminus BulkDrop's host contract)
  property var bulkOpenDrop: null
  property real wheelStep: 120
  // where a dropdown's list goes: the sheet's own root (the Sheet this
  // body sits in), over its card and unclipped by it — not the window's
  // stage, which is under the sheet (user, 2026-11-08); a click off an
  // open list puts it away
  readonly property Item sheetRoot: {
    for (let p = sb.parent; p; p = p.parent) if ("cardW" in p) return p;
    return sb;
  }
  Item {
    id: dropLayer
    parent: sb.sheetRoot
    anchors.fill: parent
    z: 300
    MouseArea {
      anchors.fill: parent
      enabled: sb.bulkOpenDrop !== null
      onClicked: sb.bulkOpenDrop = null
    }
  }

  // two columns: the notes (and the stickies) on the left, the journal and
  // the lock on the right
  Row {
    spacing: sb.gap
    Column {
      width: sb.colW
      spacing: 14
          SideHead { width: sb.colW; ruled: false; label: "Notes" }
          SettingLine {
            width: sb.colW
            label: "New notes start with"
            Segments { options: [["title", "Title"], ["heading", "Heading"], ["subheading", "Subheading"], ["body", "Body"]]; current: sb.mgr ? sb.mgr.startWith : "title"; textSize: Zenon.px(12); onChose: (v) => sb.mgr.set("startWith", v) }
          }
          SettingLine {
            width: sb.colW
            label: "Sort notes by"
            Segments { options: [["modified", "Edited"], ["created", "Created"], ["title", "Title"]]; current: sb.mgr ? sb.mgr.sort : "modified"; textSize: Zenon.px(12); onChose: (v) => sb.mgr.set("sort", v) }
          }
          SettingLine {
            width: sb.colW
            label: "Group notes by date"
            Controls.Check { lit: sb.mgr ? sb.mgr.groupByDate : true; onToggled: sb.mgr.set("groupByDate", !(sb.mgr ? sb.mgr.groupByDate : true)) }
          }
          SettingLine {
            width: sb.colW
            label: "Sort ticked items"
            note: "A box ticked moves under the ones still to do"
            Controls.Check { lit: sb.mgr ? sb.mgr.sinkChecked : false; onToggled: sb.mgr.set("sinkChecked", !(sb.mgr ? sb.mgr.sinkChecked : false)) }
          }
          SettingLine {
            width: sb.colW
            label: "Text size"
            note: "ctrl = and ctrl −"
            // on ctrl = / ctrl −'s own tenths, and the nearest lit when a
            // step lands between two (1.1 lit nothing: user, 2026-11-08)
            Segments {
              readonly property var sizes: [0.9, 1, 1.2, 1.4]
              options: [[0.9, "S"], [1, "M"], [1.2, "L"], [1.4, "XL"]]
              current: {
                const s = sb.mgr ? sb.mgr.textScale : 1;
                return sizes.reduce((a, b) => Math.abs(b - s) < Math.abs(a - s) ? b : a);
              }
              textSize: Zenon.px(12)
              onChose: (v) => sb.mgr.set("textScale", v)
            }
          }
          SettingLine {
            width: sb.colW
            label: "Templates"
            note: !sb.mgr || sb.mgr.templates.length === 0 ? "None yet — save one from a note's menu, or import one" : sb.mgr.templates.map((t) => t.name).join(", ")
            DialogButton { visible: !!sb.mgr && !!sb.mgr.fileManager; label: "Import"; onClicked: { sb.closed(); sb.win.importTemplate(); } }
            DialogButton {
              id: tplBtn
              visible: !!sb.mgr && sb.mgr.templates.length > 0
              label: "Delete"
              onClicked: {
                const p = tplBtn.mapToItem(sb.win.stageItem, 0, tplBtn.height + 4);
                sb.win.menuRef.open(p.x, p.y, sb.mgr.templates.map((x) => ({ text: x.name, icon: "", danger: true, run: () => sb.mgr.deleteTemplate(x.id) })));
              }
            }
          }
          SettingLine {
            width: sb.colW
            label: "Smart punctuation"
            note: "“Curly quotes” and — dashes as you type"
            Controls.Check { lit: sb.mgr ? sb.mgr.smartPunct : true; onToggled: sb.mgr.set("smartPunct", !(sb.mgr ? sb.mgr.smartPunct : true)) }
          }
          SettingLine {
            width: sb.colW
            label: "Stickies on the desktop"
            Controls.Check { lit: Clio.shown; onToggled: Clio.shown = !Clio.shown }
          }
    }
    Column {
      width: sb.colW
      spacing: 14
          SideHead { width: sb.colW; ruled: false; label: "Journal" }
          SettingLine {
            width: sb.colW
            label: "Today's entry starts from"
            note: "ctrl t opens today's entry, or begins it"
            DialogButton {
              id: dailyBtn
              readonly property var t: sb.mgr ? sb.mgr.templates.find((x) => x.id === sb.mgr.meta.daily) : null
              label: t ? t.name : "Nothing"
              onClicked: {
                const p = dailyBtn.mapToItem(sb.win.stageItem, 0, dailyBtn.height + 4);
                sb.win.menuRef.open(p.x, p.y, [{ text: "Nothing", icon: "", run: () => sb.mgr.setDaily("") }]
                  .concat(sb.mgr.templates.map((x) => ({ text: x.name, icon: "\u{F0DC9}", run: () => sb.mgr.setDaily(x.id) }))));
              }
            }
          }
          SettingLine {
            width: sb.colW
            label: "Blur previews"
            note: "Entries' words and pictures frosted in the list until the pointer is on them"
            Controls.Check { lit: sb.mgr ? sb.mgr.journalBlur : false; onToggled: sb.mgr.set("journalBlur", !(sb.mgr ? sb.mgr.journalBlur : false)) }
          }
          SettingLine {
            width: sb.colW
            label: "Remind me to write"
            note: "A notification, unless something was written that day"
            Controls.Check { lit: sb.mgr ? sb.mgr.remind : false; onToggled: sb.mgr.set("remind", !(sb.mgr ? sb.mgr.remind : false)) }
          }
          SettingLine {
            width: sb.colW
            visible: !!sb.mgr && sb.mgr.remind
            label: "At"
            Row {
              spacing: Zenon.buttonGap
              DialogButton { glyph: true; label: ""; onClicked: sb.shift(-15) }
              Text { anchors.verticalCenter: parent.verticalCenter; text: sb.mgr ? sb.mgr.remindAt : ""; color: Zenon.ink; font.family: Zenon.face; font.weight: Zenon.titleWeight; font.pixelSize: Zenon.px(15); font.features: { "tnum": 1 } }
              DialogButton { glyph: true; label: ""; onClicked: sb.shift(15) }
            }
          }
          SettingLine {
            width: sb.colW
            visible: !!sb.mgr && sb.mgr.remind
            label: "On"
            Row {
              spacing: 4
              Repeater {
                model: [[1, "M"], [2, "T"], [3, "W"], [4, "T"], [5, "F"], [6, "S"], [0, "S"]]
                delegate: MoodChip {
                  required property var modelData
                  width: 30
                  word: modelData[1]
                  on: sb.mgr.remindDays.indexOf(modelData[0]) >= 0
                  onClicked: sb.mgr.set("remindDays", on ? sb.mgr.remindDays.filter((d) => d !== modelData[0]) : sb.mgr.remindDays.concat([modelData[0]]))
                }
              }
            }
          }

          SideHead { width: sb.colW; ruled: false; label: "Locking" }
          SettingLine {
            width: sb.colW
            label: "The Clio password"
            note: !sb.mgr ? "" : sb.mgr.hasPassword ? (sb.mgr.unlocked ? "Set, and open now" : "Set") : "Not set yet — asked the first time something is locked"
            Row {
              spacing: Zenon.buttonGap
              DialogButton { visible: !!sb.mgr && sb.mgr.unlocked; label: "Lock now"; ink: Zenon.yellow; onClicked: sb.win.lockNow() }
              DialogButton { label: sb.mgr && sb.mgr.hasPassword ? "Change" : "Set"; onClicked: { sb.closed(); sb.win.changePassword(); } }
            }
          }
          SettingLine {
            width: sb.colW
            label: "Lock again after"
            Segments { options: [[5, "5 min"], [10, "10"], [30, "30"], [60, "1 h"], [0, "Never"]]; current: sb.mgr ? sb.mgr.lockAfter : 10; textSize: Zenon.px(12); onChose: (v) => sb.mgr.set("lockAfter", v) }
          }

          // ── SPELLING ── hunspell's (ClioManager's spelling), in notes,
          // entries and stickies
          SideHead { width: sb.colW; ruled: false; label: "Spelling" }
          SettingLine {
            width: sb.colW
            label: "Check spelling"
            note: sb.mgr && !sb.mgr.spellInfo.have ? "Hunspell is not installed" : "A red line under a word it does not know; right click for guesses"
            Controls.Check { lit: sb.mgr ? sb.mgr.spellOn : true; onToggled: sb.mgr.setSpellOn(!(sb.mgr ? sb.mgr.spellOn : true)) }
          }
          SettingLine {
            width: sb.colW
            visible: !!sb.mgr && sb.mgr.spellOn
            label: "Languages"
            note: sb.mgr && sb.mgr.spellInfo.langs.length === 0 ? "No dictionaries yet" : "Words right in any one of them count as right"
            // A DROPDOWN (user, 2026-11-08), not a chip per dictionary: one
            // language, or every one installed at once ("*")
            BulkDrop {
              readonly property var langs: sb.mgr ? sb.mgr.spellInfo.langs : []
              readonly property var inUse: !sb.mgr ? [] : sb.mgr.spellLangs.length > 0 ? sb.mgr.spellLangs : sb.mgr.spellInfo.default
              visible: langs.length > 0
              host: sb
              overlay: dropLayer
              textSize: Zenon.px(13)
              options: langs.map((c) => [c, sb.langName(c)]).concat(langs.length > 1 ? [["*", "Every one of them"]] : [])
              value: inUse.length === 1 ? inUse[0] : (inUse.length > 1 && langs.every((c) => inUse.indexOf(c) >= 0) ? "*" : "")
              onPicked: (v) => sb.mgr.setSpellLangs(v === "*" ? langs.slice() : [v])
            }
          }
          SettingLine {
            width: sb.colW
            label: "More languages"
            note: "Dictionaries are packages: Ceres opens on them"
            DialogButton { label: "Find in Ceres"; onClicked: { sb.closed(); sb.mgr.moreLanguages(); } }
          }
          SettingLine {
            width: sb.colW
            visible: !!sb.mgr && (sb.mgr.meta.learned || []).length > 0
            label: "Learned words"
            note: sb.mgr ? (sb.mgr.meta.learned || []).length + ((sb.mgr.meta.learned || []).length === 1 ? " word" : " words") + ", kept with the notebook" : ""
            DialogButton {
              id: learnedBtn
              label: "Forget"
              onClicked: {
                const p = learnedBtn.mapToItem(sb.win.stageItem, 0, learnedBtn.height + 4);
                sb.win.menuRef.open(p.x, p.y, (sb.mgr.meta.learned || []).slice().sort()
                  .map((w) => ({ text: w, icon: "", danger: true, run: () => sb.mgr.unlearnWord(w) })));
              }
            }
          }
    }
  }
  Item {
    width: sb.width - 44
    height: 32
    DialogButton { anchors.right: parent.right; label: "Close"; ink: Zenon.accent; primary: true; onClicked: sb.closed() }
  }

  // the dictionaries looked at again whenever the sheet comes up: one added
  // through Ceres since shows
  Connections {
    target: sb.win
    ignoreUnknownSignals: true
    function onSetOpenChanged() { if (sb.win.setOpen && sb.mgr) sb.mgr.spellRefresh(); }
  }
  // "en_US" → "American English", in its own language; "de_DE" → "Deutsch
  // (Deutschland)" when the language's name does not already say where;
  // "-large" said after a dot
  function langName(code) {
    const base = String(code).split("-")[0];
    const l = Qt.locale(base);
    let n = l.nativeLanguageName || base;
    n = n.charAt(0).toUpperCase() + n.slice(1);
    const t = base.indexOf("_") > 0 ? l.nativeTerritoryName : "";
    const plain = Qt.locale(base.split("_")[0]).nativeLanguageName;
    const extra = String(code).indexOf("-") > 0 ? " · " + String(code).split("-").slice(1).join(" ") : "";
    return n + (t && n.toLowerCase() === String(plain).toLowerCase() ? " (" + t + ")" : "") + extra;
  }

  function shift(mins) {
    const m = sb.mgr.remindAt.match(/^(\d{1,2}):(\d{2})$/) || [0, 21, 0];
    const t = ((+m[1]) * 60 + (+m[2]) + mins + 1440) % 1440;
    sb.mgr.set("remindAt", N.two(Math.floor(t / 60)) + ":" + N.two(t % 60));
    sb.mgr.set("remindedOn", "");
  }
}
