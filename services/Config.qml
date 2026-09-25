pragma Singleton
import QtQuick
import QtCore

Item {
    id: root

    property alias wallpaperDir: settings.wallpaperDir
    property alias wallpaperDaemon: settings.wallpaperDaemon

    property alias showLockscreenSessionControls: settings.showLockscreenSessionControls
    property alias lockscreenAlignment: settings.lockscreenAlignment
    property alias rememberLastUser: settings.rememberLastUser

    property bool _init: {
        Qt.application.name = "xeon-shell"
        Qt.application.organization = "Xeon Shell"
        return true
    }
    Settings {
        id: settings
        category: "General"
        property string wallpaperDir: "~/Pictures/Wallpapers"
        property string wallpaperDaemon: "awww" // 'awww', 'swww', 'hyprpaper'
        property bool showLockscreenSessionControls: true
        property string lockscreenAlignment: "left" // 'left', 'right'
        property bool rememberLastUser: false
    }
}
