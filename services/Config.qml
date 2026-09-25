pragma Singleton
import QtQuick
import QtCore

Item {
    id: root

    property alias wallpaperDir: settings.wallpaperDir
    property alias wallpaperDaemon: settings.wallpaperDaemon

    property alias showLockscreenSessionControls: settings.showLockscreenSessionControls
    property alias lockscreenAlignment: settings.lockscreenAlignment

    Settings {
        id: settings
        category: "General"
        property string wallpaperDir: "~/Pictures/Wallpapers"
        property string wallpaperDaemon: "awww" // 'awww', 'swww', 'hyprpaper'
        property bool showLockscreenSessionControls: true
        property string lockscreenAlignment: "left" // 'left', 'right'
    }
}
