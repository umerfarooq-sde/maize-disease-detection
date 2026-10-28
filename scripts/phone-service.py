"""Windows-only owned service supervisor; no shell, no remote shutdown API.

An exclusive Job Object owns the supervisor and its descendants. A new hidden
console lets CTRL+C reach just that service tree. On graceful timeout or owner
death the job closes: no unrelated process can be terminated through a stale PID.
Only non-secret argv/cwd and lifecycle records are stored in the ignored cache.
"""

import argparse
import base64
import ctypes
import json
import os
import subprocess
import sys
import time
from contextlib import suppress
from ctypes import wintypes
from pathlib import Path


class IO_COUNTERS(ctypes.Structure):
    _fields_ = [
        (name, ctypes.c_ulonglong)
        for name in (
            "ReadOperationCount",
            "WriteOperationCount",
            "OtherOperationCount",
            "ReadTransferCount",
            "WriteTransferCount",
            "OtherTransferCount",
        )
    ]


class BASIC_LIMIT(ctypes.Structure):
    _fields_ = [
        ("PerProcessUserTimeLimit", ctypes.c_longlong),
        ("PerJobUserTimeLimit", ctypes.c_longlong),
        ("LimitFlags", wintypes.DWORD),
        ("MinimumWorkingSetSize", ctypes.c_size_t),
        ("MaximumWorkingSetSize", ctypes.c_size_t),
        ("ActiveProcessLimit", wintypes.DWORD),
        ("Affinity", ctypes.c_size_t),
        ("PriorityClass", wintypes.DWORD),
        ("SchedulingClass", wintypes.DWORD),
    ]


class EXTENDED_LIMIT(ctypes.Structure):
    _fields_ = [
        ("BasicLimitInformation", BASIC_LIMIT),
        ("IoInfo", IO_COUNTERS),
        ("ProcessMemoryLimit", ctypes.c_size_t),
        ("JobMemoryLimit", ctypes.c_size_t),
        ("PeakProcessMemoryUsed", ctypes.c_size_t),
        ("PeakJobMemoryUsed", ctypes.c_size_t),
    ]


def kernel():
    api = ctypes.WinDLL("kernel32", use_last_error=True)
    for name in ("CreateJobObjectW", "OpenProcess", "GetCurrentProcess"):
        getattr(api, name).restype = wintypes.HANDLE
    api.CreateJobObjectW.argtypes = [ctypes.c_void_p, wintypes.LPCWSTR]
    api.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    api.GetProcessTimes.argtypes = [wintypes.HANDLE] + [ctypes.POINTER(wintypes.FILETIME)] * 4
    api.CloseHandle.argtypes = [wintypes.HANDLE]
    api.SetInformationJobObject.argtypes = [
        wintypes.HANDLE,
        ctypes.c_int,
        ctypes.c_void_p,
        wintypes.DWORD,
    ]
    api.AssignProcessToJobObject.argtypes = [wintypes.HANDLE, wintypes.HANDLE]
    return api


def creation_time(process_id: int) -> str | None:
    api = kernel()
    handle = api.OpenProcess(0x1000, False, process_id)
    if not handle:
        return None
    try:
        values = [wintypes.FILETIME() for _ in range(4)]
        if not api.GetProcessTimes(handle, *(ctypes.byref(v) for v in values)):
            return None
        return str((values[0].dwHighDateTime << 32) | values[0].dwLowDateTime)
    finally:
        api.CloseHandle(handle)


def same_process(process_id: int, started: str) -> bool:
    return creation_time(process_id) == started


def atomic_json(path: Path, value: dict) -> None:
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(value), encoding="utf-8")
    temporary.replace(path)


def owner_active(spec: dict) -> bool:
    if not same_process(spec["ownerPid"], spec["ownerStarted"]):
        return False
    if "lockPath" in spec:
        try:
            with Path(spec["lockPath"]).open("rb"):
                return False  # Root script released its exclusive handle.
        except PermissionError:
            pass
        except FileNotFoundError:
            return False
    return True


def owned_job():
    api = kernel()
    job = api.CreateJobObjectW(None, None)
    limits = EXTENDED_LIMIT()
    limits.BasicLimitInformation.LimitFlags = 0x2000  # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
    if (
        not job
        or not api.SetInformationJobObject(job, 9, ctypes.byref(limits), ctypes.sizeof(limits))
        or not api.AssignProcessToJobObject(job, api.GetCurrentProcess())
    ):
        raise RuntimeError("OWNERSHIP_JOB_UNAVAILABLE")
    return api, job


