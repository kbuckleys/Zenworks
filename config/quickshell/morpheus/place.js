.pragma library
// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// WHERE A LAYER OPENS (2026-11-03, Cynosure's Opens in Oracle). "bar" is
// what every layer does: out of the pill, on the bar's edge. The others put
// the panel on its own: at the top or bottom edge, or with its middle a
// third of the way down ("upper"), halfway ("center") or two thirds down
// ("lower"). Those three are placed by `steady`, the panel's usual full
// height, not its height now, so the field stays put while the list fills
// in under it; a panel taller than that is kept on the screen.
//
//   placeTop(place, barTop, H, h, steady, pad, pill)   its top, in px
//
// `pad` is the gap kept from the screen's edge, `pill` the pill's height
// where the pill is on this screen (0 elsewhere): an edge the bar is on
// is cleared of it.

const MIDDLES = { upper: 1 / 3, center: 1 / 2, lower: 2 / 3 };

function placeTop(place, barTop, H, h, steady, pad, pill) {
  const p = Number(pad) || 0, b = Number(pill) || 0;
  const lo = p + (barTop ? b : 0);
  const hi = H - h - p - (barTop ? 0 : b);
  if (place === "top") return lo;
  if (place === "bottom") return hi;
  const mid = MIDDLES[place];
  if (mid !== undefined) {
    const at = Math.round(H * mid - (Number(steady) || h) / 2);
    return Math.max(lo, Math.min(hi, at));
  }
  // out of the bar
  return barTop ? p : H - h - p;
}

// which edge it grows out of: the bottom for "bottom", and for the bar's
// own place when the bar is at the bottom; the top otherwise
function growsUp(place, barTop) {
  return place === "bottom" || ((place === "" || place === "bar") && !barTop);
}
