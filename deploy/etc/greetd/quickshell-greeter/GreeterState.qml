pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property string username: ""
    onUsernameChanged: {
        console.log("GreeterState username changed to:", username)
    }
    
    property var sessionCmd: ["start-hyprland"]
    property string sessionName: "Hyprland"
    onSessionNameChanged: {
        console.log("GreeterState sessionName changed to:", sessionName)
    }

    property var usersList: []
    property var sessionsList: []
    property int userIndex: 0
    property int sessionIndex: 0
    property bool rememberLastUser: false
    property string lockscreenAlignment: "left"
    
    readonly property string newUserSentinel: "+ NEW USER"

    property bool unlockInProgress: false
    property bool showFailure: false
    property string statusMessage: ""
    
    // Legacy properties for the old UI bindings, but we map the new ones
    property bool authenticating: unlockInProgress
    property bool authFailed: showFailure
    property string failReason: statusMessage
    property bool sessionStarting: false

    signal failed()

    function cycleUser() {
        if (usersList.length === 0) return;
        userIndex = (userIndex + 1) % usersList.length
        username = usersList[userIndex]
    }
    
    function cycleSession() {
        if (sessionsList.length === 0) return;
        sessionIndex = (sessionIndex + 1) % sessionsList.length
        sessionName = sessionsList[sessionIndex].name
        sessionCmd = sessionsList[sessionIndex].cmd
    }
    
    function commitNewUser(newUsername) {
        if (newUsername.trim().length === 0) return;
        let usr = newUsername.trim()
        let idx = usersList.indexOf(usr)
        if (idx === -1) {
            let l = usersList.slice()
            l.splice(l.length - 1, 0, usr) // insert before "+ NEW USER"
            usersList = l
            idx = usersList.length - 2
        }
        userIndex = idx
        username = usr
    }

    function authenticate(password) {
        if (unlockInProgress) return
        
        unlockInProgress = true
        showFailure = false
        statusMessage = ""
        sessionStarting = false
        
        helperProcess.password = password
        helperProcess.running = true
    }

    Component.onCompleted: {
        enumProcess.running = true
    }

    property Process enumProcess: Process {
        id: enumProcess
        command: ["python3", Quickshell.shellDir + "/enum-helper.py"]
        onRunningChanged: {
            console.log("enumProcess running:", running)
        }
        stderr: SplitParser {
            onRead: data => console.log("enum-helper stderr:", data)
        }
        stdout: SplitParser {
            onRead: data => {
                console.log("enum-helper output length:", data.length)
                try {
                    let d = JSON.parse(data)
                    root.lockscreenAlignment = d.config.lockscreenAlignment
                    root.rememberLastUser = d.config.rememberLastUser
                    
                    let uList = d.users
                    if (!Array.isArray(uList)) uList = []
                    uList.push(root.newUserSentinel)
                    
                    let sList = d.sessions
                    if (!Array.isArray(sList) || sList.length === 0) {
                        sList = [{"name": "Hyprland", "cmd": ["start-hyprland"]}]
                    }
                    root.sessionsList = sList

                    let uIdx = 0
                    if (d.config.rememberLastUser && d.last_user) {
                        uIdx = uList.indexOf(d.last_user)
                        if (uIdx === -1) {
                            uList.splice(uList.length - 1, 0, d.last_user)
                            uIdx = uList.length - 2
                        }
                    }
                    root.usersList = uList
                    root.userIndex = uIdx
                    root.username = root.usersList[uIdx]
                    
                    let sIdx = 0
                    if (d.config.rememberLastUser && d.last_session && d.last_session.length > 0) {
                        for (let i=0; i<sList.length; i++) {
                            if (JSON.stringify(sList[i].cmd) === JSON.stringify(d.last_session)) {
                                sIdx = i
                                break
                            }
                        }
                    }
                    root.sessionIndex = sIdx
                    root.sessionName = root.sessionsList[sIdx].name
                    root.sessionCmd = root.sessionsList[sIdx].cmd
                } catch(e) {
                    console.log("Error parsing enum-helper output:", e)
                }
            }
        }
    }

    property Process helperProcess: Process {
        id: helperProcess
        command: ["python3", Quickshell.shellDir + "/greet-helper.py", root.rememberLastUser ? "1" : "0", root.username].concat(root.sessionCmd)
        
        property string password: ""
        
        stdout: SplitParser {
            onRead: data => {
                if (data.trim() === "OK") {
                    root.sessionStarting = true
                }
            }
        }
        
        stderr: SplitParser {
            onRead: data => {
                let msg = data.trim()
                if (msg.startsWith("FAIL:")) {
                    root.unlockInProgress = false
                    root.showFailure = true
                    root.statusMessage = msg.substring(5)
                    root.failed()
                } else if (msg.length > 0) {
                    console.log("greet-helper:", msg)
                }
            }
        }

        onRunningChanged: {
            if (running) {
                helperProcess.write(password + "\n")
            } else {
                if (!root.sessionStarting && !root.showFailure) {
                    root.unlockInProgress = false
                    root.showFailure = true
                    root.statusMessage = "Helper exited unexpectedly"
                    root.failed()
                }
            }
        }
    }
}
