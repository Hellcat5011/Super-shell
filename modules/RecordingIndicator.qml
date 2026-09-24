// ─────────────────────────────────────────────────────────────────────────
// RecordingIndicator.qml — floating pill that shows during screen recording
//
// Positioned below the system tray (top-right, below tray offset).
// Shows a pulsing red dot, elapsed time, and a stop button.
// ─────────────────────────────────────────────────────────────────────────
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../services"

PanelWindow {
    id: root

    // ---- Public API -------------------------------------------------------
    property bool recording: false
    property int elapsedSeconds: 0
    property int fps: 24

    signal stopRequested()

    // ---- Wayland layer-shell plumbing -------------------------------------
    anchors {
        top: true
        right: true
    }

    margins {
        top: 270   // Below the tray (tray is at top: 210, height: 50, + gap)
        right: 30
    }

    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "recording-indicator"

    width: indicatorRow.width + 32
    height: 42
    color: "transparent"
    visible: recording

    // ---- Elapsed timer ----------------------------------------------------
    Timer {
        interval: 1000
        repeat: true
        running: root.recording
        onTriggered: root.elapsedSeconds++
    }

    function formatTime(secs) {
        var m = Math.floor(secs / 60)
        var s = secs % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }

    // ---- Hover tracking ---------------------------------------------------
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    // ---- Content Wrapper --------------------------------------------------
    Item {
        anchors.fill: parent
        opacity: hoverArea.containsMouse ? 1.0 : 0.3
        Behavior on opacity { NumberAnimation { duration: 150 } }

        // ---- Background -------------------------------------------------------
        Rectangle {
            anchors.fill: parent
            radius: 21
            color: Qt.rgba(0.15, 0.02, 0.02, 0.85)
            border.width: 1
            border.color: Qt.rgba(1, 0.3, 0.3, 0.6)
            layer.enabled: true
        }

    // ---- Content ----------------------------------------------------------
    RowLayout {
        id: indicatorRow
        anchors.centerIn: parent
        spacing: 10

        // Pulsing red dot
        Rectangle {
            width: 12; height: 12; radius: 6
            color: "#ff3b3b"

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { to: 0.3; duration: 800; easing.type: Easing.InOutQuad }
                NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
            }
        }

        // FPS badge
        Rectangle {
            width: fpsLabel.width + 10
            height: 20
            radius: 4
            color: Qt.rgba(1, 1, 1, 0.1)

            Text {
                id: fpsLabel
                anchors.centerIn: parent
                text: root.fps + "fps"
                color: Qt.rgba(1, 0.6, 0.6, 0.9)
                font.pixelSize: 11
                font.weight: Font.Medium
            }
        }

        // Elapsed time
        Text {
            text: root.formatTime(root.elapsedSeconds)
            color: "#ffffff"
            font.pixelSize: 14
            font.weight: Font.DemiBold
            font.family: "monospace"
        }

        // Stop button
        Rectangle {
            width: 28; height: 28; radius: 6
            color: stopMouse.containsMouse ? "#ff3b3b" : Qt.rgba(1, 1, 1, 0.15)

            Behavior on color { ColorAnimation { duration: 150 } }

            // Stop square icon
            Rectangle {
                anchors.centerIn: parent
                width: 12; height: 12; radius: 2
                color: stopMouse.containsMouse ? "#ffffff" : "#ff6b6b"
            }

            MouseArea {
                id: stopMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.stopRequested()
            }
        }
    }
    } // End of Content Wrapper
}
