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
    required property bool fullscreen

    readonly property int currentWsIdx: {
        let i = activeWsId - 1;
        const count = workspaces.count > 0 ? workspaces.count : Config.bar.workspaces.shown;
        while (i < 0)
            i += count;
        return i % count;
    }

    readonly property bool isHorizontal: Config.bar.position === "top" || Config.bar.position === "bottom"
    readonly property int barThickness: Math.round(Tokens.sizes.bar.innerWidth * Math.max(0.6, !isNaN(Config.bar.scale) ? Config.bar.scale : 1.0))

    property var currentItem: workspaces.count > 0 ? workspaces.itemAt(currentWsIdx) : null
    property real leading: currentItem ? (isHorizontal ? currentItem.x : currentItem.y) : 0
    property real trailing: currentItem ? (isHorizontal ? currentItem.x : currentItem.y) : 0
    property real currentSize: currentItem ? (currentItem as Workspace).size : 0
    property real offset: Math.min(leading, trailing)
    property real size: {
        const s = Math.abs(leading - trailing) + currentSize;
        if (Config.bar.workspaces.activeTrail && lastWs > currentWsIdx) {
            const ws = workspaces.itemAt(lastWs) as Workspace;
            return ws ? Math.min((isHorizontal ? ws.x : ws.y) + ws.size - offset, s) : 0;
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
    anchors.horizontalCenter: isHorizontal ? undefined : parent.horizontalCenter
    anchors.verticalCenter: isHorizontal ? parent.verticalCenter : undefined

    x: isHorizontal ? offset + mask.x : 0
    y: isHorizontal ? 0 : offset + mask.y
    implicitWidth: isHorizontal ? size : barThickness - Tokens.padding.small
    implicitHeight: isHorizontal ? barThickness - Tokens.padding.small : size
    radius: Tokens.rounding.full
    color: Colours.palette.m3primary

    Colouriser {
        source: root.mask
        sourceColor: Colours.palette.m3onSurface
        colorizationColor: Colours.palette.m3onPrimary

        x: isHorizontal ? -parent.offset : 0
        y: isHorizontal ? 0 : -parent.offset
        implicitWidth: root.mask.implicitWidth
        implicitHeight: root.mask.implicitHeight

        anchors.horizontalCenter: isHorizontal ? undefined : parent.horizontalCenter
        anchors.verticalCenter: isHorizontal ? parent.verticalCenter : undefined
    }

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
