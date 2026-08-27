// Reusable blink driver — alternates `value` between colorA and colorB.
// Matches waybar's 1s alternate blink animations.
import QtQuick

Item {
	id: root

	property color colorA: Theme.text
	property color colorB: Theme.separator
	property bool running: false
	property color value: colorA

	SequentialAnimation {
		id: anim
		running: root.running
		loops: Animation.Infinite
		ColorAnimation {
			target: root
			property: "value"
			to: root.colorB
			duration: 500
		}
		ColorAnimation {
			target: root
			property: "value"
			to: root.colorA
			duration: 500
		}
	}
}
