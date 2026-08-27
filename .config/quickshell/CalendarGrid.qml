// Waybar-style month calendar for the clock tooltip (weeks column on the right).
import QtQuick

Column {
	id: root

	property date month: new Date()
	property var monthRows: buildRows()

	spacing: 4

	function buildRows() {
		const y = month.getFullYear()
		const m = month.getMonth()
		const first = new Date(y, m, 1)
		const offset = (first.getDay() + 6) % 7 // Monday-first
		const days = new Date(y, m + 1, 0).getDate()
		const today = new Date()
		const rows = []
		let day = 1
		while (day <= days) {
			const cells = []
			for (let i = 0; i < 7; i++) {
				if (day > days) break
				const d = new Date(y, m, day)
				cells.push({
					day: day,
					today: today.getFullYear() === y && today.getMonth() === m && today.getDate() === day,
				})
				day++
			}
			// ISO week number of this row's Monday
			const monday = new Date(y, m, (day - cells.length))
			rows.push({ cells: cells, week: isoWeek(monday) })
		}
		return rows
	}

	function isoWeek(d) {
		const date = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
		const day = date.getUTCDay() || 7
		date.setUTCDate(date.getUTCDate() + 4 - day)
		const yearStart = new Date(Date.UTC(date.getUTCFullYear(), 0, 1))
		return Math.ceil(((date - yearStart) / 86400000 + 1) / 7)
	}

	Text {
		anchors.horizontalCenter: parent.horizontalCenter
		text: month.toLocaleString(Qt.locale(), "MMMM")
		color: "#cba6f7" // months
		font.family: Theme.fontFamily
		font.pixelSize: 14
		font.bold: true
	}

	Row {
		spacing: 4
		Repeater {
			model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
			delegate: Text {
				required property string modelData
				width: 18
				horizontalAlignment: Text.AlignHCenter
				text: modelData
				color: "#f9e2af" // weekdays
				font.family: Theme.fontFamily
				font.pixelSize: 14
				font.bold: true
			}
		}
		Text { text: ""; width: 18 }
	}

	Repeater {
		model: root.monthRows
		delegate: Row {
			required property var modelData
			spacing: 4
			Repeater {
				model: modelData.cells
				delegate: Text {
					required property var modelData
					width: 18
					horizontalAlignment: Text.AlignHCenter
					text: modelData.day
					color: modelData.today ? "#f5e0dc" : "#cdd6f4" // today / days
					font.family: Theme.fontFamily
					font.pixelSize: 14
					font.bold: true
					font.underline: modelData.today
				}
			}
			// fill short rows so the week column stays right-aligned
			Item { width: (7 - modelData.cells.length) * 22 }
			Text {
				width: 18
				horizontalAlignment: Text.AlignHCenter
				text: " W" + modelData.week
				color: "#94e2d5" // weeks
				font.family: Theme.fontFamily
				font.pixelSize: 14
			}
		}
	}
}
