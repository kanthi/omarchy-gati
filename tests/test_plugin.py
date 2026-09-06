#!/usr/bin/env python3
"""Comprehensive unit, validation, and integration test suite for Gati focus timer."""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SEMVER_RE = re.compile(r"^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$")


class TestManifest(unittest.TestCase):
    def setUp(self) -> None:
        self.manifest_path = ROOT / "manifest.json"
        self.assertTrue(self.manifest_path.is_file(), "manifest.json must exist")
        with open(self.manifest_path, "r", encoding="utf-8") as f:
            self.manifest = json.load(f)

    def test_schema_version(self) -> None:
        self.assertEqual(self.manifest.get("schemaVersion"), 1)

    def test_required_fields(self) -> None:
        for field in ("id", "name", "version", "kinds", "entryPoints"):
            self.assertIn(field, self.manifest, f"Missing required manifest field '{field}'")
            self.assertTrue(self.manifest[field], f"Field '{field}' cannot be empty")

    def test_id_format(self) -> None:
        plugin_id = self.manifest["id"]
        self.assertEqual(plugin_id, "io.github.kanthi.gati")
        self.assertNotIn("/", plugin_id)
        self.assertNotIn("..", plugin_id)
        self.assertFalse(plugin_id.startswith("omarchy."))

    def test_version_semver(self) -> None:
        version = self.manifest["version"]
        self.assertRegex(version, SEMVER_RE, f"Version '{version}' is not valid SemVer")
        self.assertEqual(version, "0.0.9")

    def test_kinds_and_entry_points(self) -> None:
        self.assertEqual(self.manifest["kinds"], ["bar-widget"])
        entry_points = self.manifest.get("entryPoints", {})
        self.assertIn("barWidget", entry_points)
        entry_file = ROOT / entry_points["barWidget"]
        self.assertTrue(entry_file.is_file(), f"Entry point {entry_file} does not exist")

    def test_bar_widget_metadata(self) -> None:
        bw = self.manifest.get("barWidget", {})
        self.assertIn(bw.get("defaultSection"), {"left", "center", "right"})
        self.assertEqual(bw.get("defaultSection"), "right")
        self.assertFalse(bw.get("allowMultiple", True))

        defaults = bw.get("defaults", {})
        schema = bw.get("schema", [])
        self.assertIsInstance(defaults, dict)
        self.assertIsInstance(schema, list)

        schema_keys = {item.get("key"): item for item in schema if isinstance(item, dict)}
        for key in defaults:
            self.assertIn(key, schema_keys, f"Default key '{key}' must have a schema declaration")
            field_def = schema_keys[key]
            field_type = field_def.get("type")
            self.assertIn(
                field_type,
                {"boolean", "enum", "integer", "path", "string"},
                f"Invalid schema type '{field_type}' for key '{key}'",
            )


class TestRepositoryFiles(unittest.TestCase):
    def test_core_files_exist(self) -> None:
        core_files = [
            "BarWidget.qml",
            "BreakOverlay.qml",
            "Panel.qml",
            "Service.qml",
            "Model.js",
            "qmldir",
            "safe_state_io.py",
            "LICENSE",
            "README.md",
            "preview.png",
        ]
        for name in core_files:
            path = ROOT / name
            self.assertTrue(path.is_file(), f"Missing core file: {name}")

    def test_sound_assets_exist(self) -> None:
        sounds_dir = ROOT / "assets" / "sounds"
        self.assertTrue(sounds_dir.is_dir(), "assets/sounds must exist")
        expected_sounds = [
            "zen_bell.wav",
            "crystal_chime.wav",
            "marimba.wav",
            "tick.wav",
            "break_done.wav",
        ]
        for sound in expected_sounds:
            sound_path = sounds_dir / sound
            self.assertTrue(sound_path.is_file(), f"Missing audio asset: {sound}")
            self.assertGreater(sound_path.stat().st_size, 100, f"Audio file {sound} appears empty")

    def test_qmldir_singleton(self) -> None:
        qmldir = (ROOT / "qmldir").read_text(encoding="utf-8")
        self.assertIn("singleton Service Service.qml", qmldir)

    def test_preview_under_limits(self) -> None:
        preview = ROOT / "preview.png"
        self.assertTrue(preview.is_file(), "preview.png must exist")
        self.assertLess(preview.stat().st_size, 50 * 1024 * 1024, "preview.png exceeds 50 MB limit")


