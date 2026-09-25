import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    Process {
        id: proc
        command: ["cat"]
        running: true
        onRunningChanged: {
            if (running) {
                proc.write("hello\n")
            }
        }
        stdout: SplitParser {
            onRead: data => console.log("OUT:", data)
        }
    }
}
