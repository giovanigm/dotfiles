// System tray (SNI): 18px icons, 8px spacing, left-click activates,
// right-click / onlyMenu items open the SNI menu via display().
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Row {
	id: root

	property var barWindow

	height: Theme.barHeight
	spacing: 8

	Repeater {
		model: SystemTray.items.values
		delegate: Item {
			id: del
			required property var modelData

			width: 18
			height: 18
			anchors.verticalCenter: parent.verticalCenter
			property bool hovered: false

			IconImage {
				anchors.fill: parent
				source: del.modelData.icon ? `image://icon/${del.modelData.icon}` : ""
				implicitSize: 18
			}

			MouseArea {
				anchors.fill: parent
				hoverEnabled: true
				acceptedButtons: Qt.LeftButton | Qt.RightButton
				onEntered: del.hovered = true
				onExited: del.hovered = false
				onClicked: mouse => {
					const item = del.modelData
					if (mouse.button === Qt.RightButton || item.onlyMenu) {
						if (item.hasMenu) del.displayMenu(mouse)
					} else {
						item.activate()
					}
				}

				ToolTip.visible: del.hovered && del.tipText() !== ""
				ToolTip.text: del.tipText()
				ToolTip.delay: 500
				ToolTip.timeout: -1
				ToolTip.toolTip.background: TooltipBackground {}
			}

			function tipText() {
				const i = del.modelData
				const t = i.tooltipTitle || i.title
				const d = i.tooltipDescription
				return d ? t + "\n" + d : t
			}

			function displayMenu(mouse) {
				const w = root.barWindow
				if (!w || !w.contentItem) return
				const p = del.mapToItem(w.contentItem, mouse.x, mouse.y)
				del.modelData.display(w, p.x, p.y)
			}
		}
	}
}
