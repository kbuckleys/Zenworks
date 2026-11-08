// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// chronos' weather: where it is asked from (over https), and that answer read.

"use strict";

module.exports = {
  module: "chronos/weather.js",
  cases: (W, t) => {
    t.eq("asked over https", W.locateUrl().indexOf("https://"), 0);
    t.eq("read", JSON.stringify(W.parseLocate('{"success":true,"city":"Cairo","latitude":30.06,"longitude":31.25}')),
      JSON.stringify({ lat: 30.06, lon: 31.25, place: "Cairo" }));
    t.eq("no city is here", W.parseLocate('{"success":true,"latitude":1,"longitude":2}').place, "here");
    t.eq("declined", W.parseLocate('{"success":false,"message":"Reserved range"}'), null);
    t.eq("out of range", W.parseLocate('{"success":true,"latitude":120,"longitude":2}'), null);
    t.eq("not numbers", W.parseLocate('{"success":true,"latitude":"x","longitude":2}'), null);
  }
};
