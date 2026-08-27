// Root filesystem usage with "Free {free}" tooltip. ≥85% → warning red + blink.
import QtQuick

Module {
	id: root

	property bool critical: SysInfo.disk >= 85

	tip: "Free " + SysInfo.diskFree

	ModuleText {
		text: " " + Math.round(SysInfo.disk) + "%"
		color: root.critical ? blink.value : Theme.performance
	}

	Blink {
		id: blink
		running: root.critical
		colorA: Theme.warning
		colorB: Theme.separator
	}
}
