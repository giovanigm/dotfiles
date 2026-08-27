// Speaker module: device icon + volume % on the default sink.
// Click opens pavucontrol, wheel adjusts volume in 8% steps, bluetooth
// devices get the  prefix. Muted → separator color.
import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire

Module {
	id: root

	property var node: Pipewire.defaultAudioSink

	PwObjectTracker { objects: root.node ? [root.node] : [] }

	tip: root.node ? root.node.description : ""

	ModuleText {
		text: root.displayText()
		color: root.muted() ? Theme.separator : Theme.audio
	}

	onClicked: proc.startDetached()

	onWheeled: wheel => {
		if (!root.node || !root.node.audio) return
		const v = wheel.angleDelta.y > 0 ? 0.08 : -0.08
		root.node.audio.volume = Math.min(1, Math.max(0, root.node.audio.volume + v))
	}

	Process {
		id: proc
		command: ["pavucontrol"]
	}

	function displayText() {
		const vol = root.volume()
		if (root.isBluetooth()) return root.iconFor() + " " + vol + "%"
		return root.iconFor() + " " + vol + "%"
	}
	function volume() {
		return root.node && root.node.audio ? Math.round(root.node.audio.volume * 100) : 0
	}
	function muted() {
		return root.node && root.node.audio ? root.node.audio.muted : false
	}
	function isBluetooth() {
		if (!root.node) return false
		const n = (root.node.name + " " + (root.node.properties["device.name"] ?? "")).toLowerCase()
		return n.includes("bluez") || n.includes("bluetooth")
	}
	function iconFor() {
		if (!root.node) return ""
		const icon = (root.node.properties["device.icon-name"] ?? "").toLowerCase()
		if (icon.includes("headphone") || icon.includes("headset")) return ""
		if (icon.includes("phone")) return ""
		if (root.isBluetooth() && icon.includes("car")) return ""
		return root.muted() ? "" : ""
	}
}
