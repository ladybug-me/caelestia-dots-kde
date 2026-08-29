pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Pipewire
import qs.components.controls
import qs.services
import qs.utils

// A "now playing" app-stream volume row. The bar audio popout and the Nexus
// app-volumes page used to repeat this exact wiring; the icon, the label, the
// muted readout and the set-volume call now live in one place.
SliderRow {
    id: root

    required property PwNode node

    // Only the bar popout makes the icon a mute toggle; the Nexus page keeps
    // it decorative.
    property bool muteOnIconClick: false

    iconClickable: root.muteOnIconClick
    icon: Icons.getVolumeIcon(Audio.getAppVolume(root.node), Audio.getAppMuted(root.node))
    label: Audio.getStreamName(root.node)
    valueLabel: Audio.getAppMuted(root.node) ? qsTr("Muted") : Math.round(value * 100) + "%"
    value: Audio.getAppVolume(root.node)
    onIconClicked: Audio.setAppMuted(root.node, !Audio.getAppMuted(root.node))
    onMoved: v => Audio.setAppVolume(root.node, v)
}
