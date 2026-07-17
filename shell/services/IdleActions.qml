pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    function isSuspendIdleAction(action: var): bool {
        if (!action)
            return false;

        if (typeof action === "string") {
            const normalized = action.trim().toLowerCase();
            return normalized === "suspendthenhibernate" || normalized === "suspend" || normalized === "suspend-then-hibernate" || normalized === "systemctl suspend" || normalized === "systemctl suspend-then-hibernate";
        }

        const isArrayLike = action instanceof Array || (typeof action === "object" && action.length !== undefined);
        if (isArrayLike) {
            for (const a of action) {
                if (root.isSuspendIdleAction(a))
                    return true;
            }
        }

        return false;
    }
}