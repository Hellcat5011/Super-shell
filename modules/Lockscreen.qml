// ─────────────────────────────────────────────────────────────────────────
// Lockscreen.qml — QuickShell session lock screen
//
// Uses the secure WlSessionLock protocol (ext-session-lock-v1) for
// proper Wayland session locking, with PAM authentication.
//
// Trigger via:
//   qs -c quickshell-launcher ipc call lock lock
//   loginctl lock-session
// ─────────────────────────────────────────────────────────────────────────
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import Qt5Compat.GraphicalEffects
import "../services"

Scope {
    id: root

    // ── shared state ──
    readonly property string username: Quickshell.env("USER") || ""
    readonly property string home: Quickshell.env("HOME") || ""
    property string currentText: ""
    property string statusMessage: ""
    property bool unlockInProgress: false
    property bool showFailure: false
    signal failed()

    // ── Fade animations ──
    property real fade: 0
    property bool unlocking: false

    NumberAnimation { id: fadeIn;  target: root; property: "fade"; to: 1; duration: 600; easing.type: Easing.OutCubic }
    NumberAnimation { id: fadeOut; target: root; property: "fade"; to: 0; duration: 350; easing.type: Easing.InOutCubic; onFinished: { sessionLock.locked = false; root.unlocking = false } }

    function beginUnlock() {
        if (unlocking || !sessionLock.locked) return
        unlocking = true
        fadeIn.stop()
        fadeOut.start()
    }
    
    Timer {
        interval: 1200
        running: root.unlocking
        onTriggered: sessionLock.locked = false
    }

    // ── Password mask state ──
    readonly property string symbolFont: "CaskaydiaCove Nerd Font"

    readonly property var symbolSet: [
        String.fromCodePoint(0xf04e5), // sword
        String.fromCodePoint(0xf0787), // sword_cross
        String.fromCodePoint(0xf0498), // shield
        String.fromCodePoint(0xf011a), // castle
        String.fromCodePoint(0xf01a5), // crown
        String.fromCodePoint(0xf068c), // skull
        String.fromCodePoint(0xf1841), // bow_arrow
        String.fromCodePoint(0xf08c8), // axe
        String.fromCodePoint(0xf06d3), // feather
        String.fromCodePoint(0xf0238), // fire
        String.fromCodePoint(0xf02a0), // ghost
        String.fromCodePoint(0xf0b5f), // bat
        String.fromCodePoint(0xf03d2), // owl
        String.fromCodePoint(0xf0bca), // spider_web
        String.fromCodePoint(0xf01c8), // diamond_stone
        String.fromCodePoint(0xf07eb), // ring
        String.fromCodePoint(0xf0b2f)  // crystal_ball
    ]
    property var maskSymbols: []

    onCurrentTextChanged: {
        let arr = maskSymbols.slice()
        while (arr.length > currentText.length) arr.pop()
        while (arr.length < currentText.length) {
            let prev = arr.length ? arr[arr.length - 1] : -1
            let i
            do { i = Math.floor(Math.random() * symbolSet.length) }
            while (i === prev && symbolSet.length > 1)
            arr.push(i)
        }
        maskSymbols = arr
    }

    function lock() {
        if (!sessionLock.locked) sessionLock.locked = true
    }

    function unlock() {
        sessionLock.locked = false
    }

    function tryUnlock() {
        if (currentText === "" || unlockInProgress) return
        showFailure = false
        statusMessage = ""
        unlockInProgress = true
        pam.start()
    }

    // ── Time keeping ──
    property var currentDate: new Date()
    Timer {
        interval: 1000
        running: sessionLock.locked
        repeat: true
        triggeredOnStart: true
        onTriggered: root.currentDate = new Date()
    }


    PamContext {
        id: pam
        config: "quickshell"
        onPamMessage: { 
            if (responseRequired) respond(root.currentText)
            else root.statusMessage = pam.message 
        }
        onCompleted: result => {
            root.unlockInProgress = false
            root.currentText = ""
            if (result === PamResult.Success) {
                root.beginUnlock()
            } else {
                root.showFailure = true
                root.failed()
            }
        }
        onError: err => {
            console.warn("Lockscreen PAM error:", err)
            root.unlockInProgress = false
            root.showFailure = true
            root.failed()
        }
    }

    WlSessionLock {
        id: sessionLock
        onLockStateChanged: { if (locked) { root.currentText = ""; root.statusMessage = ""; root.showFailure = false; root.unlocking = false; root.fade = 0; fadeIn.restart() } }

        WlSessionLockSurface {
            id: lockSurface
            color: "#000000"

            // ── Background: wallpaper + blur ──
            Item {
                id: backgroundContainer
                anchors.fill: parent
                opacity: root.fade

                Image {
                    id: wallpaperImage
                    anchors.fill: parent
                    source: "file://" + root.home + "/.wa.jpg"
                    fillMode: Image.PreserveAspectCrop
                    visible: false  // Hidden — only used as blur source
                    cache: false
                    onStatusChanged: {
                        if (status === Image.Error) console.warn("Failed to load wallpaper:", source)
                    }
                }

                MultiEffect {
                    anchors.fill: wallpaperImage
                    source: wallpaperImage
                    blurEnabled: true
                    blurMax: 32
                    blur: root.fade
                    visible: wallpaperImage.status === Image.Ready
                }

                // Dark overlay for contrast
                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.15)
                    visible: wallpaperImage.status === Image.Ready
                }
            }

            // ── Main content layout ──
            Item {
                id: content
                anchors.fill: parent
                opacity: Math.max(0, Math.min(1, (root.fade - 0.25) / 0.75))

                readonly property real designHeight: 1440
                readonly property real s: Math.max(0.1, height / designHeight)
                function px(v) { return Math.round(v * s) }

                // ── CLOCK (Unified) ──
                readonly property real clockFontSize: Math.max(content.px(120), Math.round(height * 0.255))
                Item {
                                        id: clockWrapper
                    readonly property real colonSlotWidth: 0.33
                    readonly property real colonDotSize: 0.08
                    readonly property real colonDotSpread: 0.13
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: content.px(-300)
                    height: hoursText.implicitHeight
                    width: hoursText.implicitWidth + colonItem.width + minutesText.implicitWidth

                    Item {
                        id: colonItem
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        width: content.clockFontSize * clockWrapper.colonSlotWidth
                        height: content.clockFontSize
                        opacity: 1.0
                        
                        SequentialAnimation {
                            running: sessionLock.locked
                            loops: Animation.Infinite
                            NumberAnimation { target: colonItem; property: "opacity"; to: 0.0; duration: 500; easing.type: Easing.InOutSine }
                            NumberAnimation { target: colonItem; property: "opacity"; to: 1.0; duration: 500; easing.type: Easing.InOutSine }
                            onStopped: colonItem.opacity = 1.0
                        }

                        // Top dot
                        Rectangle {
                            width: content.clockFontSize * clockWrapper.colonDotSize
                            height: width
                            radius: width / 2
                            color: Theme.primary
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: -content.clockFontSize * clockWrapper.colonDotSpread
                        }

                        // Bottom dot
                        Rectangle {
                            width: content.clockFontSize * clockWrapper.colonDotSize
                            height: width
                            radius: width / 2
                            color: Theme.primary
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: content.clockFontSize * clockWrapper.colonDotSpread
                        }
                    }

                    Text {
                        id: hoursText
                        anchors.right: colonItem.left
                        anchors.verticalCenter: colonItem.verticalCenter
                        text: {
                            let h = root.currentDate.getHours() % 12 || 12
                            return h.toString().padStart(2, '0')
                        }
                        color: Theme.primary
                        font.family: "Fast Hand"
                        font.pixelSize: content.clockFontSize
                        verticalAlignment: Text.AlignVCenter
                        renderType: Text.CurveRendering
                    }

                    Text {
                        id: minutesText
                        anchors.left: colonItem.right
                        anchors.verticalCenter: colonItem.verticalCenter
                        text: root.currentDate.getMinutes().toString().padStart(2, '0')
                        color: Theme.primary
                        font.family: "Fast Hand"
                        font.pixelSize: content.clockFontSize
                        verticalAlignment: Text.AlignVCenter
                        renderType: Text.CurveRendering
                    }
                }

                // ── AVATAR ──
                Item {
                    id: avatarContainer
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: usernamePill.top
                    anchors.bottomMargin: parent.height * 0.02
                    width: parent.height * 0.18
                    height: width
                    readonly property real d: width

                    // 1. Background fill
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.width / 2
                        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.4)
                    }

                    // 2. Combined content (icon or photo)
                    Item {
                        id: avatarContent
                        anchors.fill: parent
                        visible: false // Used as source for OpacityMask

                        // Default user icon (fallback)
                        Item {
                            anchors.fill: parent
                            visible: faceImage.status !== Image.Ready
                            
                            // Head
                            Rectangle {
                                width: avatarContainer.d * 0.30
                                height: width
                                radius: width / 2
                                color: Theme.onPrimaryContainerColor
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: avatarContainer.d * 0.21
                            }
                            
                            // Body/Shoulders
                            Rectangle {
                                width: avatarContainer.d * 0.62
                                height: avatarContainer.d * 0.50
                                radius: avatarContainer.d * 0.25
                                color: Theme.onPrimaryContainerColor
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: avatarContainer.d * 0.58
                            }
                        }

                        // Photo
                        Image {
                            id: faceImage
                            anchors.fill: parent
                            source: "file://" + root.home + "/.face"
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready
                            cache: false
                        }
                    }

                    Rectangle {
                        id: avatarMask
                        anchors.fill: parent
                        radius: parent.width / 2
                        color: "black"
                        visible: false
                    }

                    OpacityMask {
                        anchors.fill: parent
                        source: avatarContent
                        maskSource: avatarMask
                    }

                    // 3. Border
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.width / 2
                        color: "transparent"
                        border.width: content.px(2)
                        border.color: Theme.outline
                    }
                }

                // ── USERNAME PILL ──
                Rectangle {
                    id: usernamePill
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: content.px(300)
                    width: content.px(512)
                    height: parent.height * 0.05
                    radius: height / 2
                    color: Qt.rgba(0, 0, 0, 0.25)
                    border.width: content.px(3)
                    border.color: Theme.outline

                    Text {
                        anchors.centerIn: parent
                        text: root.username
                        color: Theme.onPrimaryContainerColor
                        font.family: "Katsuno Japan Demo"
                        font.pixelSize: content.px(45)
                    }
                }

                // ── PASSWORD INPUT ──
                Rectangle {
                    id: passwordContainer
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: content.px(400)
                    width: content.px(512)
                    height: parent.height * 0.05
                    radius: height / 2
                    color: Qt.rgba(0, 0, 0, 0.25)
                    border.width: content.px(3)
                    border.color: root.showFailure ? Theme.error : Theme.outline
                    Behavior on border.color { ColorAnimation { duration: 300 } }

                    // Shake animation on failed auth
                    transform: Translate { id: shakeTranslate; x: 0 }
                    SequentialAnimation {
                        id: shakeAnim
                        loops: 1
                        NumberAnimation { target: shakeTranslate; property: "x"; to: content.px(-20); duration: 50;  easing.type: Easing.OutQuad }
                        NumberAnimation { target: shakeTranslate; property: "x"; to: content.px(20);  duration: 50;  easing.type: Easing.OutQuad }
                        NumberAnimation { target: shakeTranslate; property: "x"; to: content.px(-15); duration: 50;  easing.type: Easing.OutQuad }
                        NumberAnimation { target: shakeTranslate; property: "x"; to: content.px(15);  duration: 50;  easing.type: Easing.OutQuad }
                        NumberAnimation { target: shakeTranslate; property: "x"; to: content.px(-5);  duration: 50;  easing.type: Easing.OutQuad }
                        NumberAnimation { target: shakeTranslate; property: "x"; to: 0;   duration: 50;  easing.type: Easing.OutQuad }
                    }

                    TextInput {
                        id: passwordInput
                        anchors.fill: parent
                        opacity: 0
                        cursorVisible: false
                        echoMode: TextInput.Password
                        focus: true
                        enabled: !root.unlockInProgress && !root.unlocking

                        Component.onCompleted: forceActiveFocus()
                        onTextChanged: root.currentText = text
                        onAccepted: root.tryUnlock()
                        Keys.onEscapePressed: text = ""

                        Connections {
                            target: root
                            function onCurrentTextChanged() { 
                                if (passwordInput.text !== root.currentText) {
                                    passwordInput.text = root.currentText 
                                }
                            }
                            function onFailed() { shakeAnim.start() }
                        }
                    }

                    // Placeholder
                    Text {
                        anchors.centerIn: parent
                        visible: root.currentText.length === 0
                        text: "Input password"
                        color: Qt.rgba(Theme.onPrimaryContainerColor.r, Theme.onPrimaryContainerColor.g, Theme.onPrimaryContainerColor.b, 0.4)
                        font.pixelSize: content.px(16)
                        font.family: "Katsuno Japan Demo"
                    }

                    // Mask Area
                    Item {
                        id: maskArea
                        anchors.fill: parent
                        anchors.leftMargin: content.px(30); anchors.rightMargin: content.px(30)
                        clip: true
                        Row {
                            id: maskRow
                            height: parent.height
                            spacing: content.px(8)
                            x: width <= maskArea.width ? (maskArea.width - width) / 2 : maskArea.width - width
                            Repeater {
                                model: root.maskSymbols.length
                                Text {
                                    id: symbolText
                                    height: maskRow.height
                                    verticalAlignment: Text.AlignVCenter
                                    text: root.symbolSet[root.maskSymbols[index]]
                                    font.family: root.symbolFont
                                    font.pixelSize: content.px(40)
                                    color: Theme.onPrimaryContainerColor

                                    scale: 0.7
                                    opacity: 0
                                    Component.onCompleted: popAnim.start()
                                    ParallelAnimation {
                                        id: popAnim
                                        NumberAnimation { target: symbolText; property: "opacity"; to: 1; duration: 120; easing.type: Easing.OutBack }
                                        NumberAnimation { target: symbolText; property: "scale"; to: 1; duration: 120; easing.type: Easing.OutBack }
                                    }
                                }
                            }
                        }
                    }
                    
                    // ── PAM STATUS MESSAGE ──
                    Text {
                        id: pamStatusText
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.bottom
                        anchors.topMargin: content.px(15)
                        text: root.statusMessage
                        color: pam.messageIsError ? Theme.error : Qt.rgba(Theme.onPrimaryContainerColor.r, Theme.onPrimaryContainerColor.g, Theme.onPrimaryContainerColor.b, 0.7)
                        font.pixelSize: content.px(16)
                        font.family: "Musashi Brush"
                        visible: text.length > 0
                    }
                }

                // ── BOTTOM: Day of week (left) ──
                Text {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: content.px(50)
                    anchors.bottomMargin: content.px(30)
                    text: Qt.formatDate(root.currentDate, "dddd")
                    color: Theme.primary
                    font.family: "Musashi Brush"
                    font.pixelSize: content.px(75)
                }

                // ── BOTTOM: Date (right) ──
                Text {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: content.px(50)
                    anchors.bottomMargin: content.px(30)
                    text: Qt.formatDate(root.currentDate, "dd MMMM yyyy")
                    color: Theme.primary
                    font.family: "Musashi Brush"
                    font.pixelSize: content.px(75)
                }
            }
        }
    }
}
