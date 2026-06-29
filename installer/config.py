from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


@dataclass
class InstallerConfig:
    bundle_dir: Path
    scripts_dir: Path
    cache_dir: Path
    builddir: Path
    pkgdest: Path
    srcdest: Path
    srcpkgdest: Path
    failed_steps_file: Path
    failed_packages_file: Path
    failed_patches_file: Path

    base_distro: str = "unknown"
    confirm_arg: str = "--noconfirm"

    polonium_enabled: bool = False
    remove_cache: bool = True
    apply_darkly: bool = True
    apply_material_you: bool = True
    apply_fonts: bool = True


def build_config(bundle_dir: Path | None = None) -> InstallerConfig:
    if bundle_dir is None:
        bundle_dir = Path(__file__).resolve().parent.parent

    cache_dir = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "caelestia-kde"
    return InstallerConfig(
        bundle_dir=bundle_dir,
        scripts_dir=bundle_dir / "scripts",
        cache_dir=cache_dir,
        builddir=cache_dir / "makepkg-build",
        pkgdest=cache_dir / "makepkg-packages",
        srcdest=cache_dir / "makepkg-sources",
        srcpkgdest=cache_dir / "makepkg-srcpackages",
        failed_steps_file=cache_dir / "failed_steps.txt",
        failed_packages_file=cache_dir / "failed_packages.txt",
        failed_patches_file=cache_dir / "failed_patches.txt",
    )
