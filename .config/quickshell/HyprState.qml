// Shared Hyprland state (submap tracking via the socket2 event stream).
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
	id: root

	property string submap: ""

	Connections {
		target: Hyprland
		function onRawEvent(event) {
			if (event.name === "submap") root.submap = event.data
		}
	}
}
