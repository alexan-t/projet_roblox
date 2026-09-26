"""Tests hors réseau, sans session Claude et sans assets Studio."""
import copy
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("bridge", Path(__file__).parents[1] / "cloud_review_bridge.py")
b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)


class BridgeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name) / "worker"
        self.root.mkdir()
        for rel in ("CLAUDE.md", "docs/ART_DIRECTION.md", "docs/VISUAL_QA.md", "docs/MONSTER_PRODUCTION.md", "docs/brief.md"):
            path = self.root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("Document de test\n", encoding="utf-8")
        b.write_json(self.root / "automation/control.json", {"paused": False, "emergency_stop": False})
        b.write_json(self.root / "automation/review.schema.json", {})
        shots = []
        for angle in ("main", "compare"):
            rel = f"automation/screenshots/monster_001/iteration_00_{angle}.png"
            path = self.root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"\x89PNG\r\n\x1a\n" + angle.encode())
            shots.append(rel)
        self.task = {"id": "monster_001", "brief_source": "docs/brief.md", "iteration": 0,
                     "max_iterations": 3, "status": "awaiting_review", "screenshots": shots, "latest_review": None}
        b.write_json(self.root / "automation/tasks.json", {"schema_version": 1, "queue": [self.task]})
        b.write_json(self.root / "automation/state/monster_001.json", {"task_id": "monster_001", "iteration": 0,
                     "status": "awaiting_review", "studio_model": "Workspace.ExistingMonster"})
        self.config = {"remote": "origin", "branch": "feature/monster-pipeline", "review_branch": "claude/qa-test",
                       "session_id": "session_test", "claude_command": sys.executable, "poll_seconds": 1}
        self.bridge = b.Bridge(self.root, self.config)
        self.request = b.make_request(self.root, self.task)
        self.review = {"request_id": self.request["request_id"], "task_id": "monster_001", "iteration": 0,
                       "verdict": "PASS", "summary": "Conforme aux références.", "visible_issues": [],
                       "required_changes": [], "references_checked": ["KingTreant"], "confidence": "high", "human_attention": []}
        self.rel = f"automation/reviews/monster_001_iteration_00_{self.request['request_id']}.json"

    def tearDown(self):
        self.tmp.cleanup()

    def test_pass_preserves_model(self):
        self.bridge.apply("monster_001", self.request, self.review, self.rel)
        self.assertEqual(b.read_json(self.root / "automation/tasks.json")["queue"][0]["status"], "done")
        self.assertEqual(b.read_json(self.root / "automation/state/monster_001.json")["studio_model"], "Workspace.ExistingMonster")

    def test_fix_and_iteration_limit(self):
        self.review.update(verdict="FIX", visible_issues=["Arme masquée"], required_changes=["Décaler l'arme"])
        self.bridge.apply("monster_001", self.request, self.review, self.rel)
        self.assertEqual(b.read_json(self.root / "automation/tasks.json")["queue"][0]["status"], "fix_required")
        self.task["max_iterations"] = 0
        b.write_json(self.root / "automation/tasks.json", {"queue": [self.task]})
        request = b.make_request(self.root, self.task)
        self.review["request_id"] = request["request_id"]
        self.bridge.apply("monster_001", request, self.review, self.rel)
        self.assertEqual(b.read_json(self.root / "automation/tasks.json")["queue"][0]["status"], "human_review")

    def test_low_confidence_requires_human(self):
        self.review["confidence"] = "low"
        self.bridge.apply("monster_001", self.request, self.review, self.rel)
        self.assertEqual(b.read_json(self.root / "automation/tasks.json")["queue"][0]["status"], "human_review")

    def test_rejects_stale_or_invalid_reviews(self):
        for change in ({"request_id": "old"}, {"iteration": True}, {"task_id": "other"},
                       {"required_changes": ["Corriger ceci"]}, {"verdict": "FIX"}, {"references_checked": []}):
            with self.subTest(change=change), self.assertRaises(b.BridgeError):
                b.validate_review({**self.review, **change}, self.request)

    def test_changed_capture_rejects_review_without_writing(self):
        (self.root / self.task["screenshots"][0]).write_bytes(b"\x89PNG\r\n\x1a\nchanged")
        with self.assertRaises(b.BridgeError):
            self.bridge.apply("monster_001", self.request, self.review, self.rel)
        self.assertFalse((self.root / self.rel).exists())

    def test_stop_and_pause_prevent_execution(self):
        (self.root / "automation/STOP").touch()
        with patch.object(subprocess, "run") as run, self.assertRaises(b.Paused):
            self.bridge.git("status")
        run.assert_not_called()
        (self.root / "automation/STOP").unlink()
        for control in ({"paused": True, "emergency_stop": False}, {"paused": False, "emergency_stop": True}):
            b.write_json(self.root / "automation/control.json", control)
            with self.assertRaises(b.Paused):
                self.bridge.apply("monster_001", self.request, self.review, self.rel)

    def test_invalid_control_stops(self):
        b.write_json(self.root / "automation/control.json", {"paused": "false", "emergency_stop": False})
        with self.assertRaises(b.BridgeError):
            b.guard(self.root)

    def test_paths_and_missing_captures(self):
        for rel in ("../outside", "C:/outside", "automation/../../outside", "/outside", "automation\\outside"):
            with self.subTest(rel=rel), self.assertRaises(b.BridgeError):
                b.safe_path(self.root, rel)
        (self.root / self.task["screenshots"][1]).unlink()
        with self.assertRaises(b.BridgeError):
            b.make_request(self.root, self.task)

    def test_crlf_does_not_change_request_id(self):
        (self.root / "docs/brief.md").write_bytes(b"Document de test\r\n")
        self.assertEqual(b.make_request(self.root, self.task), self.request)

    def test_delivery_receipt_prevents_duplicates(self):
        receipt = self.root / "automation/.local/receipt.json"
        b.write_json(receipt, {"status": "delivery_unknown"})
        with patch.object(self.bridge, "run") as run:
            self.bridge.send(self.request, "manifest", "source", receipt)
            run.assert_not_called()

    @unittest.skipUnless(shutil.which("git"), "Git requis")
    def test_git_transport_and_scoped_commit(self):
        def git(*args, cwd=None):
            return subprocess.run(["git", *args], cwd=cwd or self.root, capture_output=True, text=True, check=True).stdout.strip()
        git("init", "-b", self.config["branch"])
        git("config", "user.name", "Pipeline Test")
        git("config", "user.email", "pipeline@example.invalid")
        git("config", "core.autocrlf", "false")
        git("add", ".")
        git("commit", "-m", "fixture")
        bare = Path(self.tmp.name) / "remote.git"
        git("init", "--bare", str(bare))
        git("remote", "add", "origin", str(bare))
        git("push", "origin", "HEAD")
        (self.root / "unrelated.txt").write_text("ne pas publier")
        reqrel = "automation/requests/request.json"
        b.write_json(self.root / reqrel, self.request)
        self.bridge.publish([reqrel], "chore(automation): request test")
        self.assertEqual(git("show", "--pretty=", "--name-only", "HEAD"), reqrel)
        self.assertIsNone(self.bridge.fetch_review(self.rel))
        manager = Path(self.tmp.name) / "manager"
        git("clone", "--branch", self.config["branch"], str(bare), str(manager))
        git("config", "user.name", "Manager Test", cwd=manager)
        git("config", "user.email", "manager@example.invalid", cwd=manager)
        git("checkout", "-b", self.config["review_branch"], cwd=manager)
        b.write_json(manager / self.rel, self.review)
        (manager / "untrusted-change.txt").write_text("must not merge")
        git("add", ".", cwd=manager)
        git("commit", "-m", "review fixture", cwd=manager)
        git("push", "origin", "HEAD", cwd=manager)
        self.assertEqual(self.bridge.fetch_review(self.rel), self.review)
        self.assertFalse((self.root / "untrusted-change.txt").exists())
        # Une review existante doit être utilisée sans requête Cloud.
        with patch.object(self.bridge, "send", side_effect=AssertionError("double envoi")):
            self.bridge.process()
        self.assertEqual(b.read_json(self.root / "automation/tasks.json")["queue"][0]["status"], "done")

    def test_concurrent_bridge_lock(self):
        with b.lock(self.root):
            with self.assertRaises(b.BridgeError):
                with b.lock(self.root):
                    pass
        with b.lock(self.root):
            pass


if __name__ == "__main__":
    unittest.main()
