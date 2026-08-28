import QtQuick

QtObject {
    id: root

    function register(name, description, key, callback) {
        let qml = `
            import QtQuick
            import qs.components.misc

            CustomShortcut {
                name: "${name}"
                description: "${description}"
                key: "${key}"
            }
        `;
        let shortcut = Qt.createQmlObject(qml, root, "dynamicShortcut_" + name);
        if (shortcut && callback) {
            shortcut.pressed.connect(callback);
        }
        return shortcut;
    }
}
