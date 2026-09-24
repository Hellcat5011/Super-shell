import QtQuick
import QtQuick.Layouts
import Qt.labs.qmlmodels
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
        bottom: 30
        right: 30
    }

    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "desktop"

    implicitWidth: 360
    implicitHeight: 320
    color: "transparent"

    property var selectedDate: new Date()
    property string viewMode: "days" // "days", "months", "years"

    DesktopWidgetBackground {}

    Item {
        anchors.fill: parent
        anchors.margins: 20

        // HEADER
        RowLayout {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 30

            // Left arrow (only in days mode)
            Text {
                text: ""
                font.family: "CaskaydiaCove Nerd Font Mono"
                font.pixelSize: 16
                color: Theme.onPrimaryContainerColor
                visible: root.viewMode === "days"
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        let d = new Date(root.selectedDate);
                        d.setMonth(d.getMonth() - 1);
                        root.selectedDate = d;
                    }
                }
            }

            Item { Layout.fillWidth: true }

            RowLayout {
                spacing: 10
                
                // Month Selector
                Text {
                    text: Qt.formatDate(root.selectedDate, "MMMM")
                    color: Theme.onPrimaryContainerColor
                    font.family: "CaskaydiaCove Nerd Font Mono"
                    font.bold: true
                    font.pixelSize: 16
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.viewMode = (root.viewMode === "months") ? "days" : "months"
                    }
                }

                // Year Selector
                Text {
                    text: Qt.formatDate(root.selectedDate, "yyyy")
                    color: Theme.onPrimaryContainerColor
                    font.family: "CaskaydiaCove Nerd Font Mono"
                    font.bold: true
                    font.pixelSize: 16
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.viewMode = (root.viewMode === "years") ? "days" : "years"
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Right arrow (only in days mode)
            Text {
                text: ""
                font.family: "CaskaydiaCove Nerd Font Mono"
                font.pixelSize: 16
                color: Theme.onPrimaryContainerColor
                visible: root.viewMode === "days"
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        let d = new Date(root.selectedDate);
                        d.setMonth(d.getMonth() + 1);
                        root.selectedDate = d;
                    }
                }
            }
        }

        // DAYS VIEW
        GridLayout {
            anchors.top: header.bottom
            anchors.topMargin: 20
            anchors.horizontalCenter: parent.horizontalCenter
            columns: 7
            columnSpacing: 10
            rowSpacing: 10
            visible: root.viewMode === "days"

            Repeater {
                model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                Text {
                    text: modelData
                    color: Theme.onPrimaryContainerColor
                    font.family: "CaskaydiaCove Nerd Font Mono"
                    font.pixelSize: 14
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    Layout.minimumWidth: 30
                }
            }

            Repeater {
                model: {
                    let d = new Date(root.selectedDate);
                    d.setDate(1);
                    let daysInMonth = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
                    let startDay = d.getDay();
                    let arr = [];
                    for (let i = 0; i < startDay; i++) arr.push("");
                    for (let i = 1; i <= daysInMonth; i++) arr.push(i.toString());
                    return arr;
                }

                Rectangle {
                    Layout.minimumWidth: 30
                    Layout.minimumHeight: 30
                    radius: 3
                    property bool isToday: {
                        if (modelData === "") return false;
                        let now = new Date();
                        return (now.getDate().toString() === modelData) && 
                               (now.getMonth() === root.selectedDate.getMonth()) && 
                               (now.getFullYear() === root.selectedDate.getFullYear());
                    }
                    color: isToday ? Theme.primary : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: parent.isToday ? Theme.background : Theme.onPrimaryContainerColor
                        font.family: "CaskaydiaCove Nerd Font Mono"
                        font.pixelSize: 14
                    }
                }
            }
        }

        // MONTHS VIEW
        GridLayout {
            anchors.top: header.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 10
            columns: 3
            columnSpacing: 10
            rowSpacing: 10
            visible: root.viewMode === "months"

            Repeater {
                model: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 3
                    property bool isSelected: index === root.selectedDate.getMonth()
                    color: isSelected ? Theme.primary : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: parent.isSelected ? Theme.background : Theme.onPrimaryContainerColor
                        font.family: "CaskaydiaCove Nerd Font Mono"
                        font.pixelSize: 16
                        font.bold: parent.isSelected
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            let d = new Date(root.selectedDate);
                            d.setMonth(index);
                            root.selectedDate = d;
                            root.viewMode = "days";
                        }
                    }
                }
            }
        }

        // YEARS VIEW
        GridLayout {
            anchors.top: header.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 10
            columns: 3
            columnSpacing: 10
            rowSpacing: 10
            visible: root.viewMode === "years"

            Repeater {
                model: {
                    let y = root.selectedDate.getFullYear();
                    let arr = [];
                    for (let i = y - 4; i <= y + 7; i++) {
                        arr.push(i);
                    }
                    return arr;
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 3
                    property bool isSelected: modelData === root.selectedDate.getFullYear()
                    color: isSelected ? Theme.primary : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: modelData.toString()
                        color: parent.isSelected ? Theme.background : Theme.onPrimaryContainerColor
                        font.family: "CaskaydiaCove Nerd Font Mono"
                        font.pixelSize: 16
                        font.bold: parent.isSelected
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            let d = new Date(root.selectedDate);
                            d.setFullYear(modelData);
                            root.selectedDate = d;
                            root.viewMode = "days";
                        }
                    }
                }
            }
        }
    }
}
