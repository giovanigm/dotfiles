// Mic module: volume % on the default source. Click toggles mute,
// wheel adjusts volume in 8% steps (waybar scroll-step 4 x 2%).
import QtQuick
import Quickshell.Services.Pipewire

Module {
	id: root

	property var node: Pipewire.defaultAudioSource

	PwObjectTracker { objects: root.node ? [root.node] : [] }

	tip: root.node ? root.node.description : ""

	ModuleText {
		text: " " + root.volume()
		color: root.muted() ? Theme.separator : Theme.audio
	}

	onClicked: { if (root.node && root.node.audio) root.node.audio.muted = !root.node.audio.muted }

	onWheeled: wheel => {
		if (!root.node || !root.node.audio) return
		const v = wheel.angleDelta.y > 0 ? 0.08 : -0.08
		root.node.audio.volume = Math.min(1, Math.max(0, root.node.audio.volume + v))
	}

	function volume() {
		return root.node && root.node.audio ? Math.round(root.node.audio.volume * 100) : 0
	}
	function muted() {
		return root.node && root.node.audio ? root.node.audio.muted : false
	}
}
