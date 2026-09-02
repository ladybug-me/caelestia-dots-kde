import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia
import Caelestia.Config
import qs.components
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    // Plugin support is not wired up yet; always 0 for now
    readonly property int pluginCount: 0

    property string quickshellVersion
    property string cliVersion

    title: I18n.tr("About")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // e.g. "Quickshell 0.3.0 (revision ...)"
        Process {
            running: true
            command: ["quickshell", "--version"]
            stdout: StdioCollector {
                onStreamFinished: root.quickshellVersion = text.trim().split(" ")[1] ?? ""
            }
        }

        // Parsed from the caelestia CLI's package listing; the sh wrapper avoids a
        // warning when the (optional) CLI isn't installed
        Process {
            running: true
            command: ["sh", "-c", "caelestia --version 2>/dev/null"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const m = text.match(/caelestia-cli\S*\s+(\d+(?:\.\d+)*)/);
                    root.cliVersion = m ? m[1] : "";
                }
            }
        }

        // Hero
        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: hero.implicitHeight + Tokens.padding.extraLarge * 2

            ColumnLayout {
                id: hero

                anchors.centerIn: parent
                width: parent.width - Tokens.padding.largeIncreased * 2
                spacing: Tokens.spacing.small

                AnimatedLogo {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: implicitWidth
                    Layout.preferredHeight: implicitHeight
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Tokens.spacing.small
                    text: "Caelestia"
                    font: Tokens.font.headline.builders.large.width(110).build()
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: CUtils.version ? `v${CUtils.version}` : "…"
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.medium
                }
            }
        }

        // System
        SectionHeader {
            text: I18n.tr("System")
        }

        InfoRow {
            first: true
            label: I18n.tr("Hostname")
            value: SysInfo.hostname
        }

        InfoRow {
            label: I18n.tr("Device")
            value: SysInfo.device
        }

        InfoRow {
            label: I18n.tr("Distro")
            value: SysInfo.osPrettyName || SysInfo.osName
        }

        InfoRow {
            label: I18n.tr("Kernel")
            value: SysInfo.kernel
        }

        InfoRow {
            last: true
            label: I18n.tr("Firmware")
            value: SysInfo.firmware
        }

        // Software
        SectionHeader {
            text: I18n.tr("Software")
        }

        InfoRow {
            first: true
            label: I18n.tr("Shell")
            value: CUtils.version || "…"
        }

        InfoRow {
            label: I18n.tr("CLI")
            value: root.cliVersion || "…"
        }

        InfoRow {
            label: I18n.tr("Quickshell")
            value: root.quickshellVersion || "…"
        }

        InfoRow {
            last: true
            label: I18n.tr("Qt")
            value: CUtils.qtVersion || "…"
        }

        // Plugins
        SectionHeader {
            text: I18n.tr("Plugins")
        }

        InfoRow {
            first: true
            last: true
            label: I18n.tr("Loaded plugins")
            value: root.pluginCount.toString()
        }

        // Advanced
        SectionHeader {
            text: I18n.tr("Advanced")
        }

        ToggleRow {
            first: true
            last: true
            text: I18n.tr("Debug Mode")
            subtext: I18n.tr("Enable verbose debug logging for troubleshooting. Run 'caelestia shell -l' to view.")
            checked: GlobalConfig.general.debugLogs
            onClicked: GlobalConfig.general.debugLogs = !GlobalConfig.general.debugLogs
        }
    }
}
