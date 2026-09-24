import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../services"

PanelWindow {
    id: root

    anchors {
        bottom: true
        right: true
    }

    margins {
        bottom: 380
        right: 30
    }

    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "desktop"

    implicitWidth: 360
    implicitHeight: content.implicitHeight + 40
    color: "transparent"

    property var currentDate: new Date()
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.currentDate = new Date()
    }

    DesktopWidgetBackground {}

    ColumnLayout {
        id: content
        anchors.centerIn: parent
        anchors.margins: 20
        spacing: 5

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: {
                let h = root.currentDate.getHours() % 12 || 12;
                let m = root.currentDate.getMinutes().toString().padStart(2, '0');
                return h + ":" + m;
            }
            color: Theme.onPrimaryContainerColor
            font.family: "CaskaydiaCove Nerd Font Mono"
            font.bold: true
            font.pixelSize: 84
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDate(root.currentDate, "dddd, MMMM dd")
            color: Theme.onPrimaryContainerColor
            font.family: "CaskaydiaCove Nerd Font Mono"
            font.pixelSize: 18
        }
    }
}
