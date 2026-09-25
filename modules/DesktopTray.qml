import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
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

        SettingsWindow {
            id: settingsWindow
        }

        MouseArea {
            width: 24
            height: 24
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            onClicked: settingsWindow.toggle()

            Item {
                anchors.centerIn: parent
                width: 18
                height: 18
                opacity: parent.containsMouse ? 0.7 : 1.0

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    scale: 18 / 24
                    
                    ShapePath {
                        strokeColor: Theme.onBackground
                        strokeWidth: 2
                        fillColor: "transparent"
                        joinStyle: ShapePath.RoundJoin
                        capStyle: ShapePath.RoundCap
                        PathSvg {
                            path: "M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"
                        }
                    }
                    ShapePath {
                        strokeColor: Theme.onBackground
                        strokeWidth: 2
                        fillColor: "transparent"
                        PathSvg {
                            path: "M 12 9 A 3 3 0 0 1 12 15 A 3 3 0 0 1 12 9"
                        }
                    }
                }
            }
        }

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
