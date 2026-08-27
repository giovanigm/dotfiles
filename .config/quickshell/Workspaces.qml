// Hyprland workspaces module: overlapping parallelogram buttons (waybar replica).
// Buttons are filtered per monitor; special workspaces render on the focused bar.
import QtQuick
import Quickshell
import Quickshell.Hyprland

Item {
	id: root

	property var barScreen

	height: Theme.barHeight
	width: 20 + 4 + row.width

	property var list: {
		const out = []
		const focused = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
		for (const ws of Hyprland.workspaces.values) {
			if (ws.monitor && root.barScreen && ws.monitor.name === root.barScreen.name) {
				out.push(ws)
			} else if (ws.name.startsWith("special:") && focused !== "" && root.barScreen && focused === root.barScreen.name) {
				out.push(ws)
			}
		}
		out.sort((a, b) => a.id - b.id)
		return out
	}

	Row {
		id: row
		x: 20 // padding-left from the CSS
		height: Theme.barHeight
		spacing: -17 // margin-left: -17px overlap
		Repeater {
			model: root.list
			delegate: WorkspaceButton {
				required property var modelData
				ws: modelData
			}
		}
	}
}
