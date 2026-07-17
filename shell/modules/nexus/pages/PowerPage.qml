pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.modules.nexus.common
import qs.services

PageBase {
    id: root

    property bool idleSuspendEnabledState: false
    property int idleSuspendMinutesState: 10

    function cloneEntry(entry: var): var {
        const out = {};
        for (const k in entry)
            out[k] = entry[k];
        return out;
    }

    function clonedIdleTimeouts(): var {
        const source = GlobalConfig.general.idle.timeouts ?? [];
        const copy = [];

        for (const entry of source)
            copy.push(root.cloneEntry(entry));

        return copy;
    }

    function refreshIdleSuspendState(): void {
        root.idleSuspendEnabledState = root.suspendTimeoutEnabled();
        root.idleSuspendMinutesState = root.suspendTimeoutMinutes();
    }

    function suspendTimeoutMinutes(): int {
        const entries = GlobalConfig.general.idle.timeouts ?? [];

        for (const entry of entries) {
            if (IdleActions.isSuspendIdleAction(entry.idleAction)) {
                const seconds = Number(entry.timeout);
                if (isFinite(seconds) && seconds > 0)
                    return Math.max(1, Math.round(seconds / 60));
            }
        }

        return 10;
    }

    function suspendTimeoutEnabled(): bool {
        const entries = GlobalConfig.general.idle.timeouts ?? [];

        for (const entry of entries) {
            if (IdleActions.isSuspendIdleAction(entry.idleAction))
                return entry.enabled ?? false;
        }

        return false;
    }

    function setSuspendTimeoutMinutes(minutes: int): void {
        const sanitizedMinutes = Math.max(1, Math.min(180, Math.round(minutes)));
        const timeoutSeconds = sanitizedMinutes * 60;
        const updated = root.clonedIdleTimeouts();
        let found = false;

        for (let i = 0; i < updated.length; i++) {
            if (!IdleActions.isSuspendIdleAction(updated[i].idleAction))
                continue;

            updated[i].timeout = timeoutSeconds;
            if (updated[i].enabled === undefined)
                updated[i].enabled = true;
            found = true;
        }

        if (!found) {
            updated.push({
                timeout: timeoutSeconds,
                idleAction: ["suspendThenHibernate"],
                enabled: true,
                respectInhibitors: true
            });
        }

        GlobalConfig.general.idle.timeouts = updated;
        root.refreshIdleSuspendState();
    }

    function setSuspendTimeoutEnabled(enabled: bool): void {
        const updated = root.clonedIdleTimeouts();
        let found = false;

        for (let i = 0; i < updated.length; i++) {
            if (!IdleActions.isSuspendIdleAction(updated[i].idleAction))
                continue;

            updated[i].enabled = enabled;
            found = true;
        }

        if (!found && enabled) {
            updated.push({
                timeout: 600,
                idleAction: ["suspendThenHibernate"],
                enabled: true,
                respectInhibitors: true
            });
        }

        GlobalConfig.general.idle.timeouts = updated;
        root.refreshIdleSuspendState();
    }

    Component.onCompleted: root.refreshIdleSuspendState()

    title: qsTr("Power")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Battery indicators")
        }

        ToggleRow {
            first: true
            text: qsTr("Show battery icon")
            checked: Config.bar.status.showBattery
            onToggled: GlobalConfig.bar.status.showBattery = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Show peripheral battery")
            checked: Config.bar.status.showPeripheralBattery
            onToggled: GlobalConfig.bar.status.showPeripheralBattery = checked
        }

        SectionHeader {
            text: qsTr("Idle & sleep")
        }

        ToggleRow {
            first: true
            text: qsTr("Idle suspend")
            subtext: qsTr("Suspend the system after inactivity")
            checked: root.idleSuspendEnabledState
            onToggled: root.setSuspendTimeoutEnabled(checked)
        }

        StepperRow {
            last: true
            enabled: root.idleSuspendEnabledState
            label: qsTr("Idle suspend timer")
            subtext: root.idleSuspendEnabledState
                     ? qsTr("Suspend after %1 minute(s) of inactivity").arg(root.idleSuspendMinutesState)
                     : qsTr("Enable idle suspend to apply a timer")
            value: root.idleSuspendMinutesState
            from: 1
            to: 180
            stepSize: 1
            onMoved: v => {
                if (root.idleSuspendEnabledState)
                    root.setSuspendTimeoutMinutes(v)
            }
        }
    }
}
