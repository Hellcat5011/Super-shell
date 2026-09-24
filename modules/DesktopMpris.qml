import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick.Effects
import "../services"

PanelWindow {
    id: root
    
    anchors {
        top: true
        right: true
    }
    
    margins {
        top: 30
        right: 30
    }
    
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "desktop"
    
    implicitWidth: 400
    implicitHeight: 170
    color: "transparent"

    property var mprisData: ({})
    property bool isPlaying: mprisData.status === "Playing"

    // Track position for smooth progress bar interpolation
    property real trackPosition: 0
    property real trackLength: 0

    onMprisDataChanged: {
        trackPosition = root.mprisData.position || 0
        trackLength = root.mprisData.length || 0
    }

    // Smooth local interpolation — advances position between 1-second script updates
    Timer {
        interval: 100
        running: root.isPlaying && root.trackLength > 0
        repeat: true
        onTriggered: {
            if (root.trackPosition < root.trackLength)
                root.trackPosition += 0.1
        }
    }

    // Static process for playerctl commands to avoid Qt.createQmlObject memory leaks
    Process { id: playerCtlProcess }

    function runPlayerCtl(cmd) {
        if (!root.mprisData.player) return;
        playerCtlProcess.command = ["playerctl", "-p", root.mprisData.player, cmd];
        playerCtlProcess.running = true;
    }

    Process {
        id: mprisProcess
        command: ["bash", Quickshell.shellDir + "/scripts/get-mpris.sh"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.mprisData = JSON.parse(data)
                } catch(e) {}
            }
        }
    }

    DesktopWidgetBackground {}

    RowLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

        // Album Art
        Rectangle {
            id: artContainer
            Layout.preferredWidth: 100
            Layout.preferredHeight: 100
            radius: Theme.radiusSmall
            color: "transparent"
            clip: true

            function getFallbackSvg() {
                // We MUST url-encode the SVG, otherwise the '#' in Theme colors
                // breaks the data URI parser (it treats it as a URL fragment!)
                let c = Theme.background;
                let bg = Theme.primary;
                let raw = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
                    <path fill="none" stroke="${c}" stroke-width="2" stroke-linejoin="miter" stroke-linecap="butt" d="M 16.50 8.85 L 19.78 6.55 A 9.5 9.5 0 1 1 17.45 4.22" />
                    <circle cx="12" cy="12" r="4.5" fill="${c}" />
                    <circle cx="12" cy="12" r="1.5" fill="${bg}" />
                </svg>`;
                return "data:image/svg+xml," + encodeURIComponent(raw);
            }

            Rectangle {
                id: backgroundRect
                width: 90
                height: 90
                anchors.centerIn: parent
                color: root.mprisData.artUrl ? "transparent" : Theme.primary
                radius: 10
                clip: true

                Image {
                    id: artImage
                    anchors.fill: parent
                    source: root.mprisData.artUrl || artContainer.getFallbackSvg()
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                    layer.enabled: true
                    
                    // Prevent SVG pixelation by setting sourceSize to the exact render dimensions
                    sourceSize.width: parent.width
                    sourceSize.height: parent.height
                    
                    // Small margin so it fills up more of the space
                    anchors.margins: root.mprisData.artUrl ? 0 : 5
                }
                
                Rectangle {
                    id: maskRect
                    anchors.fill: parent
                    radius: 10
                    visible: false
                    layer.enabled: true
                }
                
                MultiEffect {
                    source: artImage
                    anchors.fill: parent
                    maskEnabled: true
                    maskSource: maskRect
                }
            }

            // Equalizer overlay
            Row {
                anchors.centerIn: parent
                spacing: 4
                visible: root.isPlaying
                opacity: 0.7

                Repeater {
                    model: 5
                    Item {
                        width: 8
                        height: 50 // Max height constraint container
                        anchors.verticalCenter: parent.verticalCenter
                        
                        Rectangle {
                            anchors.centerIn: parent
                            width: 8
                            height: 10 + Math.random() * 30
                            radius: 4
                            color: Theme.primary
                            
                            SequentialAnimation on height {
                                loops: Animation.Infinite
                                running: root.isPlaying
                                NumberAnimation { to: 10 + Math.random() * 40; duration: 200 + Math.random() * 200; easing.type: Easing.InOutQuad }
                                NumberAnimation { to: 10 + Math.random() * 20; duration: 200 + Math.random() * 200; easing.type: Easing.InOutQuad }
                            }
                        }
                    }
                }
            }
        }

        // Media Info & Controls
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5

            Text {
                Layout.fillWidth: true
                text: root.mprisData.title ? root.mprisData.title : "No Media"
                color: Theme.onPrimaryContainerColor
                font.family: "CaskaydiaCove Nerd Font Mono"
                font.bold: true
                font.pixelSize: 16
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: root.mprisData.artist ? root.mprisData.artist : ""
                color: Theme.onPrimaryContainerColor
                font.family: "CaskaydiaCove Nerd Font Mono"
                font.pixelSize: 14
                elide: Text.ElideRight
            }

            Item { Layout.fillHeight: true } // Spacer

            // ── Android-style squiggly progress bar ──────────────────
            // Adapted from AOSP SquigglyProgress.kt — draws one
            // continuous cubic-bezier wave across the full width, then
            // clips it into played (opaque) and unplayed (muted) halves.
            // The dot sits ON the wave so it traces the squiggle.
            Canvas {
                id: progressCanvas
                Layout.fillWidth: true
                height: 24

                property real progress: root.trackLength > 0 ? Math.min(root.trackPosition / root.trackLength, 1.0) : 0
                property real wavePhase: 0
                // heightFraction: 1 when playing (full wave), 0 when paused (flat line)
                property real heightFraction: root.isPlaying ? 1.0 : 0.0
                Behavior on heightFraction {
                    NumberAnimation { duration: root.isPlaying ? 800 : 550; easing.type: Easing.OutCubic }
                }

                NumberAnimation on wavePhase {
                    from: 0
                    to: 1.0
                    duration: 800
                    loops: Animation.Infinite
                    running: root.isPlaying
                }

                onProgressChanged: requestPaint()
                onWavePhaseChanged: requestPaint()
                onHeightFractionChanged: requestPaint()

                onPaint: {
                    let ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)

                    let centerY = height / 2
                    let totalWidth = width
                    let progressX = totalWidth * progress

                    // Wave parameters
                    let waveLength = 28
                    let amplitude = 4.5
                    let halfWave = waveLength / 2

                    // Phase offset in pixels
                    let phaseOffsetPx = wavePhase * waveLength

                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"

                    // Amplitude: full wave before progress, flat after
                    function computeAmp(x, sign) {
                        if (x >= progressX) return 0
                        return sign * heightFraction * amplitude
                    }

                    // Build wave path with cubic bezier curves
                    let waveStart = -phaseOffsetPx - halfWave
                    let waveEnd = totalWidth + waveLength

                    let wavePath = []
                    let currentX = waveStart
                    let waveSign = 1
                    let currentAmp = computeAmp(currentX, waveSign)
                    wavePath.push({x: currentX, y: centerY + currentAmp})

                    while (currentX < waveEnd) {
                        waveSign = -waveSign
                        let nextX = currentX + halfWave
                        let midX = currentX + halfWave / 2
                        let nextAmp = computeAmp(nextX, waveSign)

                        wavePath.push({
                            type: "cubic",
                            cp1x: midX, cp1y: centerY + currentAmp,
                            cp2x: midX, cp2y: centerY + nextAmp,
                            x: nextX,   y: centerY + nextAmp
                        })
                        currentAmp = nextAmp
                        currentX = nextX
                    }

                    // Helper: draw the wave path
                    function drawWave(ctx) {
                        ctx.beginPath()
                        ctx.moveTo(wavePath[0].x, wavePath[0].y)
                        for (let i = 1; i < wavePath.length; i++) {
                            let p = wavePath[i]
                            ctx.bezierCurveTo(p.cp1x, p.cp1y, p.cp2x, p.cp2y, p.x, p.y)
                        }
                    }

                    // --- Draw played portion (clip left of progressX) ---
                    ctx.save()
                    ctx.beginPath()
                    ctx.rect(0, 0, progressX, height)
                    ctx.clip()
                    drawWave(ctx)
                    ctx.strokeStyle = Theme.onPrimaryContainerColor
                    ctx.lineWidth = 3
                    ctx.stroke()
                    ctx.restore()

                    // --- Draw unplayed portion (flat line) ---
                    if (progressX < totalWidth) {
                        ctx.beginPath()
                        ctx.moveTo(progressX, centerY)
                        ctx.lineTo(totalWidth, centerY)
                        ctx.strokeStyle = Qt.rgba(
                            Theme.onPrimaryContainerColor.r,
                            Theme.onPrimaryContainerColor.g,
                            Theme.onPrimaryContainerColor.b, 0.2)
                        ctx.lineWidth = 3
                        ctx.stroke()
                    }

                    // --- Playback head dot (fixed at center) ---
                    if (progress > 0 && progress < 1) {
                        ctx.beginPath()
                        ctx.arc(progressX, centerY, 5, 0, Math.PI * 2)
                        ctx.fillStyle = Theme.onPrimaryContainerColor
                        ctx.fill()
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 20

                // Previous
                Text {
                    text: "󰒮" 
                    font.family: "CaskaydiaCove Nerd Font Mono"
                    font.pixelSize: 24
                    color: Theme.onPrimaryContainerColor
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.runPlayerCtl("previous")
                    }
                }

                // Play/Pause
                Text {
                    text: root.isPlaying ? "󰏤" : "󰐊" 
                    font.family: "CaskaydiaCove Nerd Font Mono"
                    font.pixelSize: 32
                    color: Theme.onPrimaryContainerColor
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.runPlayerCtl("play-pause")
                    }
                }

                // Next
                Text {
                    text: "󰒭" 
                    font.family: "CaskaydiaCove Nerd Font Mono"
                    font.pixelSize: 24
                    color: Theme.onPrimaryContainerColor
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.runPlayerCtl("next")
                    }
                }
            }
        }
    }
}
