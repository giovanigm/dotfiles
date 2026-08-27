// Waybar-styled tooltip background: background1, 3px caution border, radius 8.
// Used via the QtQuick.Controls attached ToolTip API (ToolTip.toolTip.background).
import QtQuick

Rectangle {
	color: Theme.background1
	radius: 8
	border.color: Theme.caution
	border.width: 3
}
