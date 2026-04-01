"""Drive enumeration and disk usage for Sentinel."""

import ctypes
import shutil
from ctypes import wintypes
from pathlib import Path


def get_available_drives() -> list[str]:
    """
    Return a list of available Windows drive roots (e.g. ["C:\\", "G:\\"]).
    Iterates A–Z and checks Path(f"{d}:\\").exists().
    """
    drives = []
    for letter in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
        root = Path(f"{letter}:\\")
        if root.exists():
            drives.append(str(root))
    return drives


def get_drive_usage(path: str) -> tuple[int, int]:
    """
    Return (total_bytes, free_bytes) for the given path.
    Uses shutil.disk_usage.
    """
    usage = shutil.disk_usage(path)
    return usage.total, usage.free


def _normalize_drive_root(path: str) -> str:
    """Normalize drive root to Windows mount-point style (e.g. 'H:\\')."""
    root = str(path).strip().replace("/", "\\")
    if len(root) == 2 and root[1] == ":":
        root += "\\"
    if not root.endswith("\\"):
        root += "\\"
    return root


def _sanitize_identity(text: str) -> str:
    """Keep identity safe for filename usage."""
    safe = "".join(ch if ch.isalnum() else "_" for ch in text)
    return safe.strip("_") or "unknown"


def _get_volume_guid(drive_root: str) -> str | None:
    """Return volume GUID for mount point (without wrapper), or None."""
    buffer = ctypes.create_unicode_buffer(128)
    ok = ctypes.windll.kernel32.GetVolumeNameForVolumeMountPointW(
        ctypes.c_wchar_p(drive_root),
        buffer,
        len(buffer),
    )
    if not ok:
        return None
    raw = buffer.value.strip()
    prefix = "\\\\?\\Volume{"
    suffix = "}\\"
    if raw.startswith(prefix) and raw.endswith(suffix):
        return raw[len(prefix) : -len(suffix)]
    return raw.strip("\\") or None


def _get_volume_serial(drive_root: str) -> int | None:
    """Return volume serial number, or None if unavailable."""
    serial = wintypes.DWORD()
    ok = ctypes.windll.kernel32.GetVolumeInformationW(
        ctypes.c_wchar_p(drive_root),
        None,
        0,
        ctypes.byref(serial),
        None,
        None,
        None,
        0,
    )
    if not ok:
        return None
    return int(serial.value)


def get_drive_identity(path: str) -> str:
    """
    Return stable identity for a mounted drive.
    Prefers volume GUID; falls back to serial; finally to drive letter.
    """
    root = _normalize_drive_root(path)
    guid = _get_volume_guid(root)
    if guid:
        return f"guid_{_sanitize_identity(guid.lower())}"
    serial = _get_volume_serial(root)
    if serial is not None:
        return f"serial_{serial:08x}"
    letter = root.replace("\\", "").replace(":", "").upper() or "UNKNOWN"
    return f"letter_{letter}"
