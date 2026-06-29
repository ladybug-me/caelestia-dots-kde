from __future__ import annotations

import signal

from .config import build_config
from .ui import UI
from .uninstall_core import Uninstaller


def main() -> int:
    cfg = build_config()
    uninstaller = Uninstaller(cfg)

    def handle_sigint(_signum: int, _frame: object) -> None:
        UI.die("Interrupted.", code=130)

    signal.signal(signal.SIGINT, handle_sigint)
    uninstaller.run()
    return 0
