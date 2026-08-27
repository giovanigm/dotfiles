// Base for interactive bar modules: Row content, hover tracking, tooltip,
// and click/wheel signals (overrides waybar's on-click / on-scroll).
// Tooltip uses the QtQuick.Controls attached ToolTip API with the
// waybar-styled TooltipBackground.
import QtQuick
import QtQuick.Controls

Item {
	id: root

	property string tip: ""
	property bool hovered: false

	signal clicked(var mouse)
	signal wheeled(var wheel)

	height: Theme.barHeight
	implicitWidth: row.implicitWidth

	default property alias content: row.data

	Row {
		id: row
		height: parent.height
		spacing: 0
	}

	MouseArea {
		id: mouse
		anchors.fill: parent
		hoverEnabled: true
		onEntered: root.hovered = true
		onExited: root.hovered = false
		onClicked: mouse => root.clicked(mouse)
		onWheel: wheel => root.wheeled(wheel)

		ToolTip.visible: root.tip !== "" && mouse.containsMouse
		ToolTip.text: root.tip
		ToolTip.delay: 500
		ToolTip.timeout: -1
		ToolTip.toolTip.background: TooltipBackground {}
		ToolTip.toolTip.contentItem: Text {
			text: root.tip
			color: Theme.text
			font.family: "JetBrainsMono Nerd Font"
			font.pixelSize: 14
			font.weight: Font.Medium
		}
	}
}
