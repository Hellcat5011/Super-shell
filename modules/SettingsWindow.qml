import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../services"

OverlayWindow {
    id: root
    panelWidth: 860
    panelHeight: 620
    cardRadius: Theme.radiusLarge
    hasBorder: true

    function fuzzyMatch(pattern, str) {
        pattern = pattern.toLowerCase().trim();
        str = str.toLowerCase();
        if (pattern === "") return true;
        
        let words = pattern.split(/\s+/);
        for (let i = 0; i < words.length; i++) {
            if (str.indexOf(words[i]) === -1) {
                return false;
            }
        }
        return true;
    }

    property var searchIndex: [
        "Wallpaper Wallpaper Directory The absolute path to the directory containing your wallpaper images. Wallpaper Daemon The backend service used to set and render your desktop wallpapers.",
        "Lock Screen Lockscreen Power Menu Allow session control actions (Suspend, Reboot, Shutdown) directly from the lockscreen. Lockscreen Alignment Position the lockscreen elements aligned to the left or right edge of the screen.",
        "Greeter Remember Last User Save the last logged-in user and session to automatically pre-select them on the next boot."
    ]

    onShownChanged: {
        if (shown) {
            keyHandler.forceActiveFocus()
            if (tabList) tabList.currentIndex = 0
            if (searchField) searchField.text = ""
        }
    }

    Item {
        id: keyHandler
        anchors.fill: parent
        focus: true

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                root.hide()
                event.accepted = true
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            // ── LEFT SIDEBAR (Tabs) ──
            ColumnLayout {
                Layout.preferredWidth: 220
                Layout.fillHeight: true
                spacing: 16

                // Search Bar
                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    placeholderText: "Search"
                    color: Theme.onPrimaryContainerColor
                    font.pixelSize: 14
                    leftPadding: 32
                    rightPadding: 16
                    topPadding: 8
                    bottomPadding: 8
                    
                    onTextChanged: {
                        if (text.trim() !== "") {
                            for (let i = 0; i < root.searchIndex.length; i++) {
                                if (root.fuzzyMatch(text, root.searchIndex[i])) {
                                    tabList.currentIndex = i;
                                    break;
                                }
                            }
                        }
                    }
                    
                    background: Item {
                        Rectangle {
                            anchors.fill: parent
                            radius: 20
                            color: "transparent"
                            border.width: 1
                            border.color: Theme.onPrimaryContainerColor
                            opacity: 0.15
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: 20
                            color: "transparent"
                            border.width: 1
                            border.color: Theme.primary
                            opacity: (parent.parent.activeFocus || parent.parent.hovered) ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }
                    }
                    
                    Text {
                        text: "⚲"
                        font.pixelSize: 16
                        color: Theme.onPrimaryContainerColor
                        opacity: 0.5
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        rotation: -45
                    }
                }

                // Tabs List
                ListView {
                    id: tabList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: ["Wallpaper", "Lock Screen", "Greeter"]
                    currentIndex: 0
                    
                    delegate: Item {
                        property bool isMatch: root.fuzzyMatch(searchField.text, root.searchIndex[index])
                        visible: isMatch
                        width: ListView.view.width
                        height: isMatch ? 38 : 0
                        
                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: 4
                            anchors.rightMargin: 4
                            radius: 8
                            color: Theme.onPrimaryContainerColor
                            opacity: tabList.currentIndex === index ? 0.85 : (mArea.containsMouse ? 0.15 : 0.0)
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }
                        
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            text: modelData
                            color: tabList.currentIndex === index ? Theme.inversePrimary : Theme.onPrimaryContainerColor
                            font.pixelSize: 14
                            font.weight: tabList.currentIndex === index ? Font.DemiBold : Font.Normal
                        }
                        
                        MouseArea {
                            id: mArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: parent.ListView.view.currentIndex = index
                        }
                    }
                }
            }

            // ── RIGHT CONTENT PANE ──
            Item {
                Layout.fillWidth: true
                Layout.preferredWidth: 600
                Layout.fillHeight: true
                
                // Background Card
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusLarge
                    color: "black"
                    opacity: 0.25
                }
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusLarge
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(Theme.outlineVariant.r, Theme.outlineVariant.g, Theme.outlineVariant.b, 0.45)
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 24

                    // ── Header ──
                    RowLayout {
                        Layout.fillWidth: true
                        
                        Text {
                            text: tabList.currentIndex === 0 ? "⚙  Wallpaper Settings" : (tabList.currentIndex === 1 ? "⚙  Lock Screen Settings" : "⚙  Greeter Settings")
                            color: Theme.onPrimaryContainerColor
                            font.pixelSize: 20
                            font.weight: Font.DemiBold
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        // Close button
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: closeMouse.containsMouse ? Theme.error : "transparent"
                            opacity: closeMouse.containsMouse ? 0.8 : 1.0
                            border.width: 1
                            border.color: closeMouse.containsMouse ? "transparent" : Theme.outlineVariant
                            
                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                color: closeMouse.containsMouse ? "white" : Theme.onPrimaryContainerColor
                                font.pixelSize: 14
                            }
                            
                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.hide()
                            }
                        }
                    }

                    // ── Thin Separator ──
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.outlineVariant
                        opacity: 0.3
                    }

                    // ── PAGE 0: Wallpaper ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 24
                        visible: tabList.currentIndex === 0
                        
                        // Setting: Wallpaper Directory
                        RowLayout {
                            visible: root.fuzzyMatch(searchField.text, "Wallpaper Directory The absolute path to the directory containing your wallpaper images.")
                            Layout.fillWidth: true
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Text { text: "Wallpaper Directory"; color: Theme.onPrimaryContainerColor; font.pixelSize: 15; font.weight: Font.Medium }
                                Text { text: "The absolute path to the directory containing your wallpaper images."; color: Theme.onPrimaryContainerColor; opacity: 0.6; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                            }
                            
                            TextField {
                                width: 200
                                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                                text: Config.wallpaperDir
                                color: Theme.onPrimaryContainerColor
                                font.pixelSize: 14
                                leftPadding: 12; rightPadding: 12; topPadding: 8; bottomPadding: 8
                                background: Rectangle {
                                    color: Theme.primary; opacity: 0.1; radius: 20
                                    border.width: 1; border.color: parent.activeFocus ? Theme.primary : Theme.outlineVariant
                                }
                                onEditingFinished: Config.wallpaperDir = text
                            }
                        }

                        // Setting: Wallpaper Daemon
                        RowLayout {
                            visible: root.fuzzyMatch(searchField.text, "Wallpaper Daemon The backend service used to set and render your desktop wallpapers.")
                            Layout.fillWidth: true
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Text { text: "Wallpaper Daemon"; color: Theme.onPrimaryContainerColor; font.pixelSize: 15; font.weight: Font.Medium }
                                Text { text: "The backend service used to set and render your desktop wallpapers."; color: Theme.onPrimaryContainerColor; opacity: 0.6; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                            }
                            
                            ComboBox {
                                width: 150
                                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                                model: ["awww", "swww", "hyprpaper"]
                                currentIndex: model.indexOf(Config.wallpaperDaemon)
                                onActivated: Config.wallpaperDaemon = model[currentIndex]
                                
                                contentItem: Text {
                                    text: parent.currentText; color: Theme.onPrimaryContainerColor; font.pixelSize: 14; verticalAlignment: Text.AlignVCenter; leftPadding: 16
                                }
                                background: Rectangle {
                                    implicitHeight: 36
                                    color: Theme.primary; opacity: 0.1; radius: 18
                                    border.width: 1; border.color: parent.activeFocus ? Theme.primary : Theme.outlineVariant
                                }
                            }
                        }
                        
                        Item { Layout.fillHeight: true }
                    }

                    // ── PAGE 1: Lock Screen ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 24
                        visible: tabList.currentIndex === 1
                        
                        // Setting: Lockscreen Power Menu
                        RowLayout {
                            visible: root.fuzzyMatch(searchField.text, "Lockscreen Power Menu Allow session control actions (Suspend, Reboot, Shutdown) directly from the lockscreen.")
                            Layout.fillWidth: true
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Text { text: "Lockscreen Power Menu"; color: Theme.onPrimaryContainerColor; font.pixelSize: 15; font.weight: Font.Medium }
                                Text { text: "Allow session control actions (Suspend, Reboot, Shutdown) directly from the lockscreen."; color: Theme.onPrimaryContainerColor; opacity: 0.6; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                            }
                            
                            Switch {
                                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                                checked: Config.showLockscreenSessionControls
                                onCheckedChanged: Config.showLockscreenSessionControls = checked
                            }
                        }

                        // Setting: Lockscreen Alignment
                        RowLayout {
                            visible: root.fuzzyMatch(searchField.text, "Lockscreen Alignment Position the lockscreen elements aligned to the left or right edge of the screen.")
                            Layout.fillWidth: true
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Text { text: "Lockscreen Alignment"; color: Theme.onPrimaryContainerColor; font.pixelSize: 15; font.weight: Font.Medium }
                                Text { text: "Position the lockscreen elements aligned to the left or right edge of the screen."; color: Theme.onPrimaryContainerColor; opacity: 0.6; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                            }
                            
                            ComboBox {
                                width: 150
                                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                                model: ["left", "right"]
                                currentIndex: model.indexOf(Config.lockscreenAlignment)
                                onActivated: Config.lockscreenAlignment = model[currentIndex]
                                
                                contentItem: Text {
                                    text: parent.currentText; color: Theme.onPrimaryContainerColor; font.pixelSize: 14; verticalAlignment: Text.AlignVCenter; leftPadding: 16
                                    font.capitalization: Font.Capitalize
                                }
                                background: Rectangle {
                                    implicitHeight: 36
                                    color: Theme.primary; opacity: 0.1; radius: 18
                                    border.width: 1; border.color: parent.activeFocus ? Theme.primary : Theme.outlineVariant
                                }
                            }
                        }

                        
                        Item { Layout.fillHeight: true }
                    }
                    // ── PAGE 2: Greeter ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 24
                        visible: tabList.currentIndex === 2
                        
                        // Setting: Remember Last User
                        RowLayout {
                            visible: root.fuzzyMatch(searchField.text, "Remember Last User Save the last logged-in user and session to automatically pre-select them on the next boot.")
                            Layout.fillWidth: true
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Text { text: "Remember Last User"; color: Theme.onPrimaryContainerColor; font.pixelSize: 15; font.weight: Font.Medium }
                                Text { text: "Save the last logged-in user and session to automatically pre-select them on the next boot. (Note: changes apply after next greeter sync)"; color: Theme.onPrimaryContainerColor; opacity: 0.6; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                            }
                            
                            Switch {
                                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                                checked: Config.rememberLastUser
                                onCheckedChanged: Config.rememberLastUser = checked
                            }
                        }
                        
                        Item { Layout.fillHeight: true }
                    }
                }
            }
        }
    }
}
