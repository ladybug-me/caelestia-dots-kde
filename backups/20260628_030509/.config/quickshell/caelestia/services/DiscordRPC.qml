pragma Singleton

import QtQuick
import Caelestia.Config
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Caelestia
import Caelestia.Services
import qs.utils
import qs.services

Item {
    id: root

    property bool active: GlobalConfig.services.arpcEnabled
    property string clientId: GlobalConfig.services.arpcClientId || "1126685412586733678"

    property string steamGridDbKey: ""
    onSteamGridDbKeyChanged: {
        if (root.currentSteamAppId !== "") {
            root.currentSteamData = null;
            root.updatePresence();
        }
    }

    property Process readTokenProc: Process {
        command: ["secret-tool", "lookup", "service", "caelestia-shell", "account", "steamgriddb"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.steamGridDbKey = text.trim();
            }
        }
    }
    Component.onCompleted: {
        readTokenProc.running = true;
        if (root.active) {
            DiscordIpc.connectIpc(root.clientId);
        }
    }

    property real shellStartTime: Date.now() / 1000

    Connections {
        target: DiscordIpc
        function onConnectedChanged() {
            if (DiscordIpc.connected) {
                console.log("Discord ARPC connected");
                root.updatePresence();
            }
        }
        function onErrorOccurred(errorString) {
            console.log("Discord ARPC error: " + errorString);
        }
    }

    function testRegexList(list, str) {
        if (!list || !str) return false;
        let arr = Array.from(list);
        for (let i = 0; i < arr.length; i++) {
            let pattern = arr[i];
            if (pattern.startsWith("^") && pattern.endsWith("$")) {
                let re = new RegExp(pattern);
                if (re.test(str)) return true;
            } else if (pattern === str) {
                return true;
            }
        }
        return false;
    }

    Connections {
        target: Hyprland.toplevels
        ignoreUnknownSignals: true
        function onValuesChanged() { root.updatePresence(); }
    }

    Connections {
        target: GlobalConfig.services
        function onArpcSteamAutoDetectChanged() { root.updatePresence(); }
        function onArpcTargetWindowsChanged() { root.updatePresence(); }
        function onArpcCaelestiaInfoChanged() { root.updatePresence(); }
        function onArpcSteamBlacklistChanged() { root.updatePresence(); }
        function onArpcAppNameChanged() { root.updatePresence(); }
        function onArpcDetailsChanged() { root.updatePresence(); }
        function onArpcStateChanged() { root.updatePresence(); }
        function onArpcLargeImageChanged() { root.updatePresence(); }
        function onArpcSmallImageChanged() { root.updatePresence(); }
        function onArpcManualOverrideChanged() { root.updatePresence(); }
    }

    Connections {
        target: Colours
        function onSchemeChanged() { root.updatePresence(); }
        function onLightChanged() { root.updatePresence(); }
        function onVariantChanged() { root.updatePresence(); }
    }

    property string currentSteamAppId: ""
    property var currentSteamData: null
    property bool fetchingSteam: false

    function updatePresence() {
        if (!active || !DiscordIpc.connected) return;
        if (fetchingSteam) return; // Prevent loop during async fetch

        // Priority 0: Manual Override
        if (GlobalConfig.services.arpcManualOverride && (GlobalConfig.services.arpcAppName || GlobalConfig.services.arpcDetails || GlobalConfig.services.arpcState)) {
            root.currentSteamAppId = "";
            root.sendActivity({
                details: GlobalConfig.services.arpcDetails,
                state: GlobalConfig.services.arpcState,
                large_image: GlobalConfig.services.arpcLargeImage,
                small_image: GlobalConfig.services.arpcSmallImage,
                startTimestamp: root.shellStartTime
            });
            return;
        }

        let topSteamClass = "";
        let topSteamTitle = "";
        let topTargetClass = "";
        let topTargetTitle = "";

        for (const toplevel of Hyprland.toplevels.values) {
            let winClass = toplevel.lastIpcObject?.class ?? "";
            let winTitle = toplevel.title ?? "";

            if (GlobalConfig.services.arpcSteamAutoDetect && winClass.startsWith("steam_app_")) {
                let appId = winClass.replace("steam_app_", "");
                let isBlacklisted = root.testRegexList(GlobalConfig.services.arpcSteamBlacklist, appId) || root.testRegexList(GlobalConfig.services.arpcSteamBlacklist, "steam_app_" + appId);
                if (!isBlacklisted) {
                    topSteamClass = winClass;
                    topSteamTitle = winTitle;
                    break;
                }
            }

            if (topTargetClass === "" && GlobalConfig.services.arpcTargetWindows && root.testRegexList(GlobalConfig.services.arpcTargetWindows, winClass)) {
                topTargetClass = winClass;
                topTargetTitle = winTitle;
            }
        }

        // Priority 1: Steam Games
        if (topSteamClass !== "") {
            let appId = topSteamClass.replace("steam_app_", "");
            if (appId !== root.currentSteamAppId || !root.currentSteamData) {
                root.currentSteamAppId = appId;
                root.fetchSteamData(appId);
                return; 
            }
            if (root.currentSteamData) {
                root.sendActivity({
                    details: root.currentSteamData.name,
                    state: root.currentSteamData.state || "Playing via Steam",
                    large_image: root.currentSteamData.icon || "steam",
                    small_image: "",
                    startTimestamp: root.shellStartTime
                });
                return;
            }
        } else {
            root.currentSteamAppId = "";
        }

        // Priority 2: Custom Apps (Target Windows)
        if (topTargetClass !== "") {
            root.sendActivity({
                details: topTargetTitle,
                state: "Using " + topTargetClass,
                large_image: topTargetClass,
                small_image: "",
                startTimestamp: root.shellStartTime
            });
            return;
        }

        // Priority 3: Caelestia Info
        if (GlobalConfig.services.arpcCaelestiaInfo) {
            let os = SysInfo.osPrettyName || SysInfo.osName || "Linux";
            let kernel = SysInfo.kernel ? SysInfo.kernel : "";
            let qsVersion = CUtils.version ? " (v" + CUtils.version + ")" : "";
            
            let detailsStr = os;
            if (kernel) detailsStr += " • " + kernel;

            let schemeName = Colours.scheme || (Colours.light ? "Light Mode" : "Dark Mode");
            let stateStr = "Scheme: " + schemeName;
            if (Colours.variant) stateStr += " | Variant: " + Colours.variant;

            root.sendActivity({
                name: "Caelestia Shell" + qsVersion,
                details: detailsStr,
                state: stateStr,
                large_image: "https://avatars.githubusercontent.com/u/195541893",
                small_image: "",
                startTimestamp: root.shellStartTime,
                buttons: [
                    { label: "Website", url: "https://caelestiashell.com" },
                    { label: "GitHub", url: "https://github.com/caelestia-dots/" }
                ]
            });
            return;
        }

        root.clearActivity();
    }

    function fetchSteamData(appId) {
        root.fetchingSteam = true;
        Requests.get("https://store.steampowered.com/api/appdetails?appids=" + appId, function(steamRes) {
            let steamData = JSON.parse(steamRes);
            let gameName = "Unknown Steam Game (" + appId + ")";
            if (steamData && steamData[appId] && steamData[appId].success) {
                gameName = steamData[appId].data.name;
            }
                
            Requests.get("https://store.steampowered.com/appreviews/" + appId + "?json=1", function(revRes) {
                let revData = null;
                try { revData = JSON.parse(revRes); } catch(e) {}
                let reviewText = "Playing via Steam";
                if (revData && revData.query_summary && revData.query_summary.total_reviews > 0) {
                    let score = Math.round((revData.query_summary.total_positive / revData.query_summary.total_reviews) * 100);
                    let desc = revData.query_summary.review_score_desc || "Mixed";
                    reviewText = desc + " - " + score + "%";
                }

                if (root.steamGridDbKey !== "" && steamData && steamData[appId] && steamData[appId].success) {
                    let headers = { "Authorization": "Bearer " + root.steamGridDbKey };
                    Requests.get("https://www.steamgriddb.com/api/v2/games/steam/" + appId, function(dbRes) {
                        let dbData = null;
                        try { dbData = JSON.parse(dbRes); } catch(e) {}
                        if (dbData && dbData.success && dbData.data && dbData.data.id) {
                            let sgdbId = dbData.data.id;
                            Requests.get("https://www.steamgriddb.com/api/v2/icons/game/" + sgdbId, function(iconRes) {
                                let iconData = null;
                                try { iconData = JSON.parse(iconRes); } catch(e) {}
                                let iconUrl = "";
                                if (iconData && iconData.success && iconData.data && iconData.data.length > 0) {
                                    for (let i = 0; i < iconData.data.length; i++) {
                                        if (iconData.data[i].mime !== "image/x-icon" && iconData.data[i].mime !== "image/vnd.microsoft.icon") {
                                            iconUrl = iconData.data[i].url;
                                            break;
                                        }
                                    }
                                    if (iconUrl === "") iconUrl = iconData.data[0].url;
                                }
                                root.currentSteamData = { name: gameName, icon: iconUrl, state: reviewText };
                                root.fetchingSteam = false;
                                root.updatePresence();
                            }, function() {
                                root.currentSteamData = { name: gameName, icon: "", state: reviewText };
                                root.fetchingSteam = false;
                                root.updatePresence();
                            }, headers);
                        } else {
                            root.currentSteamData = { name: gameName, icon: "", state: reviewText };
                            root.fetchingSteam = false;
                            root.updatePresence();
                        }
                    }, function() {
                        root.currentSteamData = { name: gameName, icon: "", state: reviewText };
                        root.fetchingSteam = false;
                        root.updatePresence();
                    }, headers);
                } else {
                    root.currentSteamData = { name: gameName, icon: "", state: reviewText };
                    root.fetchingSteam = false;
                    root.updatePresence();
                }
            }, function() {
                root.currentSteamData = { name: gameName, icon: "", state: "Playing via Steam" };
                root.fetchingSteam = false;
                root.updatePresence();
            });
        }, function() {
            root.fetchingSteam = false;
        });
    }

    function sendActivity(data) {
        if (!DiscordIpc.connected) return;

        const activity = {};
        if (data.name && data.name !== "") activity.name = data.name;
        if (data.state && data.state !== "") activity.state = data.state;
        if (data.details && data.details !== "") activity.details = data.details;
        
        const assets = {};
        if (data.large_image && data.large_image !== "") assets.large_image = data.large_image;
        if (data.large_text && data.large_text !== "") assets.large_text = data.large_text;
        if (data.small_image && data.small_image !== "") assets.small_image = data.small_image;
        if (Object.keys(assets).length > 0) activity.assets = assets;

        if (data.buttons && data.buttons.length > 0) {
            activity.buttons = data.buttons;
        }

        if (data.startTimestamp) {
            activity.timestamps = {
                start: Math.floor(data.startTimestamp)
            };
        }
        DiscordIpc.sendActivity(activity);
    }

    function clearActivity() {
        if (!DiscordIpc.connected) return;
        DiscordIpc.clearActivity();
    }

    onActiveChanged: {
        if (!active) {
            DiscordIpc.disconnectIpc();
        } else {
            readTokenProc.running = true; // refresh token just in case
            DiscordIpc.connectIpc(root.clientId);
        }
    }
}
