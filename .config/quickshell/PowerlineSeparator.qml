// Powerline separator: diagonal two-color band with a 1.4px separator edge.
// Replicates the waybar spacer gradient (linear-gradient 63.435deg, 47.5%→52.4%).
// Geometry: band runs (4,0) → (18,28) in a 22x28 box; from-color fills the
// bottom-left region, to-color the top-right region.
import QtQuick
import QtQuick.Shapes

Item {
	id: root

	property color from: "transparent"
	property color to: Theme.background1

	width: 22
	height: Theme.barHeight
	clip: true

	Shape {
		anchors.fill: parent
		antialiasing: true

		ShapePath {
			fillColor: root.from
			strokeColor: "transparent"
			PathPolyline {
				path: [Qt.point(0, 0), Qt.point(4, 0), Qt.point(18, 28), Qt.point(0, 28), Qt.point(0, 0)]
			}
		}
		ShapePath {
			fillColor: root.to
			strokeColor: "transparent"
			PathPolyline {
				path: [Qt.point(4, 0), Qt.point(22, 0), Qt.point(22, 28), Qt.point(18, 28), Qt.point(4, 0)]
			}
		}
		ShapePath {
			fillColor: Theme.separator
			strokeColor: "transparent"
			PathPolyline {
				path: [Qt.point(3.4, 0.3), Qt.point(4.6, -0.3), Qt.point(18.6, 27.7), Qt.point(17.4, 28.3), Qt.point(3.4, 0.3)]
			}
		}
	}
}
