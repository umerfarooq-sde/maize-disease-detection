"""Windows Job/console regression tests using generated local-only processes."""

import importlib.util
import json
import os
import subprocess
import sys
import time
import unittest
from pathlib import Path
from uuid import uuid4

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("phone_service", ROOT / "scripts/phone-service.py")
service = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(service)


def wait_for(check, seconds=20):
    end = time.monotonic() + seconds
    while time.monotonic() < end:
        result = check()
        if result:
            return result
        time.sleep(0.1)
    raise AssertionError("Owned fixture did not reach expected state")


@unittest.skipUnless(os.name == "nt", "Windows console and Job Object tests")
class SupervisorTests(unittest.TestCase):
    def fixture(self, owner_started=None, ignore_signal=False, released_lock=False):
        directory = ROOT / ".cache/phone" / ("test-" + uuid4().hex)
        directory.mkdir(parents=True)
        marker = directory / "graceful.txt"
        child = directory / "child.py"
        child.write_text(
            "import signal,time,pathlib\n"
            + (
                "signal.signal(signal.SIGINT, signal.SIG_IGN)\n"
                if ignore_signal
                else f"def stop(*_):\n pathlib.Path({str(marker)!r}).write_text('graceful')\n"
                " raise SystemExit(0)\n"
                "signal.signal(signal.SIGINT, stop)\n"
            )
            + "print('fixture started', flush=True)\nwhile True: time.sleep(.1)\n",
            encoding="utf-8",
        )
        spec_path = directory / "fixture.json"
        config = {
            "session": uuid4().hex,
            "service": "generated-fixture",
            "argv": [sys.executable, str(child)],
            "cwd": str(ROOT),
            "ownerPid": os.getpid(),
            "ownerStarted": owner_started or service.creation_time(os.getpid()),
            "graceSeconds": 2,
            "drainSeconds": 0.5,
            "log": str(directory / "fixture.log"),
        }
        if released_lock:
            lock_path = directory / "released.lock"
            lock_path.touch()
            config["lockPath"] = str(lock_path)
        service.atomic_json(spec_path, config)
        supervisor = subprocess.Popen(
            [sys.executable, str(ROOT / "scripts/phone-service.py"), "--spec", str(spec_path)],
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
        self.addCleanup(lambda: supervisor.wait(timeout=15))

        def running():
            try:
                state = json.loads(spec_path.with_suffix(".state.json").read_text())
                return state if state.get("childPid") else None
            except (OSError, ValueError):
                return None

        state = wait_for(running)
        self.addCleanup(lambda: spec_path.with_suffix(".stop").touch())
        return spec_path, state, supervisor, marker

    def test_graceful_stop_and_no_pid_reuse(self):
        spec, state, worker, marker = self.fixture()
        wait_for(lambda: "fixture started" in spec.with_suffix(".log").read_text())
        self.assertFalse(service.same_process(state["childPid"], "1"))
        spec.with_suffix(".stop").touch()
        worker.wait(timeout=15)
        self.assertTrue(marker.exists(), "CTRL+C must reach only the generated child console")
        self.assertFalse(service.same_process(state["childPid"], state["childStarted"]))
        self.assertFalse(json.loads(spec.with_suffix(".state.json").read_text())["forced"])

    def test_owner_identity_change_stops_descendants(self):
        spec, state, worker, _ = self.fixture(owner_started="1")
        worker.wait(timeout=15)
        self.assertFalse(service.same_process(state["childPid"], state["childStarted"]))

    def test_unresponsive_child_bounded_job_cleanup(self):
        spec, state, worker, _ = self.fixture(ignore_signal=True)
        wait_for(lambda: "fixture started" in spec.with_suffix(".log").read_text())
        spec.with_suffix(".stop").touch()
        worker.wait(timeout=15)
        self.assertTrue(json.loads(spec.with_suffix(".state.json").read_text())["forced"])
        self.assertFalse(service.same_process(state["childPid"], state["childStarted"]))

    def test_released_root_lock_stops_tree_even_if_owner_process_lives(self):
        _spec, state, worker, _ = self.fixture(released_lock=True)
        worker.wait(timeout=15)
        self.assertTrue(service.same_process(os.getpid(), service.creation_time(os.getpid())))
        self.assertFalse(service.same_process(state["childPid"], state["childStarted"]))

    def test_restart_uses_new_session_and_does_not_reuse_old_stop_request(self):
        old_spec, old_state, old_worker, _ = self.fixture()
        old_spec.with_suffix(".stop").touch()
        old_worker.wait(timeout=15)
        new_spec, new_state, new_worker, _ = self.fixture()
        self.assertNotEqual(old_state["session"], new_state["session"])
        self.assertTrue(service.same_process(new_state["childPid"], new_state["childStarted"]))
        new_spec.with_suffix(".stop").touch()
        new_worker.wait(timeout=15)
        self.assertFalse(service.same_process(new_state["childPid"], new_state["childStarted"]))


if __name__ == "__main__":
    unittest.main(verbosity=2)
