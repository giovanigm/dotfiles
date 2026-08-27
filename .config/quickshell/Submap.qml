// Hyprland submap indicator: shows the RESIZE glyph blinking resize<->separator,
// or the raw submap name for any other submap.
import QtQuick

ModuleText {
	visible: HyprState.submap !== ""
	text: HyprState.submap === "RESIZE" ? Theme.glyphResize : HyprState.submap
	color: HyprState.submap === "RESIZE" ? blink.value : Theme.window

	Blink {
		id: blink
		running: HyprState.submap === "RESIZE"
		colorA: Theme.resize
		colorB: Theme.separator
	}
}
