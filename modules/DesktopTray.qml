import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets
import "../services"

PanelWindow {
    id: root

    anchors {
        top: true
        right: true
    }

    margins {
        top: 210
        right: 30
    }

    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "desktop"

    width: Math.max(50, trayRow.width + 40)
    height: 50
    color: "transparent"

    DesktopWidgetBackground {
    }

    QsMenuAnchor {
        id: menuAnchor
        anchor.window: root
    }

    RowLayout {
        id: trayRow
        anchors.centerIn: parent
        spacing: 12

        Repeater {
            model: SystemTray.items

            delegate: MouseArea {
                width: 24
                height: 24
                hoverEnabled: true

                acceptedButtons: Qt.LeftButton | Qt.RightButton

                IconImage {
                    anchors.fill: parent
                    source: modelData.icon || ""
                    opacity: parent.containsMouse ? 0.7 : 1.0
                }

                onClicked: (mouse) => {
                    if (mouse.button === Qt.LeftButton) {
                        modelData.activate();
                    } else if (mouse.button === Qt.RightButton) {
                        if (modelData.hasMenu) {
                            let xPos = parent.x + trayRow.x;
                            let yPos = parent.y + trayRow.y;
                            menuAnchor.anchor.rect = Qt.rect(xPos, yPos + height + 5, width, 0);
                            menuAnchor.anchor.edges = Qt.BottomEdge;
                            menuAnchor.menu = modelData.menu;
                            menuAnchor.open();
                        } else {
                            modelData.secondaryActivate();
                        }
                    }
                }
            }
        }
    }
}
