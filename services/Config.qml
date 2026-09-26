pragma Singleton
import QtQuick
import QtCore

Item {
    id: root

    // Reference AppInfo so its singleton is constructed when Config.qml
    // is loaded. With the explicit Settings.location below, this is now
    // belt-and-braces rather than the load-bearing mechanism.
    readonly property var _appInfo: AppInfo

    Component.onCompleted: discard()

    // Live values — the shell reads these at runtime, and they persist
    // to ~/.config/Xeon Shell/xeon-shell.conf via Settings{}.
    property alias wallpaperDir: settings.wallpaperDir
    property alias wallpaperDaemon: settings.wallpaperDaemon
    property alias showLockscreenSessionControls: settings.showLockscreenSessionControls
    property alias lockscreenAlignment: settings.lockscreenAlignment
    property alias rememberLastUser: settings.rememberLastUser

    // Draft values — the Settings UI edits these. They do not affect the
    // shell's live behavior until save() is called.
    property string draftWallpaperDir: ""
    property string draftWallpaperDaemon: ""
    property bool   draftShowLockscreenSessionControls: true
    property string draftLockscreenAlignment: "left"
    property bool   draftRememberLastUser: false

    // True if any draft differs from its corresponding live value.
    readonly property bool isDirty:
        draftWallpaperDir !== wallpaperDir ||
        draftWallpaperDaemon !== wallpaperDaemon ||
        draftShowLockscreenSessionControls !== showLockscreenSessionControls ||
        draftLockscreenAlignment !== lockscreenAlignment ||
        draftRememberLastUser !== rememberLastUser

    function save() {
        wallpaperDir = draftWallpaperDir
        wallpaperDaemon = draftWallpaperDaemon
        showLockscreenSessionControls = draftShowLockscreenSessionControls
        lockscreenAlignment = draftLockscreenAlignment
        rememberLastUser = draftRememberLastUser
    }

    function discard() {
        draftWallpaperDir = wallpaperDir
        draftWallpaperDaemon = wallpaperDaemon
        draftShowLockscreenSessionControls = showLockscreenSessionControls
        draftLockscreenAlignment = lockscreenAlignment
        draftRememberLastUser = rememberLastUser
    }

    Settings {
        id: settings

        // The explicit path. This is what makes the fix robust: the
        // QSettings backend uses this directly and never consults
        // Qt.application.organization or Qt.application.name, so the
        // path is correct regardless of which property bindings have
        // fired or which Component.onCompleted handlers have run.
        location: AppInfo.settingsLocation

        category: "General"
        property string wallpaperDir: "~/Pictures/Wallpapers"
        property string wallpaperDaemon: "awww" // 'awww', 'swww', 'hyprpaper'
        property bool showLockscreenSessionControls: true
        property string lockscreenAlignment: "left" // 'left', 'right'
        property bool rememberLastUser: false
    }
}
