import QtQuick
import QtQuick.Layouts
import qs.modules.dashboard
import qs.modules.nexus.common
import qs.services

PageBase {
    title: I18n.tr("Wallhaven")
    isSubPage: true
    scrollable: false

    WallhavenTab {
        anchors.fill: parent
    }
}
