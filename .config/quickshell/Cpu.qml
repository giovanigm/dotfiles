// CPU usage (4s in waybar — served by the shared 2s SysInfo poller).
// ≥80% → warning red + blink (states warning 80 / critical 95).
import QtQuick

Module {
	id: root

	property bool critical: SysInfo.cpu >= 80

	ModuleText {
		text: " " + Math.round(SysInfo.cpu) + "%"
		color: root.critical ? blink.value : Theme.performance
	}

	Blink {
		id: blink
		running: root.critical
		colorA: Theme.warning
		colorB: Theme.separator
	}
}
