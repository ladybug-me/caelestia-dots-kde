pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Caelestia
import Caelestia.Config
import qs.utils

Singleton {
    id: root

    readonly property string apiBase: "https://wallhaven.cc/api/v1"

    // User-configurable API key (NSFW content requires this)
    property string apiKey: GlobalConfig.services.wallhavenApiKey ?? ""

    // Search state
    property bool loading: false
    property string lastQuery: ""
    property int currentPage: 1
    property int lastPage: 1
    property string lastSeed: ""
    property list<var> results
    property var currentWallpaper: null

    // Filters
    property var filters: {
        "categories": "111",
        "purity": "100",
        "sorting": "relevance",
        "order": "desc",
        "topRange": "1M",
        "atleast": "",
        "resolutions": "",
        "ratios": "",
        "colors": ""
    }

    signal searchComplete(var results, var meta)
    signal downloadProgress(string id, real progress)
    signal downloadComplete(string id, string path)
    signal downloadFailed(string id, string error)

    function buildUrl(path: string, params: var): string {
        let url = apiBase + path + "?";
        const paramList = [];

        for (const key in params) {
            if (params[key]) {
                paramList.push(`${key}=${encodeURIComponent(params[key])}`);
            }
        }

        if (apiKey) {
            paramList.push(`apikey=${apiKey}`);
        }

        return url + paramList.join("&");
    }

    function search(query: string, page: int): void {
        if (!query || query.trim() === "")
            return;

        if (!page || page < 1)
            page = 1;

        loading = true;
        lastQuery = query;
        currentPage = page;

        const params = {
            "q": query,
            "categories": filters.categories,
            "purity": filters.purity,
            "sorting": filters.sorting,
            "order": filters.order,
            "page": page.toString()
        };

        if (filters.atleast)
            params.atleast = filters.atleast;
        if (filters.resolutions)
            params.resolutions = filters.resolutions;
        if (filters.ratios)
            params.ratios = filters.ratios;
        if (filters.colors)
            params.colors = filters.colors;

        const url = buildUrl("/search", params);
        console.log("Wallhaven search:", url);

        Requests.get(url, text => {
            try {
                const json = JSON.parse(text);
                results = json.data || [];

                if (json.meta) {
                    lastPage = json.meta.last_page || 1;
                    lastSeed = json.meta.seed || "";
                }

                loading = false;
                searchComplete(results, json.meta || {});
            } catch (e) {
                loading = false;
                console.error("Wallhaven parse error:", e);
                searchComplete([], {});
            }
        });
    }

    function searchRandom(query: string): void {
        if (!query || query.trim() === "")
            return;

        loading = true;
        lastQuery = query;
        currentPage = 1;

        const params = {
            "q": query,
            "categories": filters.categories,
            "purity": filters.purity,
            "sorting": "random",
            "page": "1"
        };

        const url = buildUrl("/search", params);
        console.log("Wallhaven random:", url);

        Requests.get(url, text => {
            try {
                const json = JSON.parse(text);
                results = json.data || [];

                if (json.meta) {
                    lastPage = json.meta.last_page || 1;
                    lastSeed = json.meta.seed || "";
                }

                loading = false;
                searchComplete(results, json.meta || {});
            } catch (e) {
                loading = false;
                console.error("Wallhaven random parse error:", e);
                searchComplete([], {});
            }
        });
    }

    function searchNextPage(): void {
        if (currentPage < lastPage && lastQuery) {
            if (filters.sorting === "random" && lastSeed) {
                currentPage++;
                const params = {
                    "q": lastQuery,
                    "categories": filters.categories,
                    "purity": filters.purity,
                    "sorting": "random",
                    "seed": lastSeed,
                    "page": currentPage.toString()
                };
                const url = buildUrl("/search", params);
                loadPage(url);
            } else {
                search(lastQuery, currentPage + 1);
            }
        }
    }

    function loadPage(url: string): void {
        Requests.get(url, text => {
            try {
                const json = JSON.parse(text);
                results = json.data || [];
                if (json.meta) {
                    lastPage = json.meta.last_page || 1;
                    lastSeed = json.meta.seed || "";
                }
                loading = false;
                searchComplete(results, json.meta || {});
            } catch (e) {
                loading = false;
                console.error("Wallhaven page load error:", e);
                searchComplete([], {});
            }
        });
    }

    function setFilter(key: string, value: string): void {
        const newFilters = {
            "categories": filters.categories,
            "purity": filters.purity,
            "sorting": filters.sorting,
            "order": filters.order,
            "topRange": filters.topRange,
            "atleast": filters.atleast,
            "resolutions": filters.resolutions,
            "ratios": filters.ratios,
            "colors": filters.colors
        };
        newFilters[key] = value;
        filters = newFilters;
    }

    function setPurity(sfw: bool, sketchy: bool, nsfw: bool): void {
        if (!apiKey && (nsfw || sketchy)) {
            console.warn("Wallhaven: Sketchy/NSFW requires API key");
        }
        let p = (sfw ? "1" : "0") + (sketchy ? "1" : "0") + (nsfw && apiKey ? "1" : "0");
        setFilter("purity", p);
    }

    function setResolution(width: int, height: int): void {
        if (width > 0 && height > 0) {
            setFilter("atleast", `${width}x${height}`);
        } else {
            setFilter("atleast", "");
        }
    }

    function setSorting(sorting: string): void {
        setFilter("sorting", sorting);
    }

    function resetFilters(): void {
        filters = {
            "categories": "111",
            "purity": apiKey ? "110" : "100",
            "sorting": "relevance",
            "order": "desc",
            "topRange": "1M",
            "atleast": "",
            "resolutions": "",
            "ratios": "",
            "colors": ""
        };
    }

    function downloadWallpaper(wallpaper: var): void {
        if (!wallpaper || !wallpaper.path) {
            console.error("Wallhaven: Invalid wallpaper data");
            return;
        }

        // Extract extension from file path or URL, default to jpg
        const fullPath = wallpaper.path || wallpaper.url || "";
        const urlMatch = fullPath.match(/\.([a-zA-Z]{3,4})(?:\?|$)/);
        let ext = urlMatch ? urlMatch[1] : "";
        // Normalize to lowercase and handle jpeg -> jpg
        if (ext) {
            ext = ext.toLowerCase();
            if (ext === "jpeg")
                ext = "jpg";
        } else {
            ext = "jpg";
        }

        const tmpPath = `${Paths.cache}/wallhaven-${wallpaper.id}.tmp`;
        const dstPath = `${Paths.wallsdir}/wallhaven-${wallpaper.id}.${ext}`;

        currentWallpaper = {
            id: wallpaper.id,
            ext: ext
        };
        downloadProc.wallpaperId = wallpaper.id;
        downloadProc.tmpPath = tmpPath;
        downloadProc.dstPath = dstPath;

        console.log("Wallhaven: Downloading", wallpaper.path, "to", tmpPath);
        console.log("Wallhaven: Will move to", dstPath, "(ext:", ext, ")");

        downloadProc.command = ["sh", "-c", "curl -L -s -o '" + tmpPath + "' '" + wallpaper.path + "'"];
        downloadProc.running = true;
    }

    IpcHandler {
        function doSearch(query: string): void {
            search(query);
        }

        function doRandom(query: string): void {
            searchRandom(query);
        }

        target: "wallhaven"
    }

    Process {
        id: downloadProc

        property string wallpaperId: ""
        property string tmpPath: ""
        property string dstPath: ""

        // qmllint disable signal-handler-parameters
        onExited: code => {
            if (code !== 0) {
                downloadFailed(wallpaperId, "Download failed: " + code);
                return;
            }
            if (currentWallpaper) {
                const src = downloadProc.tmpPath;
                const dst = downloadProc.dstPath;
                console.log("Wallhaven: Download complete, moving to", dst);
                moveProc.source = src;
                moveProc.destination = dst;
                moveProc.command = ["sh", "-c", "test -f '" + src + "' && mv '" + src + "' '" + dst + "'"];
                moveProc.running = true;
            }
            currentWallpaper = null;
        }
    }

    Process {
        id: moveProc

        property string source: ""
        property string destination: ""

        // qmllint disable signal-handler-parameters
        onExited: code => {
            const id = downloadProc.wallpaperId;
            const dst = downloadProc.dstPath;
            console.log("Wallhaven: moveProc exited with code", code);
            if (code === 0) {
                downloadComplete(id, dst);
            } else {
                downloadFailed(id, "Failed to save wallpaper (exit " + code + ")");
            }
        }
    }
}
