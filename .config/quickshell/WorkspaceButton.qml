// Single workspace chip: 42x28 parallelogram (top edge shifted +14px).
// States (waybar CSS): idle = #45475a text on bg2, visible = caution fill +
// text, active = separator-edged background1 fill + lavender text, urgent =
// blinking text, special.active = active fill + separator<->window blink.
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland

Item {
	id: root

	property var ws

	width: 42
	height: Theme.barHeight
	property bool hovered: false

	property bool isSpecial: ws ? ws.name.startsWith("special:") : false
	property bool active: ws ? ws.active : false
	property bool urgent: ws ? ws.urgent : false

	property string icon: {
		const name = ws ? ws.name : ""
		const n = name.startsWith("special:") ? name.slice(8) : name
		const map = {
			"magic": "", // waybar format-icons magic
			"zellij": "",
			"10": Theme.glyphWsTen,
			"lock": ""
		}
		return map[n] ?? n
	}

	// waybar 0.15 (the bar this replaces) only ever filled the ACTIVE chip
	// (GTK ignored the .visible gradient); every other workspace renders as a
	// bare caution-colored glyph — replicate that look.
	property color textColor: {
		if (isSpecial && active) return blinkSpecial.value
		if (urgent) return blinkUrgent.value
		if (active || hovered) return Theme.window
		return Theme.caution
	}

	Shape {
		anchors.fill: parent
		antialiasing: true

		// active: background1 fill between two separator bands hugging the
		// slanted edges (waybar 24/28% + 73/76% gradient stops). No separator
		// rim on the top/bottom edges — the fill bleeds to the bar edge.
		ShapePath {
			fillColor: root.active ? Theme.background1 : "transparent"
			strokeColor: "transparent"
			PathPolyline {
				path: [Qt.point(15, 0), Qt.point(40, 0), Qt.point(26, 28), Qt.point(1, 28), Qt.point(15, 0)]
			}
		}
		ShapePath {
			fillColor: root.active ? Theme.separator : "transparent"
			strokeColor: "transparent"
			PathPolyline {
				path: [Qt.point(13, 0), Qt.point(15, 0), Qt.point(1, 28), Qt.point(-1, 28), Qt.point(13, 0)]
			}
		}
		ShapePath {
			fillColor: root.active ? Theme.separator : "transparent"
			strokeColor: "transparent"
			PathPolyline {
				path: [Qt.point(40, 0), Qt.point(42, 0), Qt.point(28, 28), Qt.point(26, 28), Qt.point(40, 0)]
			}
		}
		// non-active: bg2 (invisible) — no fill, matching waybar 0.15's render
		ShapePath {
			fillColor: !root.active ? Theme.background2 : "transparent"
			strokeColor: "transparent"
			PathPolyline {
				path: [Qt.point(14, 0), Qt.point(42, 0), Qt.point(28, 28), Qt.point(0, 28), Qt.point(14, 0)]
			}
		}
	}

	Text {
		anchors.centerIn: parent
		text: root.icon
		color: root.textColor
		font.family: Theme.fontFamily
		font.pixelSize: Theme.pixelSize
		font.weight: Theme.fontWeight
		font.italic: true
	}

	MouseArea {
		anchors.fill: parent
		hoverEnabled: true
		onEntered: root.hovered = true
		onExited: root.hovered = false
		onClicked: { if (root.ws) root.ws.activate() }
		onWheel: wheel => Hyprland.dispatch(wheel.angleDelta.y > 0 ? "workspace e+1" : "workspace e-1")
	}

	Blink {
		id: blinkUrgent
		running: root.urgent
		colorA: Theme.caution
		colorB: Theme.warning
	}
	Blink {
		id: blinkSpecial
		running: root.isSpecial && root.active
		colorA: Theme.separator
		colorB: Theme.window
	}
}
