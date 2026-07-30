pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia
import Caelestia.Config
import Caelestia.Services
import Quickshell
import Quickshell.Io
import qs.components
import qs.components.controls
import qs.modules.nexus.common


PageBase {
    id: root

    property bool showLogout: false
    title: qsTr("Window Tiling")
    isSubPage: true


    headerActions: [
        IconTextButton {
            text: qsTr("Save Changes")
            icon: "check"
            type: TextButton.Filled
            onClicked: {
                KrohnkiteConfig.apply()
                showLogout = true;
            }
        },
        IconTextButton {
            visible: showLogout
            text: qsTr("Logout to Apply Changes")
            icon: "logout"
            type: TextButton.Filled
            onClicked: restartProcess.running = true
            
            Process {
                id: restartProcess
                command: ["bash", "-c", "nohup bash -c 'qdbus6 org.kde.Shutdown /Shutdown org.kde.Shutdown.logout 2>/dev/null || true' >/dev/null 2>&1"]
            }
        }
    ]

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Main Toggle
        ToggleRow {
            Layout.fillWidth: true
            first: true
            last: true
            text: qsTr("Window Tiling")
            subtext: qsTr("Automatically tile windows using Krohnkite")
            checked: Config.general.krohnkiteEnabled
            onToggled: {
                GlobalConfig.general.krohnkiteEnabled = checked;
                GlobalConfig.save();
                Quickshell.execDetached(["bash", "-c", `
                    if [[ "${checked ? 'true' : 'false'}" == "true" ]]; then
                        qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "krohnkite" 2>/dev/null || true
                        if ! kpackagetool6 -t KWin/Script -s krohnkite >/dev/null 2>&1; then
                            if command -v kpackagetool6 >/dev/null 2>&1; then
                                notify-send "Installing Krohnkite..." "Please stay connected to internet.."
                                tmpdir="$(mktemp -d)"
                                kwinscript_url="$(curl -sL https://codeberg.org/api/v1/repos/anametologin/Krohnkite/releases/latest | grep -oP '"browser_download_url":\\s*"\\K[^"]+\\.kwinscript' | head -1)"
                                if [[ -n "$kwinscript_url" ]] && curl -sL "$kwinscript_url" -o "$tmpdir/krohnkite.kwinscript"; then
                                    kpackagetool6 -t KWin/Script -i "$tmpdir/krohnkite.kwinscript" 2>/dev/null || true
                                    notify-send "Installation Completed.." "Krohnkite has been installed successfully.."
                                else
                                    notify-send "Installation Failed.." "Krohnkite could not be downloaded. Please try again.."
                                fi
                                rm -rf "$tmpdir"
                            fi
                        fi
                        kwriteconfig6 --file kwinrc --group "Plugins" --key "krohnkiteEnabled" "true" 2>/dev/null || true
                        qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true
                    else
                        qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut "KrohnkiteFloatAll" 2>/dev/null || true
                        sleep 0.1
                        qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "krohnkite" 2>/dev/null || true
                        kwriteconfig6 --file kwinrc --group "Plugins" --key "krohnkiteEnabled" "false" 2>/dev/null || true
                        qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true
                    fi
                `]);
            }
        }

        SectionHeader {
            Layout.topMargin: Tokens.spacing.medium
            text: qsTr("Gaps")
        }

        StepperRow {
            first: true
            label: qsTr("Gap Between Windows")
            subtext: qsTr("Space between tiled windows")
            from: 0
            to: 80
            value: KrohnkiteConfig.screenGapBetween
            onMoved: v => KrohnkiteConfig.screenGapBetween = v
        }

        StepperRow {
            label: qsTr("Top Gap")
            subtext: qsTr("Distance from the top screen edge")
            from: 0
            to: 80
            value: KrohnkiteConfig.screenGapTop
            onMoved: v => KrohnkiteConfig.screenGapTop = v
        }

        StepperRow {
            label: qsTr("Bottom Gap")
            subtext: qsTr("Distance from the bottom screen edge")
            from: 0
            to: 80
            value: KrohnkiteConfig.screenGapBottom
            onMoved: v => KrohnkiteConfig.screenGapBottom = v
        }

        StepperRow {
            label: qsTr("Left Gap")
            subtext: qsTr("Distance from the left screen edge")
            from: 0
            to: 80
            value: KrohnkiteConfig.screenGapLeft
            onMoved: v => KrohnkiteConfig.screenGapLeft = v
        }

        StepperRow {
            last: true
            label: qsTr("Right Gap")
            subtext: qsTr("Distance from the right screen edge")
            from: 0
            to: 80
            value: KrohnkiteConfig.screenGapRight
            onMoved: v => KrohnkiteConfig.screenGapRight = v
        }

        SectionHeader {
            Layout.topMargin: Tokens.spacing.medium
            text: qsTr("Ignored Window Classes")
        }

        ConnectedRect {
            first: true
            last: true
            Layout.fillWidth: true
            implicitHeight: Math.max(rowLayout.implicitHeight, 48)

            RowLayout {
                id: rowLayout
                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Window Classes")
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Comma separated list of classes to not tile (e.g. quickshell,krunner)")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                        elide: Text.ElideRight
                    }
                }

                StyledTextField {
                    Layout.preferredWidth: parent.width / 2
                    Layout.alignment: Qt.AlignVCenter
                    placeholderText: "krunner,yakuake,spectacle..."
                    text: KrohnkiteConfig.ignoreClass
                    onAccepted: KrohnkiteConfig.ignoreClass = text
                }
            }
        }

        SectionHeader {
            Layout.topMargin: Tokens.spacing.medium
            text: qsTr("Enabled Layouts")
        }

        ToggleRow {
            first: true
            text: qsTr("Binary Tree")
            checked: KrohnkiteConfig.binaryTreeLayoutEnabled
            onToggled: KrohnkiteConfig.binaryTreeLayoutEnabled = checked
        }

        ToggleRow {
            text: qsTr("Floating")
            checked: KrohnkiteConfig.floatingLayoutEnabled
            onToggled: KrohnkiteConfig.floatingLayoutEnabled = checked
        }

        ToggleRow {
            text: qsTr("Monocle")
            checked: KrohnkiteConfig.monocleLayoutEnabled
            onToggled: KrohnkiteConfig.monocleLayoutEnabled = checked
        }

        ToggleRow {
            text: qsTr("Quarter")
            checked: KrohnkiteConfig.quarterLayoutEnabled
            onToggled: KrohnkiteConfig.quarterLayoutEnabled = checked
        }

        ToggleRow {
            text: qsTr("Spiral")
            checked: KrohnkiteConfig.spiralLayoutEnabled
            onToggled: KrohnkiteConfig.spiralLayoutEnabled = checked
        }

        ToggleRow {
            text: qsTr("Spread")
            checked: KrohnkiteConfig.spreadLayoutEnabled
            onToggled: KrohnkiteConfig.spreadLayoutEnabled = checked
        }

        ToggleRow {
            text: qsTr("Stacked")
            checked: KrohnkiteConfig.stackedLayoutEnabled
            onToggled: KrohnkiteConfig.stackedLayoutEnabled = checked
        }

        ToggleRow {
            text: qsTr("Stair")
            checked: KrohnkiteConfig.stairLayoutEnabled
            onToggled: KrohnkiteConfig.stairLayoutEnabled = checked
        }

        ToggleRow {
            text: qsTr("Three Column")
            checked: KrohnkiteConfig.threeColumnLayoutEnabled
            onToggled: KrohnkiteConfig.threeColumnLayoutEnabled = checked
        }

        ToggleRow {
            text: qsTr("Tile")
            checked: KrohnkiteConfig.tileLayoutEnabled
            onToggled: KrohnkiteConfig.tileLayoutEnabled = checked
        }
        
        ToggleRow {
            text: qsTr("Cascade")
            checked: KrohnkiteConfig.cascadeLayoutEnabled
            onToggled: KrohnkiteConfig.cascadeLayoutEnabled = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Columns")
            checked: KrohnkiteConfig.columnsLayoutEnabled
            onToggled: KrohnkiteConfig.columnsLayoutEnabled = checked
        }
    }
}
