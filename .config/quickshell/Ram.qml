// Memory usage with used/total GiB tooltip. ≥80% → warning red + blink.
import QtQuick

Module {
	id: root

	property bool critical: SysInfo.ram >= 80

	tip: SysInfo.ramUsed + "/" + SysInfo.ramTotal + " GiB"

	ModuleText {
		text: " " + Math.round(SysInfo.ram) + "%"
		color: root.critical ? blink.value : Theme.performance
	}

	Blink {
		id: blink
		running: root.critical
		colorA: Theme.warning
		colorB: Theme.separator
	}
}
