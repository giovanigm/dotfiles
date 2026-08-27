// Clock: 1s interval, waybar format " {:%H:%M:%S    %a %d.%m}",
// tooltip shows the Catppuccin calendar.
import QtQuick
import QtQuick.Controls

Item {
	id: root

	property bool hovered: false

	height: Theme.barHeight
	width: label.implicitWidth

	ModuleText {
		id: label
		anchors.fill: parent
		text: root.timeText
		color: Theme.date
	}

	property string timeText: ""

	Timer {
		interval: 1000
		repeat: true
		running: true
		onTriggered: root.update()
	}
	Component.onCompleted: root.update()

	function update() {
		const d = new Date()
		const wd = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][d.getDay()]
		const p = n => String(n).padStart(2, "0")
		timeText = " " + p(d.getHours()) + ":" + p(d.getMinutes()) + ":" + p(d.getSeconds())
			+ "    " + wd + " " + p(d.getDate()) + "." + p(d.getMonth() + 1)
	}

	MouseArea {
		anchors.fill: parent
		hoverEnabled: true
		onEntered: root.hovered = true
		onExited: root.hovered = false

		ToolTip.visible: root.hovered
		ToolTip.text: ""
		ToolTip.delay: 500
		ToolTip.timeout: -1
		ToolTip.toolTip.background: TooltipBackground {}
		ToolTip.toolTip.contentItem: CalendarGrid {}
	}
}
