// Active window title: italic lavender, truncated to 48 chars (waybar max-length).
import Quickshell
import Quickshell.Hyprland
import QtQuick

ModuleText {
	property var t: Hyprland.activeToplevel

	visible: !!t && t.title !== ""
	text: t && t.title ? t.title.slice(0, 48) : ""
	color: Theme.window
	font.italic: true
}
