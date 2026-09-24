// ─────────────────────────────────────────────────────────────────────────
// WallpaperSelector.qml — floating 3-image depth carousel
//
// Visual: three rounded wallpaper thumbnails with no card background.
// The centre image sits in front (z=2), flanking images peek from behind
// (z=0), matching the reference image layout.
//
// Fixes in this version:
//   • cardTransparent: true  — no card box, only the images float
//   • forceActiveFocus on open + Keys.on*Pressed — arrow keys now work
//   • Theme.file.reload() called after wallpaper script exits — forces an
//     immediate colour re-read because matugen uses atomic renames which
//     inotify's IN_MODIFY never catches
//   • Flanking images positioned at 22 %/78 % so they overlap behind the
//     centre image, replicating the carousel depth look from the reference
// ─────────────────────────────────────────────────────────────────────────
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick.Effects
import "../services"

OverlayWindow {
    id: picker
    WlrLayershell.namespace: "wallpaper"
    panelWidth:      1118
    panelHeight:     468
    cardRadius:      Theme.radiusLarge
    // No card background — the images float directly over the wallpaper.
    cardTransparent: true

    property string wallpaperDir: "/mnt/hdd/Wallpapers/walls"
    property var    wallpapers:   []
    property bool   applying:     false
    property int    currentIndex: 0

    Component.onCompleted: {
        scanProcess.running = true
    }

    onShownChanged: {
        if (shown) {
            // Shuffle the already-loaded array instantly instead of spawning bash every time
            var arr = picker.wallpapers.slice()
            for (var i = arr.length - 1; i > 0; i--) {
                var j = Math.floor(Math.random() * (i + 1))
                var temp = arr[i]
                arr[i] = arr[j]
                arr[j] = temp
            }
            picker.wallpapers = arr
            picker.currentIndex = 0

            // Give PathView keyboard focus as soon as the panel opens.
            carousel.forceActiveFocus()
        }
    }

    // ── File scanner ────────────────────────────────────────────────────
    // Runs exactly once on startup to cache the list of wallpapers.
    Process {
        id: scanProcess
        command: [
            "bash", "-c",
            "find '" + picker.wallpaperDir + "' -maxdepth 1 -type f " +
            "\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' " +
            "-o -iname '*.gif' -o -iname '*.bmp' -o -iname '*.svg' -o -iname '*.avif' " +
            "-o -iname '*.heic' -o -iname '*.heif' -o -iname '*.jxl' -o -iname '*.tiff' \\)"
        ]
        property var _buffer: []

        onRunningChanged: {
            if (running) {
                _buffer = []
            } else {
                picker.wallpapers = _buffer
            }
        }

        stdout: SplitParser {
            onRead: data => {
                if (data.trim().length > 0)
                    scanProcess._buffer.push(data.trim())
            }
        }
    }

    // ── Wallpaper applicator ────────────────────────────────────────────
    Process {
        id: applyProcess
        onExited: (exitCode) => {
            picker.applying = false
            if (exitCode === 0) {
                // Matugen writes colours.json via atomic rename (temp file →
                // final path).  inotify's IN_MODIFY never fires for renames,
                // so watchChanges alone can't pick this up.  Calling reload()
                // here, right after the script exits, is the reliable way to
                // refresh the theme immediately.
                Theme.forceReload()
                picker.hide()
            }
        }
    }

    function applyWallpaper(path) {
        picker.applying = true
        applyProcess.command = ["sh", Quickshell.shellDir + "/scripts/set-wallpaper.sh", path]
        applyProcess.running  = true
    }

    // ── Carousel ─────────────────────────────────────────────────────────
    PathView {
        id: carousel
        anchors.fill: parent

        // Keyboard focus — allows ← / → arrow keys to navigate.
        focus: true
        Keys.onLeftPressed:   decrementCurrentIndex()
        Keys.onRightPressed:  incrementCurrentIndex()
        Keys.onEscapePressed: picker.hide()
        // Enter / Return applies the selected wallpaper (same as clicking).
        Keys.onReturnPressed: {
            if (!picker.applying && picker.wallpapers.length > 0)
                picker.applyWallpaper(picker.wallpapers[picker.currentIndex])
        }
        Keys.onEnterPressed: {
            if (!picker.applying && picker.wallpapers.length > 0)
                picker.applyWallpaper(picker.wallpapers[picker.currentIndex])
        }

        // Mouse-wheel / touchpad scroll to navigate the carousel.
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => {
                // Negative Y (or negative X on horizontal swipe) = forward/right.
                var forward = event.angleDelta.y < 0 || event.angleDelta.x < 0
                if (forward) carousel.incrementCurrentIndex()
                else         carousel.decrementCurrentIndex()
                event.accepted = true
            }
        }

        model:         picker.wallpapers
        currentIndex:  picker.currentIndex
        // Only three delegates instantiated at a time: left, center, right.
        pathItemCount: 3

        preferredHighlightBegin: 0.5
        preferredHighlightEnd:   0.5
        highlightRangeMode:      PathView.StrictlyEnforceRange
        snapMode:                PathView.SnapToItem

        onCurrentIndexChanged: picker.currentIndex = currentIndex

        // ── Path ──────────────────────────────────────────────────────────
        // Three horizontal slots:
        //   Left  22 %  — flanking, partially hidden behind centre
        //   Centre 50 %  — full size, on top (z=2)
        //   Right  78 %  — flanking, partially hidden behind centre
        //
        // Delegates are centred on the path point (x: -width/2), so the %
        // values reference the middle of each image, not the left edge.
        // At delegate width = 60 % of carousel and flank scale = 0.75, the
        // flanking images overlap the centre image by ~10 %, giving the
        // layered depth look from the reference image.
        path: Path {
            startX: 0
            startY: carousel.height / 2

            // Left slot
            PathAttribute { name: "itemScale";   value: 0.75 }
            PathAttribute { name: "itemOpacity"; value: 0.75 }
            PathAttribute { name: "itemZ";       value: 0    }

            PathLine { x: carousel.width * 0.22; y: carousel.height / 2 }

            PathAttribute { name: "itemScale";   value: 0.75 }
            PathAttribute { name: "itemOpacity"; value: 0.75 }
            PathAttribute { name: "itemZ";       value: 0    }

            // Centre slot
            PathLine { x: carousel.width * 0.50; y: carousel.height / 2 }

            PathAttribute { name: "itemScale";   value: 1.0  }
            PathAttribute { name: "itemOpacity"; value: 1.0  }
            PathAttribute { name: "itemZ";       value: 2    }

            // Right slot
            PathLine { x: carousel.width * 0.78; y: carousel.height / 2 }

            PathAttribute { name: "itemScale";   value: 0.75 }
            PathAttribute { name: "itemOpacity"; value: 0.75 }
            PathAttribute { name: "itemZ";       value: 0    }

            PathLine { x: carousel.width * 1.0;  y: carousel.height / 2 }

            PathAttribute { name: "itemScale";   value: 0.75 }
            PathAttribute { name: "itemOpacity"; value: 0.75 }
            PathAttribute { name: "itemZ";       value: 0    }
        }

        // ── Delegate ──────────────────────────────────────────────────────
        delegate: Item {
            // Base dimensions multiplied by itemScale directly to avoid matrix scale bugs with MultiEffect
            width:  (carousel.width  * 0.60) * (PathView.itemScale ?? 0.75)
            height: (carousel.height * 0.90) * (PathView.itemScale ?? 0.75)

            // Shift origin to centre so the path x% values land at the
            // middle of the image rather than its top-left corner.
            x: -width  / 2
            y: -height / 2

            opacity: PathView.itemOpacity ?? 0.75
            z:       PathView.itemZ       ?? 0

            readonly property bool isCurrent: PathView.isCurrentItem

            // ── Image tile ────────────────────────────────────────────────
            Item {
                anchors.fill:  parent

                Rectangle {
                    id: imageMask
                    anchors.fill: parent
                    radius:       42
                    visible:      false
                    layer.enabled: true
                }

                Image {
                    id: img
                    anchors.fill:  parent
                    source:        "file://" + modelData
                    sourceSize.width: 1920
                    fillMode:      Image.PreserveAspectCrop
                    asynchronous:  true
                    visible:       false
                }

                MultiEffect {
                    anchors.fill: parent
                    source: img
                    maskEnabled: true
                    maskSource: imageMask

                    // Fade in once decoded instead of popping in abruptly.
                    opacity:       img.status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.animMed } }
                }

                // 2 px accent border only on the selected centre image
                Rectangle {
                    anchors.fill: parent
                    radius:       42
                    color:        "transparent"
                    border.width: isCurrent ? 3 : 0
                    border.color: Theme.primary
                    Behavior on border.width { NumberAnimation { duration: Theme.animFast } }
                }

                // Dim + label the centre tile while the script runs.
                Rectangle {
                    anchors.fill: parent
                    color:        Qt.rgba(0, 0, 0, 0.55)
                    visible:      picker.applying && isCurrent
                    radius:       42
                    Text {
                        anchors.centerIn: parent
                        text:             "Applying…"
                        color:            "white"
                        font.pixelSize:   20
                        font.bold:        true
                    }
                }
            }

            // ── Click handling ────────────────────────────────────────────
            MouseArea {
                anchors.fill: parent
                enabled:      !picker.applying
                onClicked: {
                    if (isCurrent) {
                        // Centre → apply.
                        picker.applyWallpaper(modelData)
                    } else {
                        // Flank → scroll to centre.
                        carousel.currentIndex = index
                    }
                }
            }
        }
    }
}
