pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.bar.components as BarComponents
import M3Shapes

StyledRect {
    id: root

    required property var popouts

    property string username: ""
    property var weekDays: []
    property int total: 0
    property string lastError: ""
    property int refreshInterval: 1800
    property color colour: Colours.palette.m3secondary
    readonly property int padding: Config.bar.github.background ? Tokens.padding.medium : Tokens.padding.small
    readonly property int cellSize: 12
    readonly property int cellSpacing: Tokens.spacing.small
    readonly property var displayDays: weekDays.length > 0 ? weekDays : [
        {
            color: Colours.layer(Colours.palette.m3outlineVariant, 2)
        },
        {
            color: Colours.layer(Colours.palette.m3outlineVariant, 2)
        },
        {
            color: Colours.layer(Colours.palette.m3outlineVariant, 2)
        },
        {
            color: Colours.layer(Colours.palette.m3outlineVariant, 2)
        },
        {
            color: Colours.layer(Colours.palette.m3outlineVariant, 2)
        },
        {
            color: Colours.layer(Colours.palette.m3outlineVariant, 2)
        },
        {
            color: root.lastError.length > 0 ? Colours.palette.m3error : Colours.layer(Colours.palette.m3outlineVariant, 2)
        }
    ]

    function redact(value: string): string {
        return (value || "").replace(/bearer\s+[A-Za-z0-9_\-.]+/gi, "bearer [redacted]");
    }

    function setUnavailable(message: string): void {
        const msg = root.redact(message);
        root.lastError = msg;
        BarComponents.GithubStore.lastError = msg;
        BarComponents.GithubStore.available = false;
        console.error("[GitHubWidget] " + msg);
    }

    readonly property bool isHorizontal: Config.bar.position === "top" || Config.bar.position === "bottom"

    implicitWidth: isHorizontal ? (cells.implicitWidth + root.padding * 2) : Tokens.sizes.bar.innerWidth
    implicitHeight: isHorizontal ? Tokens.sizes.bar.innerWidth : (cells.implicitHeight + root.padding * 2)

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, Config.bar.github.background ? Colours.tPalette.m3surfaceContainer.a : 0)
    radius: Tokens.rounding.full



    Grid {
        id: cells

        anchors.centerIn: parent
        spacing: root.cellSpacing
        columns: root.isHorizontal ? root.displayDays.length : 1
        rows: root.isHorizontal ? 1 : root.displayDays.length

        Repeater {
            model: root.displayDays

            delegate: MaterialShape {
                required property var modelData

                width: root.cellSize
                height: root.cellSize
                shape: MaterialShape.Square
                color: modelData.color || "#2f2f2f"
            }
        }

        /* Uncomment for total count beside the widget
        StyledText {
            id: text
            verticalAlignment: StyledText.AlignVCenter
            text: root.total
            font.pointSize: Appearance.font.size.smaller
            font.family: Appearance.font.family.mono
            color: root.colour
        }
        */
    }

    // Could do something with this in the future, nothing currently though to keep things decluttered
    // var counts root.lastError !== "" ? ("GitHub: " + root.lastError) : root.weekDays.map(d => `${d.date}: ${d.count}`).join("\n")

    Process {
        id: proc

        command: ["bash", "-c", `
        set -Eeuo pipefail
        export GITHUB_TOKEN="$(secret-tool lookup service caelestia-shell account github 2>/dev/null || echo '')"
        : "\${GITHUB_TOKEN:?Missing GITHUB_TOKEN}"

        # Resolve login via token if GITHUB_USERNAME is unset
        login="\${GITHUB_USERNAME-}"
        if [ -z "$login" ]; then
          vpayload="$(python - <<'PY'
import json; print(json.dumps({"query": "query{viewer{login}}"}))
PY
          )"
          tmpv="$(mktemp)"
          vcode="$(curl -sS -o "$tmpv" -w "%{http_code}" \
                     -H "Authorization: bearer $GITHUB_TOKEN" \
                     -H "Content-Type: application/json" \
                     -X POST https://api.github.com/graphql \
                     --data "$vpayload")"
          case "$vcode" in
            2??) : ;;
            *)   echo "viewer HTTP $vcode: $(head -c 200 "$tmpv")" >&2; rm -f "$tmpv"; exit 22 ;;
          esac
          login="$(python -c '
import json,sys
d=json.load(sys.stdin)
print(((d.get("data") or {}).get("viewer") or {}).get("login",""))
' <"$tmpv")"
          rm -f "$tmpv"
        fi
        [ -n "$login" ] || { echo "no login provided and token did not resolve viewer.login" >&2; exit 2; }

        today="$(date +%F)"
        from="$(date -d '6 days ago' +%F)"
        export LOGIN="$login" FROM="$from" TO="$today"

        payload="$(python - <<'PY'
import os, json
login = os.environ.get("LOGIN","")
start = os.environ.get("FROM","")
end   = os.environ.get("TO","")
query = ("query($login:String!, $from:DateTime!, $to:DateTime!)"
         "{ user(login:$login){ login contributionsCollection(from:$from, to:$to){"
         " contributionCalendar{ weeks{ contributionDays{ date color contributionCount } } } } } }")
print(json.dumps({"query": query,
                  "variables": {"login": login,
                                "from": f"{start}T00:00:00Z",
                                "to":   f"{end}T23:59:59Z"}}))
PY
        )"

        tmp="$(mktemp)"
        code="$(curl -sS -o "$tmp" -w "%{http_code}" \
                 -H "Authorization: bearer $GITHUB_TOKEN" \
                 -H "Content-Type: application/json" \
                 -X POST https://api.github.com/graphql \
                 --data "$payload")"
        case "$code" in
          2??) cat "$tmp" ;;
          *)   echo "http $code: $(head -c 200 "$tmp")" >&2; rm -f "$tmp"; exit 22 ;;
        esac
        rm -f "$tmp"
    `]

        stdout: StdioCollector {
            id: out
        }

        stderr: StdioCollector {
            id: err
        }

        onExited: code => { // qmllint disable signal-handler-parameters
            if (code !== 0) {
                root.setUnavailable(err.text || ("fetch failed (exit " + code + ")"));
                return;
            }

            const raw = out.text.trim();
            try {
                const obj = JSON.parse(raw);
                if (obj.errors) {
                    root.setUnavailable(obj.errors.map(e => e.message).join("; "));
                    return;
                }

                root.username = (obj.data && obj.data.user && obj.data.user.login) || root.username;

                const weeks = obj.data.user.contributionsCollection.contributionCalendar.weeks || [];
                const days = [];
                weeks.forEach(w => w.contributionDays.forEach(d => days.push({
                            date: d.date,
                            count: d.contributionCount
                        })));

                const now = new Date();
                now.setHours(0, 0, 0, 0);
                const start = new Date(now);
                start.setDate(now.getDate() - 6);

                function fmt(d) {
                    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
                }

                const dates = [];
                for (let i = 0; i < 7; i++) {
                    const t = new Date(start);
                    t.setDate(start.getDate() + i);
                    dates.push(fmt(t));
                }

                const byDate = {};
                days.forEach(d => byDate[d.date] = d);
                const window = dates.map(date => byDate[date] || {
                        date,
                        count: 0
                    });

                const palette = ["#161b22", "#0e4429", "#006d32", "#26a641", "#39d353"];
                let max = 1;
                for (let i = 0; i < window.length; i++) {
                    if (window[i].count > max)
                        max = window[i].count;
                }

                for (let i = 0; i < window.length; i++) {
                    const count = window[i].count;
                    const idx = count === 0 ? 0 : Math.min(4, 1 + Math.floor((count * 4) / max));
                    window[i] = {
                        date: window[i].date,
                        count,
                        color: palette[idx]
                    };
                }

                root.weekDays = window;
                root.total = window.reduce((a, b) => a + (b.count || 0), 0);
                root.lastError = "";

                BarComponents.GithubStore.days = window;
                BarComponents.GithubStore.total = root.total;
                BarComponents.GithubStore.username = root.username;
                BarComponents.GithubStore.lastError = "";
                BarComponents.GithubStore.available = true;
            } catch (e) {
                root.setUnavailable("parse error: " + e + " | first 200B: " + raw.slice(0, 200));
            }
        }
    }

    Timer {
        interval: root.refreshInterval * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: proc.exec(proc.command)
    }
}
