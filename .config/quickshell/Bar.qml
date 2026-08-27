// The bar itself: floating rounded PanelWindow, faithful to the old Waybar layout.
// Layout: left-cap | workspaces | submap | window-title ‖ tray ‖ separator ‖
// [bg1: cpu temp ram disk net] ‖ [audio-in audio-out visualizer] ‖ [bg1: clock]
import Quickshell
import QtQuick

PanelWindow {
	id: root
	required property var modelData
	screen: modelData

	anchors {
		top: true
		left: true
		right: true
	}
	margins {
		top: Theme.barMargin
		left: Theme.barMargin
		right: Theme.barMargin
	}
	exclusiveZone: Theme.barHeight + Theme.barMargin
	implicitHeight: Theme.barHeight
	color: "transparent"

	Rectangle {
		id: bar
		anchors.fill: parent
		radius: Theme.barRadius
		color: Theme.background2
		clip: true

		Row {
			id: leftRow
			anchors {
				left: parent.left
				top: parent.top
				bottom: parent.bottom
			}
			spacing: 0

			// custom/left-cap — spacing before the workspace chips
			Item { width: 8; height: Theme.barHeight }
			Workspaces { barScreen: root.screen }
			Submap {}
			WindowTitle {}
		}

		Row {
			id: rightRow
			anchors {
				right: parent.right
				top: parent.top
				bottom: parent.bottom
			}
			spacing: 0

			Tray { barWindow: root }
			PowerlineSeparator { from: "transparent"; to: Theme.background1 }
			Section {
				Cpu {}
				Temperature {}
				Ram {}
				Disk {}
				Network {}
			}
			PowerlineSeparator { from: Theme.background1; to: Theme.background2 }
			// audio section sits on the bar's background2 (invisible section, like waybar)
			AudioInput {}
			AudioOutput {}
			Visualizer {}
			PowerlineSeparator { from: Theme.background2; to: Theme.background1 }
			Section {
				rightRadius: true
				Clock {}
			}
		}
	}
}
