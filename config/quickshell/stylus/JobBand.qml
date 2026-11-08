// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// HOW FAR A WRITE HAS COME: the band over a job's words, red if it failed.
// The download and backup pages each drew it.

import QtQuick
import "../morpheus"
import "../terminus"
import "stylus.js" as S

Rectangle {
  id: band
  property var job: null
  height: 8
  radius: Zenon.rad(4)
  color: Zenon.wash(0.06)
  ProgressFill {
    anchors.fill: parent
    radius: band.radius
    frac: S.phaseFrac(band.job)
    ink: band.job && band.job.result && !band.job.result.ok ? Zenon.red : Zenon.accent
  }
}
