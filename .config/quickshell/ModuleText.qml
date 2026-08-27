// Text base for bar modules: 8pt side padding, centered, bar font.
import QtQuick

Text {
	height: Theme.barHeight
	verticalAlignment: Text.AlignVCenter
	leftPadding: Theme.modulePadding
	rightPadding: Theme.modulePadding
	font.family: Theme.fontFamily
	font.pixelSize: Theme.pixelSize
	font.weight: Theme.fontWeight
}
