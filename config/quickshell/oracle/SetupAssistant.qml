// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE SETUP ASSISTANT (2026-11-04) — the very first start's window, grown
// out of Make it yours (theme, accent, background) into a few steps. Not an
// app: one card over the new desktop, opened by ZshSetup on the first start
// (Oracle.setupAsked) and again by `qs ipc call Welcome open`.
//
//   Welcome     what this is, Continue or Skip
//   Language    the system's locale (setup/LanguageStep)
//   Time zone   the map and the cities (setup/TimeStep)
//   Keyboard    layout and variant, with a line to try them (KeyboardStep)
//   Look        dark or light, an accent, a background (LookStep)
//   Text size   Oracle's Font size, the card itself the sample (TextStep)
//   Accounts    calendar, git forges, passwords, all optional (AccountsStep)
//   Apps        Flathub in the Store, Zenworks' terminal setup (AppsStep)
//   Done        then the shortcuts sheet
//
// WHAT NEEDS NO PASSWORD IS SET AS IT IS PICKED — keyboard, look, text
// size are Oracle's settings, and the desktop behind changes as you choose.
// WHAT DOES IS KEPT FOR THE END: the language and the time zone go to Ceres
// as one job (one password card), after the shortcuts sheet has closed —
// a password card or polkit's dialog would open under this overlay. The
// terminal setup follows once Ceres is done (it uses Ceres too); Flathub
// is Ceres' own setup question, answered here ("want": asked there ticked).
//
// Every step is Oracle's afterwards, and the Done step says where. Skip
// closes it (Esc does not), still ending on the shortcuts sheet; then the
// terminal question comes as the notification it always was.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "../morpheus"
import "../ceres"
import "setup"
// qualified, for Segments alone: oracle and terminus import each other
import "../terminus" as Term