def run(spec_path: Path) -> None:
    spec = json.loads(spec_path.read_text(encoding="utf-8-sig"))
    state_path = spec_path.with_suffix(".state.json")
    stop_path = spec_path.with_suffix(".stop")
    api, job = owned_job()
    # Do not close job early: this process itself belongs to the job. Windows
    # closes it on supervisor exit, terminating only descendants still alive.
    state = {
        "session": spec["session"],
        "pid": os.getpid(),
        "started": creation_time(os.getpid()),
        "status": "starting",
        "service": spec["service"],
    }
    atomic_json(state_path, state)
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
    with Path(spec["log"]).open("ab", buffering=0) as log:
        environment = os.environ.copy()
        for name, value in spec.get("environment", {}).items():
            if name not in {
                "MAIZEDOCTOR_PHONE_SESSION",
                "MAIZEDOCTOR_PHONE_STOP",
                "MAIZEDOCTOR_PHONE_ACK",
            }:
                raise RuntimeError("INVALID_SUPERVISOR_ENVIRONMENT")
            environment[name] = value
        child = subprocess.Popen(
            spec["argv"],
            cwd=spec["cwd"],
            stdin=subprocess.DEVNULL,
            stdout=log,
            stderr=log,
            startupinfo=startup,
            creationflags=subprocess.CREATE_NEW_CONSOLE,
            env=environment,
        )
        state.update(childPid=child.pid, childStarted=creation_time(child.pid), status="running")
        atomic_json(state_path, state)
        while child.poll() is None:
            if (
                stop_path.exists()
                or Path(spec.get("sessionStop", stop_path)).exists()
                or not owner_active(spec)
            ):
                break
            time.sleep(0.25)
        forced = False
        if child.poll() is None:
            state["status"] = "stopping"
            atomic_json(state_path, state)
            if "applicationAck" in spec:
                stop_path.touch()
                deadline = time.monotonic() + spec["graceSeconds"]
                acknowledged = False
                while time.monotonic() < deadline:
                    with suppress(OSError):
                        acknowledged = Path(spec["applicationAck"]).read_text() == spec["session"]
                    if acknowledged:
                        break
                    time.sleep(0.2)
                state["applicationDrained"] = acknowledged
                forced = not acknowledged
            # Attach only to our still-live child's private console, never the
            # user's console. Ignore CTRL+C in the supervisor, not in the child.
            api.FreeConsole()
            if same_process(child.pid, state["childStarted"]) and api.AttachConsole(child.pid):
                api.SetConsoleCtrlHandler(None, True)
                api.GenerateConsoleCtrlEvent(0, 0)
            try:
                child.wait(timeout=5 if "applicationAck" in spec else spec["graceSeconds"])
            except subprocess.TimeoutExpired:
                forced = True
        # Closing a watcher (npm/tsx) may precede application child completion.
        # Allow the full grace window before job teardown so DB writers can drain.
        if state["status"] == "stopping" and not forced and "applicationAck" not in spec:
            time.sleep(spec.get("drainSeconds", 3))
        state.update(status="stopped", exitCode=child.poll(), forced=forced)
        atomic_json(state_path, state)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--spec", type=Path)
    parser.add_argument("--identity", type=int)
    parser.add_argument("--capture")
    arguments = parser.parse_args()
    try:
        if arguments.capture:
            command = json.loads(base64.b64decode(arguments.capture))
            api, job = owned_job()
            raise SystemExit(
                subprocess.call(
                    command["argv"],
                    cwd=command["cwd"],
                    stdin=subprocess.DEVNULL,
                    stdout=sys.stdout,
                    stderr=sys.stderr,
                    creationflags=subprocess.CREATE_NO_WINDOW,
                )
            )
        elif arguments.identity:
            print(creation_time(arguments.identity) or "missing")
        else:
            run(arguments.spec)
    except Exception:
        # Never print argv, inherited environment or rejected config values.
        if arguments.spec:
            atomic_json(arguments.spec.with_suffix(".state.json"), {"status": "failed"})
        raise SystemExit(
            "Owned service supervisor failed; inspect prerequisites and job permissions."
        ) from None
