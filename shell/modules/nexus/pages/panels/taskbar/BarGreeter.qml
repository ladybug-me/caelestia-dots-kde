pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.filedialog
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Greeter")
    isSubPage: true
    scrollable: true

    readonly property list<MenuItem> modeItems: [
        MenuItem { text: qsTr("Time of day"); icon: "schedule" },
        MenuItem { text: qsTr("Slideshow"); icon: "slideshow" }
    ]

    function formatHour(h: int): string {
        if (GlobalConfig.services.useTwelveHourClock) {
            const period = h >= 12 ? "PM" : "AM";
            const hour12 = (h % 12 === 0) ? 12 : (h % 12);
            return `${hour12}:00 ${period}`;
        }
        return `${h < 10 ? "0" + h : h}:00`;
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("General Settings")
        }

        ToggleRow {
            first: true
            text: qsTr("Enable component")
            checked: {
                const entries = Config.bar.entries || [];
                for (let i = 0; i < entries.length; i++) {
                    if (entries[i].id === "greeter" || entries[i].id === "activeWindow")
                        return entries[i].enabled;
                }
                return false;
            }
            onToggled: {
                let newEntries = [...(GlobalConfig.bar.entries || [])];
                let found = false;
                for (let i = 0; i < newEntries.length; i++) {
                    if (newEntries[i].id === "greeter" || newEntries[i].id === "activeWindow") {
                        newEntries[i].enabled = checked;
                        found = true;
                        break;
                    }
                }

                if (!found) {
                    newEntries.push({ id: "greeter", enabled: checked, zone: "left" });
                }

                GlobalConfig.bar.entries = newEntries;
                GlobalConfig.save();
            }
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Compact")
            checked: Config.bar.greeter?.compact ?? false
            onToggled: {
                GlobalConfig.bar.greeter.compact = checked;
                GlobalConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("Inverted")
            checked: Config.bar.greeter?.inverted ?? false
            onToggled: {
                GlobalConfig.bar.greeter.inverted = checked;
                GlobalConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("Show on hover")
            subtext: qsTr("Only show the greeter while hovering")
            checked: Config.bar.greeter?.showOnHover ?? true
            onToggled: {
                GlobalConfig.bar.greeter.showOnHover = checked;
                GlobalConfig.save();
            }
        }

        ToggleRow {
            last: true
            text: qsTr("Popout on hover")
            subtext: qsTr("Show a greeter popout when hovering")
            checked: Config.bar.popouts?.greeter ?? true
            onToggled: {
                GlobalConfig.bar.popouts.greeter = checked;
                GlobalConfig.save();
            }
        }

        SectionHeader {
            text: qsTr("Animation Mechanism")
        }

        SelectRow {
            first: true
            last: true
            label: qsTr("Mode")
            subtext: qsTr("Switch GIFs according to time of day or cycle through a slideshow")
            menuItems: root.modeItems
            active: (Config.bar.greeter?.mode === "slideshow") ? root.modeItems[1] : root.modeItems[0]
            onSelected: item => {
                GlobalConfig.bar.greeter.mode = (item === root.modeItems[1]) ? "slideshow" : "timeOfDay";
                GlobalConfig.save();
            }
        }

        // ==========================================
        // TIME OF DAY SECTION
        // ==========================================
        SectionHeader {
            visible: (Config.bar.greeter?.mode ?? "timeOfDay") !== "slideshow"
            text: qsTr("Time of Day Periods & GIFs")
        }

        NavRow {
            visible: (Config.bar.greeter?.mode ?? "timeOfDay") !== "slideshow"
            first: true
            icon: "wb_twilight"
            label: qsTr("Morning GIF")
            status: {
                const p = Config.bar.greeter?.morningGif || "morning.gif";
                return p.includes("/") ? p.split("/").pop() : p;
            }
            onClicked: morningDialog.open()

            FileDialog {
                id: morningDialog
                title: qsTr("Select Morning GIF")
                filterLabel: qsTr("GIF / Animated files")
                filters: ["gif", "webp"]
                onAccepted: path => {
                    GlobalConfig.bar.greeter.morningGif = path;
                    GlobalConfig.save();
                }
            }
        }

        StepperRow {
            visible: (Config.bar.greeter?.mode ?? "timeOfDay") !== "slideshow"
            label: qsTr("Morning start time")
            subtext: root.formatHour(Config.bar.greeter?.morningStart ?? 5)
            value: Config.bar.greeter?.morningStart ?? 5
            from: 0
            to: 23
            stepSize: 1
            onMoved: v => {
                GlobalConfig.bar.greeter.morningStart = Math.round(v);
                GlobalConfig.save();
            }
        }

        NavRow {
            visible: (Config.bar.greeter?.mode ?? "timeOfDay") !== "slideshow"
            icon: "light_mode"
            label: qsTr("Afternoon GIF")
            status: {
                const p = Config.bar.greeter?.afternoonGif || "afternoon.gif";
                return p.includes("/") ? p.split("/").pop() : p;
            }
            onClicked: afternoonDialog.open()

            FileDialog {
                id: afternoonDialog
                title: qsTr("Select Afternoon GIF")
                filterLabel: qsTr("GIF / Animated files")
                filters: ["gif", "webp"]
                onAccepted: path => {
                    GlobalConfig.bar.greeter.afternoonGif = path;
                    GlobalConfig.save();
                }
            }
        }

        StepperRow {
            visible: (Config.bar.greeter?.mode ?? "timeOfDay") !== "slideshow"
            label: qsTr("Afternoon start time")
            subtext: root.formatHour(Config.bar.greeter?.afternoonStart ?? 12)
            value: Config.bar.greeter?.afternoonStart ?? 12
            from: 0
            to: 23
            stepSize: 1
            onMoved: v => {
                GlobalConfig.bar.greeter.afternoonStart = Math.round(v);
                GlobalConfig.save();
            }
        }

        NavRow {
            visible: (Config.bar.greeter?.mode ?? "timeOfDay") !== "slideshow"
            icon: "wb_twilight"
            label: qsTr("Evening GIF")
            status: {
                const p = Config.bar.greeter?.eveningGif || "evening.gif";
                return p.includes("/") ? p.split("/").pop() : p;
            }
            onClicked: eveningDialog.open()

            FileDialog {
                id: eveningDialog
                title: qsTr("Select Evening GIF")
                filterLabel: qsTr("GIF / Animated files")
                filters: ["gif", "webp"]
                onAccepted: path => {
                    GlobalConfig.bar.greeter.eveningGif = path;
                    GlobalConfig.save();
                }
            }
        }

        StepperRow {
            visible: (Config.bar.greeter?.mode ?? "timeOfDay") !== "slideshow"
            label: qsTr("Evening start time")
            subtext: root.formatHour(Config.bar.greeter?.eveningStart ?? 17)
            value: Config.bar.greeter?.eveningStart ?? 17
            from: 0
            to: 23
            stepSize: 1
            onMoved: v => {
                GlobalConfig.bar.greeter.eveningStart = Math.round(v);
                GlobalConfig.save();
            }
        }

        NavRow {
            visible: (Config.bar.greeter?.mode ?? "timeOfDay") !== "slideshow"
            icon: "bedtime"
            label: qsTr("Night GIF")
            status: {
                const p = Config.bar.greeter?.nightGif || "night.gif";
                return p.includes("/") ? p.split("/").pop() : p;
            }
            onClicked: nightDialog.open()

            FileDialog {
                id: nightDialog
                title: qsTr("Select Night GIF")
                filterLabel: qsTr("GIF / Animated files")
                filters: ["gif", "webp"]
                onAccepted: path => {
                    GlobalConfig.bar.greeter.nightGif = path;
                    GlobalConfig.save();
                }
            }
        }

        StepperRow {
            visible: (Config.bar.greeter?.mode ?? "timeOfDay") !== "slideshow"
            last: true
            label: qsTr("Night start time")
            subtext: root.formatHour(Config.bar.greeter?.nightStart ?? 20)
            value: Config.bar.greeter?.nightStart ?? 20
            from: 0
            to: 23
            stepSize: 1
            onMoved: v => {
                GlobalConfig.bar.greeter.nightStart = Math.round(v);
                GlobalConfig.save();
            }
        }

        // ==========================================
        // SLIDESHOW SECTION
        // ==========================================
        SectionHeader {
            visible: (Config.bar.greeter?.mode ?? "timeOfDay") === "slideshow"
            text: qsTr("Slideshow Timing & Order")
        }

        StepperRow {
            visible: (Config.bar.greeter?.mode ?? "timeOfDay") === "slideshow"
            first: true
            label: qsTr("Slide interval")
            subtext: qsTr("%1 seconds").arg(Math.round(Config.bar.greeter?.slideshowInterval ?? 60))
            value: Config.bar.greeter?.slideshowInterval ?? 60
            from: 5
            to: 3600
            stepSize: 5
            onMoved: v => {
                GlobalConfig.bar.greeter.slideshowInterval = v;
                GlobalConfig.save();
            }
        }

        ToggleRow {
            visible: (Config.bar.greeter?.mode ?? "timeOfDay") === "slideshow"
            last: true
            text: qsTr("Random shuffle")
            subtext: qsTr("Pick random GIFs instead of cycling sequentially")
            checked: Config.bar.greeter?.slideshowRandom ?? false
            onToggled: {
                GlobalConfig.bar.greeter.slideshowRandom = checked;
                GlobalConfig.save();
            }
        }

        SectionHeader {
            visible: (Config.bar.greeter?.mode ?? "timeOfDay") === "slideshow"
            text: qsTr("Slideshow Folders")
        }

        NavRow {
            visible: (Config.bar.greeter?.mode ?? "timeOfDay") === "slideshow"
            first: true
            last: (Config.bar.greeter?.slideshowFolders || []).length === 0
            icon: "create_new_folder"
            label: qsTr("Add GIF folder")
            status: qsTr("Select a folder containing GIF animations")
            onClicked: addFolderDialog.open()

            FileDialog {
                id: addFolderDialog
                title: qsTr("Select GIF Folder")
                selectFolder: true
                onAccepted: path => {
                    let folders = [...(GlobalConfig.bar.greeter?.slideshowFolders || [])];
                    if (!folders.includes(path)) {
                        folders.push(path);
                        GlobalConfig.bar.greeter.slideshowFolders = folders;
                        GlobalConfig.save();
                    }
                }
            }
        }

        Repeater {
            model: (Config.bar.greeter?.mode ?? "timeOfDay") === "slideshow" ? (Config.bar.greeter?.slideshowFolders || []) : []

            delegate: ConnectedRect {
                id: folderRow
                required property string modelData
                required property int index

                Layout.fillWidth: true
                first: false
                last: index === ((Config.bar.greeter?.slideshowFolders?.length ?? 1) - 1)

                implicitHeight: fRow.implicitHeight + Tokens.padding.medium * 2

                RowLayout {
                    id: fRow
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.largeIncreased
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: "folder"
                        color: Colours.palette.m3primary
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: folderRow.modelData
                        font: Tokens.font.body.small
                        elide: Text.ElideMiddle
                    }

                    IconButton {
                        type: IconButton.Text
                        icon: "close"
                        onClicked: {
                            let folders = [...(GlobalConfig.bar.greeter?.slideshowFolders || [])];
                            folders.splice(folderRow.index, 1);
                            GlobalConfig.bar.greeter.slideshowFolders = folders;
                            GlobalConfig.save();
                        }
                    }
                }
            }
        }

        SectionHeader {
            visible: (Config.bar.greeter?.mode ?? "timeOfDay") === "slideshow"
            text: qsTr("Individual Slideshow GIFs")
        }

        NavRow {
            visible: (Config.bar.greeter?.mode ?? "timeOfDay") === "slideshow"
            first: true
            last: (Config.bar.greeter?.slideshowGifs || []).length === 0
            icon: "add_photo_alternate"
            label: qsTr("Add GIF file")
            status: qsTr("Select specific GIF file to include in slideshow")
            onClicked: addGifDialog.open()

            FileDialog {
                id: addGifDialog
                title: qsTr("Select a GIF File")
                filterLabel: qsTr("GIF / Animated files")
                filters: ["gif", "webp"]
                onAccepted: path => {
                    let files = [...(GlobalConfig.bar.greeter?.slideshowGifs || [])];
                    if (!files.includes(path)) {
                        files.push(path);
                        GlobalConfig.bar.greeter.slideshowGifs = files;
                        GlobalConfig.save();
                    }
                }
            }
        }

        Repeater {
            model: (Config.bar.greeter?.mode ?? "timeOfDay") === "slideshow" ? (Config.bar.greeter?.slideshowGifs || []) : []

            delegate: ConnectedRect {
                id: fileRow
                required property string modelData
                required property int index

                Layout.fillWidth: true
                first: false
                last: index === ((Config.bar.greeter?.slideshowGifs?.length ?? 1) - 1)

                implicitHeight: gRow.implicitHeight + Tokens.padding.medium * 2

                RowLayout {
                    id: gRow
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.largeIncreased
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: "gif"
                        color: Colours.palette.m3secondary
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: fileRow.modelData.split("/").pop()
                        font: Tokens.font.body.small
                        elide: Text.ElideMiddle
                    }

                    IconButton {
                        type: IconButton.Text
                        icon: "close"
                        onClicked: {
                            let files = [...(GlobalConfig.bar.greeter?.slideshowGifs || [])];
                            files.splice(fileRow.index, 1);
                            GlobalConfig.bar.greeter.slideshowGifs = files;
                            GlobalConfig.save();
                        }
                    }
                }
            }
        }
    }
}