PanelWindow {
  id: asst

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "zenworks-welcome"
  WlrLayershell.keyboardFocus: asst.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  exclusionMode: ExclusionMode.Ignore
  anchors { left: true; right: true; top: true; bottom: true }
  color: "transparent"

  property bool shown: false
  property real showFactor: asst.shown ? 1 : 0
  Behavior on showFactor { NumberAnimation { duration: Zenon.slow; easing.type: Zenon.ease } }
  visible: asst.shown || asst.showFactor > 0.01

  // ── THE STEPS ──
  readonly property var steps: [
    { id: "welcome",  label: "Welcome",   glyph: "" },
    { id: "language", label: "Language",  glyph: "\uF1AB", title: "Language",
      words: "The language apps speak, and how dates and numbers are written. Zenworks itself is in English for now." },
    { id: "time",     label: "Time zone", glyph: "\uF0AC", title: "Time zone",
      words: "Click the map or search for a city." },
    { id: "keyboard", label: "Keyboard",  glyph: "\uF11C", title: "Keyboard",
      words: "The layout your keys type. Try it in the line below." },
    { id: "look",     label: "Look",      glyph: "\uF1FC", title: "Make it yours",
      words: "Pick what you like; it changes as you pick." },
    { id: "text",     label: "Text size", glyph: "\uF031", title: "Text size",
      words: "How big the suite's text is. This card is the sample." },
    { id: "accounts", label: "Accounts",  glyph: "\uF2BD", title: "Accounts",
      words: "All optional, here for convenience. Each opens in its app; close it to come back here." },
    { id: "apps",     label: "Apps",      glyph: "\uF1B3", title: "Apps and the terminal",
      words: "Two choices about software. Both can be changed later." },
    { id: "done",     label: "Done",      glyph: "\uF00C", title: "You're set",
      words: "" }
  ]
  property int at: 0
  readonly property var step: asst.steps[asst.at]
  // which way the last move went, for the page's slide
  property int dir: 1

  function go(i) {
    const n = Math.max(0, Math.min(asst.steps.length - 1, i));
    if (n === asst.at) return;
    asst.leave(asst.step.id);
    asst.dir = n > asst.at ? 1 : -1;
    asst.at = n;
    asst.arrive(asst.step.id);
  }
  function next() { asst.go(asst.at + 1); }
  function back() { asst.go(asst.at - 1); }
  function stepOf(id) { return Math.max(0, asst.steps.findIndex((s) => s.id === id)); }

  // ── WHAT IT WAS TOLD, kept for the end ──
  // "" is: leave it as it is
  property string pickLocale: ""
  property string pickZone: ""
  property bool wantZsh: false
  property bool wantFlatpak: false
  // reading text in pictures in the language picked (tesseract-data-*):
  // asked on the Language step, ticked until unticked
  property bool wantTess: true
  // the Apps step seen: its two answers count, ticked or not
  property bool appsSeen: false
  // the Language step seen: its text recognition tick counts (audit
  // 11-04: a Skip on Welcome asked for a password to install it)
  property bool languageSeen: false
  readonly property bool tessWanted: asst.languageSeen && asst.tessNeeded && asst.wantTess

  function arrive(id) {
    if (id === "time") Oracle.readTimedate();
    if (id === "apps") asst.appsSeen = true;
    if (id === "language") asst.languageSeen = true;
  }
  function leave(id) {}

  function open(stepId) {
    // the languages take a moment to read: begun now, ready by their step
    if (asst.locales.length === 0) asst.localeRead();
    // Flathub as it stands, so passing the Apps step again keeps a yes
    asst.wantFlatpak = Ceres.flatpakPref === "want";
    asst.at = stepId ? asst.stepOf(stepId) : 0;
    asst.arrive(asst.step.id);
    asst.shown = true;
    Qt.callLater(() => keys.forceActiveFocus());
  }
  // Get started and Skip both end here: the shortcuts sheet next, then what
  // was kept for after it
  function finish() {
    asst.shown = false;
    asst.pending = true;
    if (asst.appsSeen) {
      if (Ceres.flatpakAsk) Ceres.setFlatpakPref(asst.wantFlatpak ? "want" : "no");
      if (!asst.wantZsh && Oracle.zshAnswer !== "yes") Oracle.zshDeclined();
    }
    Oracle.keysSheetAsked();
  }

  // ── AFTER THE SHEET ──
  // pending: closed, with jobs still to hand on; setupOpen holds the
  // terminal notification back until they are
  property bool pending: false
  Binding { target: Oracle; property: "setupOpen"; value: asst.shown || asst.pending || asst.away }
  Connections {
    target: Oracle
    function onSetupAsked(step) { asst.open(step); }
    function onKeysSheetOpenChanged() { if (!Oracle.keysSheetOpen && asst.pending && !asst.shown) Qt.callLater(asst.applySystem); }
  }
  function applySystem() {
    const steps = [];
    // only names from the lists: they go to root's shell as arguments,
    // never as code, and are checked all the same
    if (asst.pickZone !== "" && /^[A-Za-z0-9_+\/-]+$/.test(asst.pickZone) && asst.pickZone !== Oracle.timedate.zone)
      steps.push(["@sudo", "timedatectl", "set-timezone", asst.pickZone]);
    if (asst.pickLocale !== "" && /^[A-Za-z0-9_.@-]+$/.test(asst.pickLocale) && asst.pickLocale !== asst.localeNow)
      steps.push(["@sudo", "sh", "-c", asst.localeScript, "_", asst.pickLocale]);
    // ONE JOB THROUGH CERES' install (audit 11-04): its done comes once the
    // job ends, or "cancelled" from a password card closed unanswered —
    // watching txBusy missed both (a cancel never went busy and left
    // `pending` up for good; a wrong password went not-busy mid-ask and
    // the text recognition install took the steps' place). The package
    // first, then the root steps, under the one password.
    const pkg = asst.tessWanted ? asst.tessFor : "";
    const sys = steps.length === 0 ? ""
      : steps.length > 1 ? "language and time zone" : steps[0][1] === "timedatectl" ? "time zone" : "language";
    const why = pkg !== "" ? "to read " + asst.tessLanguage + " text in pictures" + (sys !== "" ? ", and set the " + sys : "")
      : "set the " + sys;
    if ((pkg !== "" || steps.length > 0) && Ceres.install(pkg !== "" ? [pkg] : [], why, () => asst.afterTess(), steps))
      return;
    asst.afterTess();
  }
  function afterTess() {
    Oracle.readTimedate();
    asst.localeRead();
    if (asst.wantZsh && Oracle.zshAnswer !== "yes") Oracle.zshAsked();
    asst.pickLocale = "";
    asst.pickZone = "";
    asst.pending = false;
  }

  // the locale, root's part: uncommented in locale.gen (or added), built
  // when locale -a does not have it, then made the system's. Applies from
  // the next login.
  readonly property string localeScript:
    "l=$1; e=$(printf '%s' \"$l\" | sed 's/[.@]/\\\\&/g'); "
    + "grep -q \"^$e UTF-8\" /etc/locale.gen || "
    + "{ sed -i \"s/^# *\\($e UTF-8\\)/\\1/\" /etc/locale.gen; grep -q \"^$e UTF-8\" /etc/locale.gen || printf '%s UTF-8\\n' \"$l\" >> /etc/locale.gen; }; "
    + "k=$(printf '%s' \"$l\" | tr A-Z a-z | sed 's/utf-8/utf8/'); "
    + "locale -a | tr A-Z a-z | grep -qxF -e \"$k\" -e \"$k.utf8\" || locale-gen; "
    + "localectl set-locale LANG=\"$l\""

  // ── THE LANGUAGES, read once on asking (oracle/locales.sh) ──
  property var locales: []
  property string localeNow: ""
  // tesseract's languages: in the repos, and installed
  property var tessAvail: ({})
  property var tessHave: ({})
  // the worn (or picked) language's tesseract package, "" for none to
  // offer: English is the package's own, and some have no data
  readonly property var tessRow: {
    const worn = asst.pickLocale !== "" ? asst.pickLocale : asst.localeNow;
    return asst.locales.find((r) => r.value === worn) || null;
  }
  readonly property string tessFor: {
    const r = asst.tessRow;
    if (!r || !r.term) return "";
    const loc = String(r.value);
    // tesseract's own names where ISO's one code is two scripts
    const code = r.term === "zho" ? (/^zh_(TW|HK|MO)/.test(loc) ? "chi_tra" : "chi_sim")
      : r.term === "srp" && loc.indexOf("@latin") >= 0 ? "srp_latn" : r.term;
    const pkg = "tesseract-data-" + code;
    return code !== "eng" && asst.tessAvail[pkg] ? pkg : "";
  }
  readonly property string tessLanguage: asst.tessRow ? asst.tessRow.language : ""
  readonly property bool tessNeeded: asst.tessFor !== "" && !asst.tessHave[asst.tessFor]
  function localeRead() { if (!localeProc.running) localeProc.running = true; }
  Process {
    id: localeProc
    command: ["sh", Quickshell.shellDir + "/oracle/locales.sh"]
    stdout: StdioCollector {
      onStreamFinished: {
        const out = [], avail = {}, have = {};
        for (const l of String(this.text).split("\n")) {
          if (l.indexOf("now ") === 0) { asst.localeNow = l.slice(4).trim(); continue; }
          if (l.indexOf("tess ") === 0) { avail[l.slice(5).trim()] = true; continue; }
          if (l.indexOf("have ") === 0) { have[l.slice(5).trim()] = true; continue; }
          const f = l.split("\t");
          if (f.length < 4 || f[0] === "") continue;
          out.push({ value: f[0], label: f[1] + (f[2] ? " (" + f[2] + ")" : ""), sub: f[0].replace(".UTF-8", ""),
                     language: f[1], term: f[4] || "" });
        }
        out.sort((a, b) => a.label < b.label ? -1 : a.label > b.label ? 1 : 0);
        asst.tessAvail = avail;
        asst.tessHave = have;
        asst.locales = out;
      }
    }
  }

  // ── AWAY IN AN APP (Accounts, and Look's background) ──
  // The card steps aside while the app is up — a window would open under
  // this overlay — and comes back on the same step once it has closed.
  // `isUp` says whether it is; one that never shows within a while brings
  // the card back anyway.
  property var isUp: null
  readonly property bool away: asst.isUp !== null
  property bool awaySeen: false
  property int awayWaited: 0
  function visit(isUp, ipc) {
    asst.isUp = isUp;
    asst.awaySeen = false;
    asst.awayWaited = 0;
    asst.shown = false;
    Quickshell.execDetached(["qs", "ipc", "call"].concat(ipc));
  }
  // an app's window, by its title
  function windowUp(title) {
    return () => Hyprland.toplevels.values.some((t) => t.wayland && t.title === title);
  }
  Timer {
    interval: 500
    repeat: true
    running: asst.away
    onTriggered: {
      const up = asst.isUp();
      if (up) asst.awaySeen = true;
      asst.awayWaited += interval;
      if ((asst.awaySeen && !up) || (!asst.awaySeen && asst.awayWaited > 15000)) {
        asst.isUp = null;
        asst.shown = true;
        Qt.callLater(() => keys.forceActiveFocus());
      }
    }
  }

  HyprlandFocusGrab {
    windows: [ asst ]
    active: asst.shown
  }

  // ── KEYS: the card's, so they climb to it from a step's own field ──
  // Esc never closes it (user, 2026-11-04): a setup is put away with Skip
  // setup, not a slip of a key. A list's search line still clears on Esc.
  function key(e) {
    if (e.key === Qt.Key_Escape) { e.accepted = true; return; }
    if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
      if (asst.at === asst.steps.length - 1) asst.finish(); else asst.next();
      e.accepted = true;
    }
    else if (e.key === Qt.Key_Tab) { asst.next(); e.accepted = true; }
    else if (e.key === Qt.Key_Backtab) { asst.back(); e.accepted = true; }
  }

  // ── THE SCREEN ──
  Rectangle {
    anchors.fill: parent
    color: Zenon.darken(0.32)
    opacity: asst.showFactor
    // a click past the card does nothing: a setup is not put away by a slip
    MouseArea { anchors.fill: parent }
  }

  // MACOS' ONBOARDING, IN THE SUITE'S LOOK (user, 2026-11-04): one roomy
  // window, the steps as Segments along the top, each page a large glyph
  // over a centered title and a line of words, its content in a centered
  // column under them, Back at the left of the foot and Continue at the
  // right, the keys in the HintBar's pill between them.
  Rectangle {
    id: card
    anchors.centerIn: parent
    width: Math.min(asst.width - 96, Zenon.px(15) * 62)
    height: Math.min(asst.height - 96, Zenon.px(15) * 48)
    radius: Zenon.dialogRadius
    color: Zenon.layerBg
    border.width: 1
    border.color: Zenon.border
    opacity: asst.showFactor
    scale: 0.97 + 0.03 * asst.showFactor
    clip: true
    Keys.onPressed: (e) => asst.key(e)

    // what holds the keys when no step's field does
    Item { id: keys; focus: true }
    MouseArea { anchors.fill: parent; onClicked: keys.forceActiveFocus() }

    // ── the steps along the top: where you are, and a way back ──
    Term.Segments {
      id: strip
      anchors.top: parent.top
      anchors.topMargin: 24
      anchors.horizontalCenter: parent.horizontalCenter
      visible: asst.at > 0
      // the step you are on by name, the others by their glyph alone
      // (user, 2026-11-04), the name a tooltip's job
      options: asst.steps.slice(1).map((s) => [s.id, s.id === asst.step.id ? s.label : ""])
      current: asst.step.id
      glyphOf: (v) => (asst.steps.find((s) => s.id === v) || {}).glyph || ""
      textSize: Zenon.px(13)
      pad: 16
      onChose: (v) => asst.go(asst.stepOf(v))
    }

    // ── the page ──
    Item {
      id: page
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: asst.at > 0 ? strip.bottom : parent.top
      anchors.bottom: foot.visible ? foot.top : parent.bottom
      anchors.leftMargin: 48
      anchors.rightMargin: 48
      anchors.topMargin: 30
      anchors.bottomMargin: 20

      Column {
        id: head
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width, Zenon.px(15) * 40)
        spacing: 8
        visible: asst.step.id !== "welcome"
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: asst.step.glyph || ""
          color: Zenon.accent
          font.family: Zenon.face
          font.weight: Zenon.weight
          font.pixelSize: Zenon.px(40)
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: asst.step.title || ""
          textFormat: Text.PlainText
          color: Zenon.white
          font.family: Zenon.face
          font.weight: Zenon.titleWeight
          font.pixelSize: Zenon.px(26)
        }
        Text {
          width: head.width
          visible: text !== ""
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.Wrap
          text: asst.step.words || ""
          textFormat: Text.PlainText
          color: Zenon.accentMuted
          font.family: Zenon.face
          font.weight: Zenon.weight
          font.pixelSize: Zenon.px(15)
        }
      }

      Loader {
        id: body
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width, Zenon.px(15) * 44)
        anchors.top: head.visible ? head.bottom : parent.top
        anchors.topMargin: head.visible ? 26 : 0
        anchors.bottom: parent.bottom
        // built again on each arrival, so a step opens as it stands now
        sourceComponent: asst.shown || asst.showFactor > 0.01 ? ({
          welcome: welcomePage, language: languagePage, time: timePage, keyboard: keyboardPage,
          look: lookPage, text: textPage, accounts: accountsPage, apps: appsPage, done: donePage
        })[asst.step.id] : null
        // arriving from the side it was moved toward
        onLoaded: { slide.from = 24 * asst.dir; slide.restart(); fade.restart(); }
        transform: Translate { id: shift }
        NumberAnimation { id: slide; target: shift; property: "x"; to: 0; duration: Zenon.normal; easing.type: Zenon.ease }
        NumberAnimation on opacity { id: fade; from: 0; to: 1; duration: Zenon.normal; easing.type: Zenon.ease }
      }
    }

    // ── the foot: the suite's HintBar (its floating pill of keys in the
    // middle, Skip and Continue as its buttons at the right), and Back at
    // the left, on the same line (2026-11-04: the hand-built rule + Row
    // folded onto HintBar; the keys were only in the code before) ──
    HintBar {
      id: foot
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.leftMargin: 16
      anchors.rightMargin: 16
      anchors.bottomMargin: 12
      visible: asst.step.id !== "welcome"
      centered: true
      frostBase: Zenon.layerBg
      rows: [["shift tab", "back"], ["tab", "next"],
             ["return", asst.at === asst.steps.length - 1 ? "get started" : "continue"]]
      DialogButton {
        visible: asst.at < asst.steps.length - 1
        label: "Skip setup"
        onClicked: asst.finish()
      }
      DialogButton {
        id: nextBtn
        label: asst.at === asst.steps.length - 1 ? "Get started" : "Continue"
        ink: Zenon.accent
        primary: true
        onClicked: asst.at === asst.steps.length - 1 ? asst.finish() : asst.next()
      }
    }
    DialogButton {
      anchors.left: foot.left
      anchors.leftMargin: foot.pillInset
      anchors.verticalCenter: foot.verticalCenter
      visible: foot.visible
      label: "Back"
      onClicked: asst.back()
    }
  }

  // ── PAGES ──
  Component {
    id: welcomePage
    Item {
      Column {
        anchors.centerIn: parent
        width: parent.width
        spacing: 14
        // the Zenworks logo, Oracle's mark: a line a Text, in the art's
        // own face (Zenon.artFace) at one line-height apart, so the
        // box-drawing strokes meet (OracleWindow's About does the same)
        Column {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: 0
          Repeater {
            model: Oracle.mark
            Text {
              required property var modelData
              anchors.horizontalCenter: parent.horizontalCenter
              text: modelData
              textFormat: Text.PlainText
              color: Zenon.accent
              font.family: Zenon.artFace
              font.weight: Zenon.weight
              font.pixelSize: Zenon.px(30)
              lineHeight: 1.0
            }
          }
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "Welcome to Zenworks"
          color: Zenon.white
          font.family: Zenon.face
          font.weight: Zenon.titleWeight
          font.pixelSize: Zenon.px(28)
        }
        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.Wrap
          text: "A few choices and you're set: language, keyboard, the look, a few accounts. Everything here stays in Oracle for later."
          color: Zenon.accentMuted
          font.family: Zenon.face
          font.weight: Zenon.weight
          font.pixelSize: Zenon.px(15)
        }
        Item { width: 1; height: 10 }
        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Zenon.buttonGap
          DialogButton { label: "Skip setup"; onClicked: asst.finish() }
          DialogButton { label: "Continue"; ink: Zenon.accent; primary: true; onClicked: asst.next() }
        }
      }
    }
  }
  Component {
    id: languagePage
    LanguageStep { setup: asst }
  }
  Component {
    id: timePage
    TimeStep { setup: asst }
  }
  Component {
    id: keyboardPage
    KeyboardStep { setup: asst }
  }
  Component {
    id: lookPage
    LookStep { setup: asst }
  }
  Component {
    id: textPage
    TextStep { setup: asst }
  }
  Component {
    id: accountsPage
    AccountsStep { setup: asst }
  }
  Component {
    id: appsPage
    AppsStep { setup: asst }
  }
  Component {
    id: donePage
    DoneStep { setup: asst }
  }
}
