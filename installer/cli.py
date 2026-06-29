from __future__ import annotations

import signal

from .config import build_config
from .core import Installer
from .ui import UI


def main() -> int:
    cfg = build_config()
    installer = Installer(cfg)

    def handle_sigint(_signum: int, _frame: object) -> None:
        UI.die("Interrupted.", code=130)

    signal.signal(signal.SIGINT, handle_sigint)
    installer.run()
    return 0
