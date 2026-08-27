// Colored background section wrapping a Row of modules.
// The bar's own clip does not round children, so sections that sit at a bar
// corner (e.g. the clock) opt into rounding via rightRadius: their outer
// corners are rounded and the inner ones squared off with cover rects.
import QtQuick

Rectangle {
	id: root

	property color bg: Theme.background1
	property bool rightRadius: false

	color: bg
	radius: rightRadius ? Theme.barRadius : 0
	height: Theme.barHeight
	implicitWidth: row.implicitWidth

	default property alias content: row.data

	Row {
		id: row
		height: parent.height
		spacing: 0
	}

	// square off the inner corners when rounded
	Rectangle {
		visible: root.rightRadius
		width: Theme.barRadius
		height: Theme.barRadius
		color: root.bg
		anchors {
			left: parent.left
			top: parent.top
		}
	}
	Rectangle {
		visible: root.rightRadius
		width: Theme.barRadius
		height: Theme.barRadius
		color: root.bg
		anchors {
			left: parent.left
			bottom: parent.bottom
		}
	}
}
