import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    property bool isFetching: false
    property string errorMessage: ""
    
    // Bind colors at the root to avoid delegate scope resolution issues
    readonly property color cBgHigh: Colours.tPalette.m3surfaceContainerHigh
    readonly property color cBgHighest: Colours.tPalette.m3surfaceContainerHighest
    readonly property color cOnSurface: Colours.palette.m3onSurface
    readonly property color cOnSurfaceVariant: Colours.palette.m3onSurfaceVariant
    readonly property color cError: Colours.palette.m3error

    Component.onCompleted: fetchNews()

    // ── Distro-aware news feed ────────────────────────────────────
    // The feed URL is chosen based on the running distribution so Fedora
    // users see Fedora news rather than an irrelevant Arch Linux feed.

    function newsFeedUrl() {
        var process = Qt.createQmlObject(
            'import QtQuick\n' +
            'import Quickshell.Io\n' +
            'Process {\n' +
            '    id: p\n' +
            '    command: ["sh", "-c", \'. /etc/os-release 2>/dev/null && echo "$ID"\']\n' +
            '    stdout: StdioCollector { onStreamFinished: p.destroy(); }\n' +
            '}', root, "osReleaseProc");
        return process;
    }

    property string _distroId: ""

    function fetchNews() {
        if (isFetching) return;
        isFetching = true;
        errorMessage = "";
        
        // Default to Arch; re-read /etc/os-release to decide at fetch time
        // so the feed is correct even if the shell was started before the OS
        // release file was updated.
        var feedUrl = "https://archlinux.org/feeds/news/";
        if (_distroId === "") {
            var proc = newsFeedUrl();
            if (proc && proc.stdout) {
                proc.stdout.onStreamFinished = function() {
                    var id = (proc.stdout.text || "").trim();
                    _distroId = id;
                    doFetch(id);
                    if (proc) proc.destroy();
                };
                proc.running = true;
                return;
            }
        }
        doFetch(_distroId);
    }

    function doFetch(distroId) {
        var feedUrl = "https://archlinux.org/feeds/news/";
        // Map known distro IDs to their news/blog feeds. Falls back to
        // Arch Linux news for unrecognised distributions.
        var feedMap = {
            "fedora": "https://fedoramagazine.org/feed/",
            "arch": "https://archlinux.org/feeds/news/",
            "cachyos": "https://archlinux.org/feeds/news/",
            "endeavouros": "https://archlinux.org/feeds/news/",
            "manjaro": "https://archlinux.org/feeds/news/",
            "ubuntu": "https://ubuntu.com/blog/feed",
            "debian": "https://www.debian.org/News/news.en.rss",
            "opensuse": "https://news.opensuse.org/feed/",
        };
        if (feedMap[distroId])
            feedUrl = feedMap[distroId];

        var xhr = new XMLHttpRequest();
        xhr.open("GET", feedUrl);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                isFetching = false;
                if (xhr.status === 200) {
                    parseNews(xhr.responseText);
                } else {
                    errorMessage = I18n.tr("Failed to fetch news (Status: %1)").arg(xhr.status);
                }
            }
        };
        xhr.send();
    }

    function parseNews(xmlString) {
        newsModel.clear();
        
        var itemRegex = /<item>([\s\S]*?)<\/item>/g;
        var titleRegex = /<title>(.*?)<\/title>/;
        var linkRegex = /<link>(.*?)<\/link>/;
        var dateRegex = /<pubDate>(.*?)<\/pubDate>/;
        
        var match;
        while ((match = itemRegex.exec(xmlString)) !== null) {
            var itemContent = match[1];
            
            var titleMatch = titleRegex.exec(itemContent);
            var linkMatch = linkRegex.exec(itemContent);
            var dateMatch = dateRegex.exec(itemContent);
            
            if (titleMatch && linkMatch && dateMatch) {
                // Remove CDATA if present or unescape basic HTML entities
                var title = titleMatch[1].replace(/<!\[CDATA\[(.*?)\]\]>/g, "$1").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"").replace(/&#039;/g, "'");
                var dateStr = dateMatch[1];
                
                // Format date nicely
                var dateObj = new Date(dateStr);
                var formattedDate = dateObj.toLocaleDateString();
                if (formattedDate === "Invalid Date") formattedDate = dateStr;
                
                newsModel.append({
                    "title": title,
                    "link": linkMatch[1],
                    "date": formattedDate
                });
            }
        }
        
        if (newsModel.count === 0) {
            errorMessage = I18n.tr("No news articles found.");
        }
    }

    ListModel {
        id: newsModel
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        spacing: Tokens.spacing.medium

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: I18n.tr("Arch Linux News")
                font: Tokens.font.title.medium
                color: root.cOnSurface
            }
            
            IconButton {
                icon: "refresh"
                onClicked: fetchNews()
            }
        }

        // Error message
        StyledText {
            Layout.fillWidth: true
            visible: root.errorMessage !== ""
            text: root.errorMessage
            color: root.cError
            wrapMode: Text.WordWrap
        }

        // Loading Indicator
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.isFetching && newsModel.count === 0

            StyledText {
                anchors.centerIn: parent
                text: I18n.tr("Fetching latest news...")
                color: root.cOnSurfaceVariant
            }
        }

        // List
        ListView {
            id: newsListView

            Layout.fillWidth: true
            Layout.fillHeight: true
            model: newsModel
            spacing: Tokens.spacing.small
            clip: true
            visible: !root.isFetching || newsModel.count > 0
            
            ScrollBar.vertical: StyledScrollBar { flickable: newsListView }

            delegate: StyledRect {
                id: delegateItem

                required property string title
                required property string link
                required property string date

                width: ListView.view.width
                implicitHeight: col.implicitHeight + Tokens.padding.medium * 2
                radius: Tokens.rounding.medium
                
                color: ma.containsMouse ? root.cBgHighest : root.cBgHigh

                MouseArea {
                    id: ma

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.openUrlExternally(delegateItem.link)
                }

                ColumnLayout {
                    id: col

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        Layout.fillWidth: true
                        text: delegateItem.title
                        font: Tokens.font.label.large
                        color: root.cOnSurface
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: delegateItem.date
                        font: Tokens.font.body.small
                        color: root.cOnSurfaceVariant
                    }
                }
            }
        }
    }
}
