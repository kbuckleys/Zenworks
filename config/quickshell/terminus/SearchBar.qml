// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// A SEARCH'S OWN BAR — Finder's smart directory toolbar, under the path bar
// of a results page (user, 2026-10-13; in the same tab and with no sheet
// since 2026-11-01: "match the finder's smart folder toolbars. search should
// have no sheets"). It says what was asked and lets it be asked differently
// without retyping it:
//
//   where      the directory it was asked from, home, or everywhere
//   what       names, or what is inside the files
//   n matches  how many, and how long it took (dots while it runs)
//   ✓          keep it as a collection, named right here on the bar
//   +          one more criteria row under the bar: Name / Kind / Size …,
//              each with its own − and + (terminus/RuleRow, the sheet's row)
//
// Reads the tab's spec (term.searchSpec) and changes it through
// term.respec, which runs it again in this tab. Only there on a results
// page (term.searchPage); zero high otherwise.

import QtQuick
import "../morpheus"
import "terminus.js" as Terminus
import "collections.js" as Coll

Rectangle {
  id: bar
  property var term: null

  readonly property bool on: !!term && term.searchPage
  // the bar's own row, and one row under it per criterion
  readonly property int headRow: term ? term.headH - 2 : 0
  readonly property int ruleH: 40
  height: bar.on ? bar.headRow + ruleModel.count * bar.ruleH : 0
  visible: height > 0
  clip: true
  color: term ? term.chromeBg : "transparent"

  readonly property var spec: bar.on ? term.searchSpec : null
  readonly property string home: Paths.home()
  // where it looks, as one of the switch's three, or "" for a root of the
  // sheet's own (then shown as its own option)
  readonly property string scope: {
    if (!bar.spec) return "";
    const r = String(bar.spec.root || "");
    if (r === "" || r === term.cwd) return "here";
    if (r === bar.home) return "home";
    if (r === "/") return "all";
    return "other";
  }
  readonly property var scopes: {
    if (!bar.on) return [];
    const out = [["here", "“" + (term.cwd === "/" ? "/" : Terminus.basename(term.cwd)) + "”"]];
    if (term.cwd !== bar.home) out.push(["home", "Home"]);
    if (term.cwd !== "/") out.push(["all", "Everywhere"]);
    if (bar.scope === "other")
      out.push(["other", "“" + Terminus.basename(String(bar.spec.root)) + "”"]);
    return out;
  }

  // ── THE CRITERIA ROWS ────────────────────────────────────────────────
  // The spec's rules, blanks included: a row you have just added and not
  // filled in yet is part of the bar (and of the tab, see Tabs.tabState),
  // it just asks nothing — respec leaves it out of the question.
  ListModel { id: ruleModel }
  function rulesNow() {
    const out = [];
    for (let i = 0; i < ruleModel.count; ++i) {
      const r = ruleModel.get(i);
      out.push({ kind: r.kind, op: r.op, value: r.value });
    }
    return out;
  }
  function asked(rules) {
    return JSON.stringify(rules.filter((r) => String(r.value || "").trim() !== ""));
  }
  // From the spec when it changed from somewhere else — a tab stepped to,
  // the query or the scope changed — and only when the rows differ, so the
  // field you are typing in is not rebuilt under you.
  property bool writing: false
  onSpecChanged: {
    if (bar.writing || !bar.spec) return;
    const rs = bar.spec.rules || [];
    if (JSON.stringify(rs) === JSON.stringify(bar.rulesNow())) return;
    ruleModel.clear();
    for (const r of rs)
      ruleModel.append({ kind: String(r.kind), op: String(r.op), value: String(r.value || "") });
  }
  // Back into the spec; run again only when what is ASKED changed (a blank
  // row added, or one emptied that was already empty, is not a new question).
  function store() {
    if (!bar.spec) return;
    const now = bar.rulesNow();
    const rerun = bar.asked(now) !== bar.asked(bar.spec.rules || []);
    bar.writing = true;
    if (rerun) term.respec({ rules: now });
    else term.searchSpec = Object.assign({}, term.searchSpec, { rules: now });
    bar.writing = false;
  }
  // typing in a value waits for a pause, as the search field does
  Timer { id: ruleTyped; interval: 300; onTriggered: bar.store() }
  function setRule(i, field, v) {
    if (i < 0 || i >= ruleModel.count) return;
    if (ruleModel.get(i)[field] === v) return;
    ruleModel.setProperty(i, field, String(v));
    // the op belongs to the kind, as the sheet's (CollEditSheet.setRule)
    if (field === "kind") {
      const ops = Coll.opsFor(v);
      ruleModel.setProperty(i, "op", ops.length > 0 ? ops[0] : "");
      ruleModel.setProperty(i, "value", "");
    }
    if (field === "value" && ruleModel.get(i).kind !== "kind") ruleTyped.restart();
    else bar.store();
  }
  // Finder's first new row asks about the kind
  function addRule(at) {
    const n = Coll.newRule("kind");
    ruleModel.insert(Math.max(0, Math.min(at, ruleModel.count)), n);
    bar.store();
  }
  function dropRule(i) {
    if (i < 0 || i >= ruleModel.count) return;
    ruleTyped.stop();
    ruleModel.remove(i);
    bar.store();
  }

  // ── SAVE, NAMED ON THE BAR ───────────────────────────────────────────
  // The name field opens before the ✓; return keeps it as a collection and
  // opens it, Escape (or the ×) goes back to the search.
  property bool naming: false
  onOnChanged: if (!bar.on) bar.naming = false
  function beginNaming() {
    bar.naming = true;
    nameField.text = bar.spec ? bar.spec.query : "";
    Qt.callLater(() => nameField.claim());
  }
  function save() {
    const s = bar.spec;
    const name = nameField.text.trim();
    if (!s || name === "") return;
    // spelled as the sheet spells a search it saves (CollEditSheet.draftNow)
    const d = Coll.blank(Date.now());
    d.name = name;
    d.root = String(s.root || "").trim() === "" ? term.cwd : s.root;
    d.rules = [];
    if (s.query !== "") d.rules.push(s.kind === "grep"
      ? { kind: "content", op: "text", value: s.query }
      : { kind: "name", op: "contains", value: s.query });
    for (const r of (s.rules || []))
      if (String(r.value || "").trim() !== "") d.rules.push({ kind: r.kind, op: r.op, value: r.value });
    bar.naming = false;
    term.saveCollection(d);
    term.goToCollection(d.id);
  }

  // ── HOW MANY, AND HOW LONG ───────────────────────────────────────────
  // A names search stops at 300 (Terminus.findCommand), so 300 is "300+".
  readonly property string tally: {
    if (!bar.on || term.searchBusy) return "";
    const n = term.rows.length;
    const capped = bar.spec && bar.spec.kind === "find" && n >= 300;
    const words = n === 0 ? "No matches"
      : (capped ? "300+" : String(n)) + (n === 1 ? " match" : " matches");
    const ms = term.searchMs;
    if (ms < 0) return words;
    return words + "  ·  " + (ms < 100 ? "<0.1" : (ms / 1000).toFixed(ms < 10000 ? 1 : 0)) + " s";
  }

  // the bar's ink fades with the rest of the chrome while a sheet is up
  readonly property real ink: term ? 1 - term.sheetInk : 1

  Item {
    id: headLine
    width: parent.width
    height: bar.headRow

    Row {
      anchors.left: parent.left
      anchors.leftMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      spacing: 10
      opacity: bar.ink
      enabled: bar.ink > 0.5

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "Search:"
        color: Zenon.accentMuted
        font.family: Zenon.face
        font.weight: Zenon.weight
        font.pixelSize: Zenon.px(13)
      }
      Segments {
        anchors.verticalCenter: parent.verticalCenter
        textSize: Zenon.px(13)
        pad: 22
        options: bar.scopes
        current: bar.scope
        onChose: (v) => {
          if (v === bar.scope || v === "other") return;
          term.respec({ root: v === "here" ? term.cwd : v === "home" ? bar.home : "/" });
        }
      }
      Segments {
        anchors.verticalCenter: parent.verticalCenter
        textSize: Zenon.px(13)
        pad: 22
        options: [["find", "Names"], ["grep", "Contents"]]
        current: bar.spec ? bar.spec.kind : ""
        onChose: (v) => { if (bar.spec && v !== bar.spec.kind) term.respec({ kind: v }); }
      }
    }

    Row {
      anchors.right: parent.right
      anchors.rightMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      spacing: 10
      opacity: bar.ink
      enabled: bar.ink > 0.5

      Working {
        anchors.verticalCenter: parent.verticalCenter
        running: bar.on && term.searchBusy
        ink: Zenon.accentMuted
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: !bar.naming && bar.tally !== ""
        text: bar.tally
        color: Zenon.accentMuted
        font.family: Zenon.face
        font.weight: Zenon.weight
        font.features: { "tnum": 1 }
        font.pixelSize: Zenon.px(13)
      }
      BulkField {
        id: nameField
        anchors.verticalCenter: parent.verticalCenter
        visible: bar.naming
        width: 220
        textSize: Zenon.px(13)
        ghost: "Collection name"
        onAccepted: bar.save()
        Keys.onEscapePressed: (e) => { e.accepted = true; bar.naming = false; term.contentRef.forceActiveFocus(); }
      }
      // keep it as a collection: a quiet chip beside the + rather than a lit
      // button (user, 2026-11-02); the same chip saves the typed name
      CheckChip {
        anchors.verticalCenter: parent.verticalCenter
        size: Zenon.px(15)
        ready: !bar.naming || nameField.text.trim() !== ""
        onClicked: bar.naming ? bar.save() : bar.beginNaming()
      }
      ClearChip {
        anchors.verticalCenter: parent.verticalCenter
        visible: bar.naming
        size: Zenon.px(15)
        onClicked: { bar.naming = false; term.contentRef.forceActiveFocus(); }
      }
      // one more criterion, at the top of the rows (Finder's +)
      AddChip {
        anchors.verticalCenter: parent.verticalCenter
        visible: !bar.naming
        size: Zenon.px(15)
        onClicked: bar.addRule(0)
      }
    }
  }

  Column {
    anchors.top: headLine.bottom
    width: parent.width
    opacity: bar.ink
    enabled: bar.ink > 0.5

    Repeater {
      model: ruleModel
      delegate: RuleRow {
        id: crit
        required kind
        required op
        required value
        required property int index
        width: bar.width
        rowH: bar.ruleH
        inset: 12
        host: bar.term
        textSize: Zenon.px(13)
        onEdited: (field, v) => bar.setRule(crit.index, field, v)
        onAccepted: { ruleTyped.stop(); bar.store(); term.contentRef.forceActiveFocus(); }
        // Finder's − and + at the end of every criterion
        trailing: Component {
          Row {
            spacing: 8
            ClearChip {
              anchors.verticalCenter: parent.verticalCenter
              size: Zenon.px(15)
              disc: 1.05
              strokes: [0]
              onClicked: bar.dropRule(crit.index)
            }
            AddChip {
              anchors.verticalCenter: parent.verticalCenter
              size: Zenon.px(15)
              onClicked: bar.addRule(crit.index + 1)
            }
          }
        }
        Rectangle {
          anchors.top: parent.top
          width: parent.width
          height: 1
          color: Zenon.border
          opacity: 0.6
        }
      }
    }
  }

  // the bar's edge, as the path bar's
  Rectangle {
    anchors.bottom: parent.bottom
    width: parent.width
    height: 1
    color: Zenon.border
  }
}