class TestSafeStateIo(unittest.TestCase):
    def setUp(self) -> None:
        self.script = ROOT / "safe_state_io.py"
        self.state_dir = Path.home() / ".local" / "state" / "omarchy" / "tests"
        self.state_dir.mkdir(parents=True, exist_ok=True)
        self.test_file = self.state_dir / "test_state.json"
        if self.test_file.exists():
            self.test_file.unlink()

    def tearDown(self) -> None:
        if self.test_file.exists():
            self.test_file.unlink()
        if self.state_dir.exists():
            shutil.rmtree(self.state_dir, ignore_errors=True)

    def test_write_and_read(self) -> None:
        payload = {
            "version": 1,
            "state": "work",
            "remainingSeconds": 1500,
            "running": False,
            "stats": {"todayFocusSeconds": 1500, "todayCompletedSessions": 1},
        }
        json_str = json.dumps(payload)

        # Write
        res_write = subprocess.run(
            [sys.executable, str(self.script), "write", str(self.test_file), json_str],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(res_write.returncode, 0, f"safe_state_io write failed: {res_write.stderr}")
        self.assertTrue(self.test_file.is_file())

        # Read
        res_read = subprocess.run(
            [sys.executable, str(self.script), "read", str(self.test_file)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(res_read.returncode, 0, f"safe_state_io read failed: {res_read.stderr}")
        read_payload = json.loads(res_read.stdout)
        self.assertEqual(read_payload["remainingSeconds"], 1500)
        self.assertEqual(read_payload["state"], "work")

    def test_symlink_rejection(self) -> None:
        target = self.state_dir / "real_file.json"
        target.write_text('{"ok": true}', encoding="utf-8")
        symlink = self.state_dir / "symlink.json"
        if symlink.exists():
            symlink.unlink()
        os.symlink(target, symlink)

        res = subprocess.run(
            [sys.executable, str(self.script), "read", str(symlink)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertNotEqual(res.returncode, 0, "safe_state_io must reject symlinks")

        if symlink.exists():
            symlink.unlink()
        if target.exists():
            target.unlink()

    def test_traversal_rejection(self) -> None:
        res = subprocess.run(
            [sys.executable, str(self.script), "write", "/etc/dangerous_state.json", '{"a": 1}'],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertNotEqual(res.returncode, 0, "safe_state_io must reject paths outside home/xdg_state")

    def test_invalid_json_rejection(self) -> None:
        res = subprocess.run(
            [sys.executable, str(self.script), "write", str(self.test_file), "{invalid_json"],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertNotEqual(res.returncode, 0, "safe_state_io must reject non-JSON payloads")


class TestModelJs(unittest.TestCase):
    def test_pure_logic_via_node(self) -> None:
        node = shutil.which("node")
        if not node:
            self.skipTest("node not installed, skipping JS evaluation")

        js_runner = f"""
        const fs = require('fs');
        const code = fs.readFileSync('{ROOT}/Model.js', 'utf8');
        eval(code);

        if (formatTime(1500) !== "25:00") throw new Error("formatTime(1500) failed");
        if (formatTime(0) !== "00:00") throw new Error("formatTime(0) failed");
        if (formatTime(65) !== "01:05") throw new Error("formatTime(65) failed");
        if (formatHoursDecimal(3600) !== "1.0h") throw new Error("formatHoursDecimal failed");
        if (formatHoursDecimal(5400) !== "1.5h") throw new Error("formatHoursDecimal failed");
        if (stateLabel(STATE_WORK) !== "Focus") throw new Error("stateLabel failed");
        if (typeof gatiWaveEnvelope(0.5) !== "number") throw new Error("gatiWaveEnvelope failed");
        if (last28DaysIso().length !== 28) throw new Error("last28DaysIso failed");
        console.log("ALL_JS_TESTS_PASSED");
        """
        res = subprocess.run(
            [node, "-e", js_runner],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(res.returncode, 0, f"Model.js tests failed: {res.stderr}")
        self.assertIn("ALL_JS_TESTS_PASSED", res.stdout)


class TestOmarchyIntegration(unittest.TestCase):
    def test_omarchy_plugin_validate(self) -> None:
        omarchy = shutil.which("omarchy")
        if not omarchy:
            self.skipTest("omarchy CLI not available")
        res = subprocess.run(
            [omarchy, "plugin", "validate", str(ROOT)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(res.returncode, 0, f"omarchy plugin validate failed: {res.stderr}")

    def test_ipc_endpoints(self) -> None:
        omarchy_shell = shutil.which("omarchy-shell")
        if not omarchy_shell:
            self.skipTest("omarchy-shell CLI not available")

        # Test status
        res = subprocess.run(
            [omarchy_shell, "io.github.kanthi.gati", "status"],
            capture_output=True,
            text=True,
            check=False,
        )
        if res.returncode != 0 and "Target not found" in res.stderr:
            self.skipTest("Gati plugin not loaded in running shell")

        self.assertEqual(res.returncode, 0, f"IPC status failed: {res.stderr}")
        self.assertTrue(len(res.stdout.strip()) > 0)

        # Test statusJson
        res_json = subprocess.run(
            [omarchy_shell, "io.github.kanthi.gati", "statusJson"],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(res_json.returncode, 0, f"IPC statusJson failed: {res_json.stderr}")
        status_data = json.loads(res_json.stdout.strip())
        self.assertIn("state", status_data)
        self.assertIn("remainingSeconds", status_data)


if __name__ == "__main__":
    unittest.main(verbosity=2)
