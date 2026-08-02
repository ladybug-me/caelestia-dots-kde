import QtQuick
import QtCore
import Caelestia.Config

Item {
    id: root

    required property Item target
    property string vAnchor: "bottom" 
    property string hAnchor: "right"
    property real offsetScale: 0
    required property Item contentItem
    property real blurOffsetTop: 0
    property real blurOffsetBottom: 0
    property real blurOffsetLeft: 0
    property real blurOffsetRight: 0
    property bool isActive: target && target.visible && target.opacity > 0 && GlobalConfig.appearance.transparency.enabled && GlobalConfig.appearance.blur
    property Settings blurSettings: Settings {
        property int blurQuality: 20

        category: "Blur"
    }
    // The centered deformMatrix from the BlobRect (identity by default)
    // m11 = horizontal scale, m22 = vertical scale, applied around the center of the target
    property matrix4x4 deformMatrix
    property real animScale: 1 - offsetScale
    property real sTop: (vAnchor === "top" ? blurOffsetBottom : blurOffsetTop) * animScale
    property real sBottom: (vAnchor === "top" ? blurOffsetTop : blurOffsetBottom) * animScale
    property real sLeft: (hAnchor === "left" ? blurOffsetRight : blurOffsetLeft) * animScale
    property real sRight: (hAnchor === "left" ? blurOffsetLeft : blurOffsetRight) * animScale
    property real tX: {
        if (!target) return 0;
        let _ = target.x + target.width; // Dependency tracking
        return target.parent ? target.parent.mapToItem(contentItem, target.x, target.y).x : 0;
    }
    property real tY: {
        if (!target) return 0;
        let _ = target.y + target.height; // Dependency tracking
        return target.parent ? target.parent.mapToItem(contentItem, target.x, target.y).y : 0;
    }
    // Raw layout dimensions of the target
    property real tW: target ? target.width : 0
    property real tH: target ? target.height : 0
    // Deform scale factors from the jelly matrix (m11=horizontal, m22=vertical).
    // The centered deform matrix layout is: translate(cx,cy) * scale * translate(-cx,-cy),
    // so the translation components encode the offset to center; we read scale directly.
    property real dm11: deformMatrix.m11 > 0 ? deformMatrix.m11 : 1
    property real dm22: deformMatrix.m22 > 0 ? deformMatrix.m22 : 1
    // The translate-back component moves the origin, so the visual top-left shifts by (cx*(1-dm11), cy*(1-dm22))
    property real deformOffsetX: (tW / 2) * (1 - dm11)
    property real deformOffsetY: (tH / 2) * (1 - dm22)
    property real bX: tX + deformOffsetX + sLeft * dm11
    property real bY: tY + deformOffsetY + sTop * dm22
    property real bW: isActive ? Math.max(0, tW * dm11 - sLeft * dm11 - sRight * dm11) : 0
    property real bH: isActive ? Math.max(0, tH * dm22 - sTop * dm22 - sBottom * dm22) : 0
    property real r: isActive ? Tokens.rounding.extraLarge * animScale : 0
    property bool isIsland: GlobalConfig.appearance.islands
    property real rTop: (!isIsland && (vAnchor === "top" || vAnchor === "both")) ? 0 : r
    property real rBottom: (!isIsland && (vAnchor === "bottom" || vAnchor === "both")) ? 0 : r
    property real rLeft: (!isIsland && (hAnchor === "left" || hAnchor === "both")) ? 0 : r
    property real rRight: (!isIsland && (hAnchor === "right" || hAnchor === "both")) ? 0 : r
    property real inLeft: bX + rLeft
    property real inRight: bX + bW - rRight
    property real inTop: bY + rTop
    property real inBottom: bY + bH - rBottom
}
