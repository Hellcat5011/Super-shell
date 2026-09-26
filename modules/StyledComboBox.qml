import QtQuick
import QtQuick.Controls
import "../services"

ComboBox {
    id: control
    implicitWidth: 150
    implicitHeight: 36
    leftPadding: 24
    rightPadding: 24

    indicator: Canvas {
        x: control.width - width - 12
        y: control.topPadding + (control.availableHeight - height) / 2
        width: 10
        height: 5
        contextType: "2d"
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.moveTo(0, 0);
            ctx.lineTo(width, 0);
            ctx.lineTo(width / 2, height);
            ctx.closePath();
            ctx.fillStyle = Theme.onPrimaryContainerColor;
            ctx.fill();
        }
    }

    contentItem: Text {
        text: control.currentText
        color: Theme.onPrimaryContainerColor
        font.pixelSize: 14
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        font.capitalization: control.font.capitalization
    }

    background: Rectangle {
        color: Theme.primary
        opacity: 0.1
        radius: 18
        border.width: 1
        border.color: control.activeFocus ? Theme.primary : Theme.outlineVariant
    }

    delegate: ItemDelegate {
        id: itemDlgt
        hoverEnabled: true
        width: ListView.view.width
        height: 36
        contentItem: Text {
            text: modelData
            color: Theme.onPrimaryContainerColor
            font.pixelSize: 14
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            font.capitalization: control.font.capitalization
        }
        background: Rectangle {
            color: itemDlgt.highlighted ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2) : (itemDlgt.hovered ? Qt.rgba(Theme.onPrimaryContainerColor.r, Theme.onPrimaryContainerColor.g, Theme.onPrimaryContainerColor.b, 0.1) : "transparent")
            radius: 18
            anchors.margins: 2
            anchors.fill: parent
            layer.enabled: true
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    popup: Popup {
        y: control.height + 4
        width: control.width
        implicitHeight: contentItem.implicitHeight + 8
        padding: 4

        contentItem: ListView {
            clip: true
            interactive: false
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator { }
        }

        background: Item {
            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: 0.45
                radius: 20
            }
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: Qt.rgba(Theme.outlineVariant.r, Theme.outlineVariant.g, Theme.outlineVariant.b, 0.45)
                border.width: 1
                radius: 20
            }
        }
    }
}
