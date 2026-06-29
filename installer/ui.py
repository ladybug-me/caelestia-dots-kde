from __future__ import annotations

import contextlib
import os
import sys

try:
    import msvcrt  # type: ignore
except ImportError:
    msvcrt = None

try:
    import termios
    import tty
except ImportError:
    termios = None
    tty = None


class UI:
    RST = "\033[0m"
    BOLD = "\033[1m"
    BLUE = "\033[38;5;75m"
    CYAN = "\033[38;5;87m"
    GREEN = "\033[38;5;84m"
    RED = "\033[38;5;196m"
    YELLOW = "\033[38;5;220m"
    DIM = "\033[2m"

    @staticmethod
    def separator(width: int = 53, color: str | None = None) -> None:
        color = color or UI.BLUE
        print(f"{color}{'-' * width}{UI.RST}")

    @staticmethod
    def section(title: str, subtitle: str = "", color: str | None = None) -> None:
        color = color or UI.BLUE
        print()
        UI.separator(color=color)
        if subtitle:
            print(f"{color}  {UI.BOLD}{title}{UI.RST} {UI.DIM}{subtitle}{UI.RST}")
        else:
            print(f"{color}  {UI.BOLD}{title}{UI.RST}")
        UI.separator(color=color)

    @staticmethod
    def info(msg: str) -> None:
        print(f"{UI.BLUE}[INFO]  {msg}{UI.RST}")

    @staticmethod
    def ok(msg: str) -> None:
        print(f"{UI.GREEN}[OK]    {msg}{UI.RST}")

    @staticmethod
    def warn(msg: str) -> None:
        print(f"{UI.YELLOW}[WARN]  {msg}{UI.RST}")

    @staticmethod
    def skip(msg: str) -> None:
        print(f"{UI.DIM}[SKIP]  {msg}{UI.RST}")

    @staticmethod
    def die(msg: str, code: int = 1) -> None:
        print(f"{UI.RED}[ERROR] {msg}{UI.RST}", file=sys.stderr)
        raise SystemExit(code)

    @staticmethod
    def prompt_yes_no(prompt: str, default: bool | None = None) -> bool:
        suffix = " [y/n]: "
        if default is True:
            suffix = " [Y/n]: "
        elif default is False:
            suffix = " [y/N]: "

        while True:
            raw = input(prompt + suffix).strip().lower()
            if not raw and default is not None:
                return default
            if raw in {"y", "yes"}:
                return True
            if raw in {"n", "no"}:
                return False
            UI.warn("Please enter y or n.")

    @staticmethod
    def clear_screen() -> None:
        if os.name == "nt":
            os.system("cls")
        else:
            print("\033[2J\033[H", end="")

    @staticmethod
    @contextlib.contextmanager
    def hidden_cursor() -> object:
        try:
            print("\033[?25l", end="", flush=True)
            yield
        finally:
            print("\033[?25h", end="", flush=True)

    @staticmethod
    def read_key() -> str:
        if msvcrt is not None:
            c = msvcrt.getwch()
            if c in ("\x00", "\xe0"):
                c2 = msvcrt.getwch()
                if c2 == "H":
                    return "UP"
                if c2 == "P":
                    return "DOWN"
                if c2 == "K":
                    return "LEFT"
                if c2 == "M":
                    return "RIGHT"
                return "OTHER"
            if c in ("\r", "\n"):
                return "ENTER"
            if c == "\t":
                return "TAB"
            if c == " ":
                return "SPACE"
            if c == "\x1b":
                return "ESC"
            return c.lower()

        if termios is None or tty is None or not sys.stdin.isatty():
            raw = input().strip().lower()
            return raw if raw else "ENTER"

        fd = sys.stdin.fileno()
        old = termios.tcgetattr(fd)
        try:
            tty.setraw(fd)
            c = sys.stdin.read(1)
            if c == "\x1b":
                seq = c + sys.stdin.read(1) + sys.stdin.read(1)
                if seq == "\x1b[A":
                    return "UP"
                if seq == "\x1b[B":
                    return "DOWN"
                if seq == "\x1b[C":
                    return "RIGHT"
                if seq == "\x1b[D":
                    return "LEFT"
                return "ESC"
            if c in ("\r", "\n"):
                return "ENTER"
            if c == "\t":
                return "TAB"
            if c == " ":
                return "SPACE"
            return c.lower()
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old)
