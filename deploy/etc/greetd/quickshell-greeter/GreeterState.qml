pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string username: "tester" // Hardcoded for this setup as per reference
    readonly property var sessionCmd: ["start-hyprland"]

    property bool unlockInProgress: false
    property bool showFailure: false
    property string statusMessage: ""
    
    // Legacy properties for the old UI bindings, but we map the new ones
    property bool authenticating: unlockInProgress
    property bool authFailed: showFailure
    property string failReason: statusMessage
    property bool sessionStarting: false

    signal failed()

    function authenticate(password) {
        if (unlockInProgress) return
        
        unlockInProgress = true
        showFailure = false
        statusMessage = ""
        sessionStarting = false
        
        // Ensure GREETD_SOCK is passed by the environment, or hardcode for testing if needed
        helperProcess.password = password
        helperProcess.running = true
    }

    property Process helperProcess: Process {
        id: helperProcess
        command: ["python3", Quickshell.shellDir + "/greet-helper.py", root.username].concat(root.sessionCmd)
        
        property string password: ""
        
        stdout: SplitParser {
            onRead: data => {
                if (data.trim() === "OK") {
                    root.sessionStarting = true
                    // Greeter expects the helper to successfully start the session and run exit command.
                    // The throwaway compositor will exit shortly.
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
                // Send password
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
