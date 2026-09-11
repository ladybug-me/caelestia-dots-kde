import QtQuick
import Quickshell
import Quickshell.Bluetooth

QtObject {
    property ShellScreen screen
    property bool isWindow
    property bool animatingContainer
    property int currentPageIdx
    property list<int> subPageIdxStack
    property bool searchOpen
    property string searchQuery

    property string selectedWallpaperCategory
    property string wallpaperFilterType: "all"
    property BluetoothDevice selectedBtDevice
    property DesktopEntry selectedApp
    property int editingVpnIndex: -1
    property string selectedNetworkSsid
    property string selectedEthernetInterface
    property bool networkDetailsFromSaved

    // Pre-filled SSID for AddNetworkPage when password is needed for an unsaved network
    property string pendingNetworkSsid: ""

    // A sub-page to open as soon as the page it belongs to has been built.
    // Changing page and opening a sub-page of the new page cannot be done with
    // openSubPage: the swap is animated, so the outgoing page is still the one
    // listening and it either opens a sub-page of its own at that index or, if
    // it has none, cancels the request. The incoming page collects this.
    property int pendingSubPageIdx: -1

    signal close
    signal subPageOpened(idx: int)
    signal subPageClosed

    function openSubPage(idx: int): void {
        subPageIdxStack.push(idx);
        subPageOpened(idx);
    }

    // Navigation that changes page, such as a search result. Landing on the
    // page that is already showing still opens immediately: nothing to wait for.
    function goToSubPage(pageIdx: int, subPageIdx: int): void {
        if (pageIdx === currentPageIdx) {
            pendingSubPageIdx = -1;
            if (subPageIdx >= 0)
                openSubPage(subPageIdx);
            return;
        }
        currentPageIdx = pageIdx;
        // After the page change: changing page clears whatever was pending.
        pendingSubPageIdx = subPageIdx;
    }

    function closeSubPage(): void {
        subPageClosed();
        subPageIdxStack.pop();
    }

    onCurrentPageIdxChanged: {
        subPageIdxStack.length = 0;
        pendingSubPageIdx = -1;
    }
}
