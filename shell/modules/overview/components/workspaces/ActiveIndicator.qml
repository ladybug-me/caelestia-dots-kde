pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.services

StyledRect {
    id: root

    required property int activeWsId
    required property Repeater workspaces
    required property Item mask
    readonly property int currentWsIdx: {
        let i = activeWsId - 1;
        const count = workspaces.count > 0 ? workspaces.count : Config.bar.workspaces.shown;
        while (i < 0)
            i += count;
        return i % count;
    }
    property var currentItem: workspaces.count > 0 ? workspaces.itemAt(currentWsIdx) : null
    readonly property int indicatorSize: currentItem ? (currentItem as Workspace).indicatorSize : 40
    property real leading: currentItem ? currentItem.x : 0
    property real trailing: currentItem ? currentItem.x : 0
    property real currentSize: currentItem ? (currentItem as Workspace).size : 0
    property real offset: Math.min(leading, trailing)
    property real size: {
        const s = Math.abs(leading - trailing) + currentSize;
        if (Config.bar.workspaces.activeTrail && lastWs > currentWsIdx) {
            const ws = workspaces.itemAt(lastWs) as Workspace;
            return ws ? Math.min(ws.x + ws.size - offset, s) : 0;
        }
        return s;
    }
    property int cWs
    property int lastWs

    onCurrentWsIdxChanged: {
        lastWs = cWs;
        cWs = currentWsIdx;
    }
    clip: true
    anchors.verticalCenter: parent.verticalCenter
    x: offset + mask.x
    y: 0
    implicitWidth: size
    implicitHeight: indicatorSize
    radius: Tokens.rounding.large
    color: Colours.palette.m3primary

    Behavior on leading {
        enabled: root.Config.bar.workspaces.activeTrail

        EAnim {}
    }
    Behavior on trailing {
        enabled: root.Config.bar.workspaces.activeTrail

        EAnim {
            duration: Tokens.anim.durations.normal * 2
        }
    }
    Behavior on currentSize {
        enabled: root.Config.bar.workspaces.activeTrail

        EAnim {}
    }
    Behavior on offset {
        enabled: !root.Config.bar.workspaces.activeTrail

        EAnim {}
    }
    Behavior on size {
        enabled: !root.Config.bar.workspaces.activeTrail

        EAnim {}
    }

    component EAnim: Anim {
        type: Anim.Emphasized
    }
}
