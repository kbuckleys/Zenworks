// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// morpheus/place.js: where a layer opens (Cynosure's Opens, 2026-11-03).

"use strict";

module.exports = {
  module: "morpheus/place.js",
  cases: (P, t) => {
    // a 1080 screen, a 400 panel usually 500 tall, 10 from the edge, a 40 pill
    const top = (place, barTop, h) => P.placeTop(place, barTop, 1080, h || 400, 500, 10, 40);
    t.eq("out of the bar, at the top", top("bar", true), 10);
    t.eq("out of the bar, at the bottom", top("bar", false), 670);
    t.eq("top clears the pill on its edge", [top("top", true), top("top", false)], [50, 10]);
    t.eq("bottom clears it on its own", [top("bottom", true), top("bottom", false)], [670, 630]);
    t.eq("centered by its usual height", top("center", false), 290);
    t.eq("upper and lower, a third from each end", [top("upper", false), top("lower", false)], [110, 470]);
    t.eq("a taller one is kept on the screen", top("lower", false, 700), 330);
    t.eq("grows from its edge", ["bar", "top", "center", "bottom"].map((p) => P.growsUp(p, false)), [true, false, false, true]);
    t.eq("out of a top bar grows down", P.growsUp("bar", true), false);
  }
};
