// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// CameraMirror — CYNOSURE'S "camera" (2026-11-04, Raycast's Camera): the
// webcam in a small window of its own, mirrored as a mirror is, to check
// your hair before a call. Nothing is recorded or kept; the camera is let go
// the moment the window closes (Esc, or its own close). Without a camera
// the window says so.
//
// Loaded by URL from CynosurePopup (cameraLoader), not named as a type.
import QtQuick
import QtMultimedia
import Quickshell
import "../morpheus"

Scope {
  id: mirror
  signal closed()

  FloatingWindow {
    id: win
    title: "cynosure-camera"
    visible: true
    color: Zenon.layerBg
    implicitWidth: 720
    implicitHeight: 405
    minimumSize: Qt.size(320, 180)
    onVisibleChanged: if (!win.visible) mirror.closed()

    MediaDevices { id: devices }
    readonly property bool hasCamera: devices.videoInputs.length > 0

    CaptureSession {
      camera: Camera {
        id: camera
        active: win.hasCamera
        cameraDevice: devices.defaultVideoInput
      }
      videoOutput: view
    }

    Item {
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: win.visible = false

      VideoOutput {
        id: view
        anchors.fill: parent
        visible: win.hasCamera
        fillMode: VideoOutput.PreserveAspectCrop
        // a mirror: your left on the left
        transform: Scale { origin.x: view.width / 2; xScale: -1 }
      }
      EmptyState {
        anchors.centerIn: parent
        width: parent.width - 40
        visible: !win.hasCamera || camera.error !== Camera.NoError
        text: !win.hasCamera ? "No camera found. Plug one in, then type camera again."
          : "The camera could not be opened: " + camera.errorString
      }
    }
  }
}
