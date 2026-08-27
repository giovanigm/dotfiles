// Network info: wifi icon by signal strength + download bitrate, ethernet icon,
// "Offline" when disconnected. Click opens networkmanager_dmenu.
// Bandwidth comes from SysInfo (sysfs deltas); frequency is not shown
// (no NetworkManager API for it in Quickshell 0.3).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

Module {
	id: root

	property var device: {
		for (const d of Networking.devices.values)
			if (d.connected && (d.type === DeviceType.Wifi || d.type === DeviceType.Wired)) return d
		return null
	}
	property var wifi: {
		if (!device || device.type !== DeviceType.Wifi) return null
		for (const n of device.networks.values)
			if (n.connected) return n
		return null
	}
	property real signal: wifi ? wifi.signalStrength : 0

	tip: root.tooltipText()

	ModuleText {
		text: root.displayText()
		color: root.displayColor()
	}

	onClicked: proc.startDetached()

	Process {
		id: proc
		command: ["networkmanager_dmenu"]
	}

	function displayText() {
		if (!device) return Theme.glyphOffline + "  Offline"
		if (device.type === DeviceType.Wired) return Theme.glyphEthernet + " " + Theme.bits(SysInfo.netDown)
		const icons = [Theme.glyphWifi0, Theme.glyphWifi1, Theme.glyphWifi2, Theme.glyphWifi3, Theme.glyphWifi4]
		const idx = Math.min(4, Math.round(signal * 4))
		return icons[idx] + " " + Theme.bits(SysInfo.netDown)
	}

	function displayColor() {
		if (!device) return Theme.caution
		if (device.type === DeviceType.Wired) return Theme.performance
		return signal < 0.25 ? Theme.warning : Theme.performance
	}

	function tooltipText() {
		if (!device) return ""
		if (device.type === DeviceType.Wired)
			return device.name + "\n" + Theme.glyphDown + " " + Theme.bits(SysInfo.netDown) + " \n" + Theme.glyphUp + " " + Theme.bits(SysInfo.netUp)
		return device.name + "\n" + (wifi ? wifi.name : "") + "\n" + Math.round(signal * 100) + "% \n" + Theme.glyphDown + " " + Theme.bits(SysInfo.netDown) + "\n" + Theme.glyphUp + " " + Theme.bits(SysInfo.netUp)
	}
}
