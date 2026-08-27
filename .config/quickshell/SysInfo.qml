// System stats poller: one Timer + Process running scripts/sysinfo.sh every 2s.
// No native sensors module exists in Quickshell 0.3, so the script reads
// /proc, /sys and df, and reports back a single JSON line.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
	id: root

	property real cpu: 0
	property real temp: 0
	property real ram: 0
	property string ramUsed: "0"
	property string ramTotal: "0"
	property real disk: 0
	property string diskFree: "0"
	property real netDown: 0 // bits/s
	property real netUp: 0 // bits/s

	property bool busy: false

	Timer {
		interval: 2000
		repeat: true
		running: true
		onTriggered: root.refresh()
	}

	function refresh() {
		if (root.busy) return
		root.busy = true
		proc.running = true
	}

	Process {
		id: proc
		command: ["/bin/sh", Quickshell.shellDir + "/scripts/sysinfo.sh"]
		running: false

		stdout: StdioCollector {
			id: out
			onStreamFinished: {
				const text = out.text ?? ""
				if (text === "") {
					console.warn("SysInfo: empty stdout")
					return
				}
				try {
					const d = JSON.parse(text.trim())
					root.cpu = d.cpu
					root.temp = d.temp
					root.ram = d.ram
					root.ramUsed = d.ramUsed
					root.ramTotal = d.ramTotal
					root.disk = d.disk
					root.diskFree = d.diskFree
					root.netDown = d.netDown
					root.netUp = d.netUp
				} catch (e) {
					console.warn("SysInfo: JSON parse failed:", text.trim())
				}
			}
		}

		stderr: StdioCollector {
			id: err
			onStreamFinished: {
				const text = err.text ?? ""
				if (text !== "") console.warn("SysInfo stderr:", text)
			}
		}

		onExited: function (exitCode, exitStatus) {
			root.busy = false
			if (exitCode !== 0) console.warn("SysInfo: process exited", exitCode)
		}
	}
}
