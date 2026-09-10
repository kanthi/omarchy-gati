#!/usr/bin/env python3
"""Safe I/O helper for Gati timer state persistence.

Enforces security and persistence boundaries:
- Constrains path strictly within user's XDG_STATE_HOME or HOME directory.
- Rejects symlinks, FIFOs, sockets, device nodes, and non-regular files.
- Opens with O_NOFOLLOW | O_NONBLOCK.
- Verifies file and parent directory ownership (must match current UID).
- Caps reads and writes to MAX_BYTES (64 KiB) to prevent memory or buffer exhaustion.
- Atomically replaces files via fsync'd 0600 temporary files in the same directory.
"""

from __future__ import annotations

import json
import os
import stat
import sys
import tempfile

MAX_BYTES = 64 * 1024  # 64 KiB cap


def die(code: int, message: str) -> None:
    print(f"safe_state_io error: {message}", file=sys.stderr)
    raise SystemExit(code)


def get_allowed_base_dirs() -> list[str]:
    bases: list[str] = []
    xdg_state = os.environ.get("XDG_STATE_HOME")
    if xdg_state:
        bases.append(os.path.realpath(os.path.abspath(xdg_state)))
    home = os.environ.get("HOME")
    if not home:
        home = os.path.expanduser("~")
    if home:
        real_home = os.path.realpath(os.path.abspath(home))
        bases.append(real_home)
        bases.append(os.path.join(real_home, ".local", "state"))
    return bases


def validate_path(path_str: str) -> str:
    if not path_str or not isinstance(path_str, str):
        die(10, "empty path")

    abs_path = os.path.abspath(os.path.expanduser(path_str))
    allowed_bases = get_allowed_base_dirs()

    is_under_allowed = False
    for base in allowed_bases:
        if abs_path == base or abs_path.startswith(base + os.sep):
            is_under_allowed = True
            break

    if not is_under_allowed:
        die(11, f"path '{abs_path}' outside allowed directories")

    parent = os.path.dirname(abs_path)
    if not os.path.exists(parent):
        try:
            os.makedirs(parent, mode=0o700, exist_ok=True)
        except OSError as exc:
            die(12, f"failed to create parent dir: {exc}")

    try:
        parent_st = os.lstat(parent)
    except OSError as exc:
        die(13, f"cannot stat parent dir: {exc}")

    if stat.S_ISLNK(parent_st.st_mode):
        die(14, "parent directory is a symlink")
    if not stat.S_ISDIR(parent_st.st_mode):
        die(15, "parent path is not a directory")
    if parent_st.st_uid != os.getuid():
        die(16, "parent directory not owned by current user")

    return abs_path


def cmd_read(path_str: str) -> None:
    path = validate_path(path_str)
    if not os.path.lexists(path):
        return

    try:
        flags = os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK
        fd = os.open(path, flags)
    except OSError as exc:
        die(20, f"cannot open path: {exc}")

    try:
        st = os.fstat(fd)
        if stat.S_ISLNK(st.st_mode):
            die(21, "symlink rejected")
        if not stat.S_ISREG(st.st_mode):
            die(22, "not a regular file")
        if st.st_uid != os.getuid():
            die(23, "not owned by current user")
        if st.st_size > MAX_BYTES:
            die(24, "file size exceeds maximum byte cap")

        data = b""
        while len(data) <= MAX_BYTES:
            chunk = os.read(fd, min(8192, MAX_BYTES + 1 - len(data)))
            if not chunk:
                break
            data += chunk

        if len(data) > MAX_BYTES:
            die(25, "read content exceeded maximum byte cap")

        if data:
            try:
                json.loads(data.decode("utf-8"))
            except Exception as exc:
                die(26, f"invalid JSON content: {exc}")

        sys.stdout.buffer.write(data)
    finally:
        os.close(fd)


def cmd_write(path_str: str, payload_bytes: bytes) -> None:
    path = validate_path(path_str)

    if len(payload_bytes) > MAX_BYTES:
        die(30, "payload exceeds maximum byte cap")

    try:
        json.loads(payload_bytes.decode("utf-8"))
    except Exception as exc:
        die(31, f"invalid JSON payload: {exc}")

    if os.path.exists(path) or os.path.lexists(path):
        try:
            lst = os.lstat(path)
            if stat.S_ISLNK(lst.st_mode):
                die(32, "target path is a symlink")
            if not stat.S_ISREG(lst.st_mode):
                die(33, "target path is not a regular file")
            if lst.st_uid != os.getuid():
                die(34, "target file not owned by current user")
        except OSError as exc:
            die(35, f"cannot stat existing target: {exc}")

    parent = os.path.dirname(path)
    fd, tmp_path = tempfile.mkstemp(prefix=".gati-", suffix=".tmp", dir=parent)
    try:
        os.chmod(tmp_path, 0o600)
        os.write(fd, payload_bytes)
        os.fsync(fd)
        os.close(fd)
        fd = -1
        os.replace(tmp_path, path)
        tmp_path = None
        try:
            dir_fd = os.open(parent, os.O_RDONLY | os.O_DIRECTORY)
            try:
                os.fsync(dir_fd)
            finally:
                os.close(dir_fd)
        except OSError:
            pass
    finally:
        if fd >= 0:
            try:
                os.close(fd)
            except OSError:
                pass
        if tmp_path is not None and os.path.exists(tmp_path):
            try:
                os.unlink(tmp_path)
            except OSError:
                pass


def main(argv: list[str]) -> None:
    if len(argv) < 3:
        die(1, "usage: safe_state_io.py read|write <path>  (write payload on stdin)")

    action, path = argv[1], argv[2]
    if action == "read":
        cmd_read(path)
    elif action == "write":
        if len(argv) >= 4:
            die(3, "write payload must be supplied on stdin, not argv")
        payload = sys.stdin.buffer.read(MAX_BYTES + 1)
        cmd_write(path, payload)
    else:
        die(2, f"unknown action: {action}")


if __name__ == "__main__":
    main(sys.argv)
