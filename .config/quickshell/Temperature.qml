// CPU temperature with banded thermometer icons (30/50/70/90°C).
// ≥90°C → warning red + blink (critical-threshold 90).
import QtQuick

Module {
	id: root

	property bool critical: SysInfo.temp >= 90

	ModuleText {
		text: root.icon() + " " + Math.round(SysInfo.temp) + "°"
		color: root.critical ? blink.value : Theme.performance
	}

	Blink {
		id: blink
		running: root.critical
		colorA: Theme.warning
		colorB: Theme.separator
	}

	function icon() {
		const icons = ["", "", "", "", ""]
		const t = SysInfo.temp
		return t < 30 ? icons[0] : t < 50 ? icons[1] : t < 70 ? icons[2] : t < 90 ? icons[3] : icons[4]
	}
}
