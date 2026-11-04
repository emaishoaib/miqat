"""Uploads a timetable to the deployed Miqat server.

It finds the server and its admin token the same way the miqat-timetables
skill does. The domain comes from Config/Release.xcconfig, and the token from
Google Secret Manager through the Mac's gcloud sign-in. The token is never
written anywhere or included in an error.
"""

from __future__ import annotations

import json
import os
import subprocess
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
RELEASE_CONFIG = REPO_ROOT / "Config/Release.xcconfig"
SERVER_HOST_SETTING = "MIQAT_SERVER_HOST"
ADMIN_TOKEN_SECRET = "admin-token"
GCLOUD_LOCATIONS = [
    Path("/opt/homebrew/bin/gcloud"),
    Path("/usr/local/bin/gcloud"),
    Path.home() / "google-cloud-sdk/bin/gcloud",
]
TOOL_DIRECTORIES = ["/opt/homebrew/bin", "/usr/local/bin"]
GCLOUD_TIMEOUT_SECONDS = 60
UPLOAD_TIMEOUT_SECONDS = 30


class UploadError(Exception):
    """Raised when the timetable can't be sent to the server."""


def server_host(config: Path) -> str:
    try:
        lines = config.read_text().splitlines()
    except OSError as error:
        raise UploadError(f"Couldn't read {config.name}: {error.strerror}.") from error
    for line in lines:
        name, _, value = line.partition("=")
        if name.strip() == SERVER_HOST_SETTING and value.strip():
            return value.strip()
    raise UploadError(f"{config.name} has no {SERVER_HOST_SETTING}.")


def upload_url(host: str, place_id: str) -> str:
    return f"https://{host}/admin/mosques/{urllib.parse.quote(place_id, safe='')}/timetable"


def find_gcloud() -> Path:
    for location in GCLOUD_LOCATIONS:
        if location.exists():
            return location
    raise UploadError("Couldn't find the gcloud command.")


def admin_token(gcloud: Path) -> str:
    path = os.pathsep.join([*TOOL_DIRECTORIES, os.environ.get("PATH", "")])
    try:
        completed = subprocess.run(
            [
                str(gcloud),
                "secrets",
                "versions",
                "access",
                "latest",
                "--secret",
                ADMIN_TOKEN_SECRET,
            ],
            env={**os.environ, "PATH": path},
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            timeout=GCLOUD_TIMEOUT_SECONDS,
            check=False,
        )
    except subprocess.TimeoutExpired as error:
        raise UploadError("gcloud took too long to read the admin token.") from error
    if completed.returncode != 0:
        reason = completed.stderr.strip().splitlines()[-1:] or ["no reason given"]
        raise UploadError(f"gcloud couldn't read the admin token: {reason[0]}")
    return completed.stdout.strip()


def put_json(url: str, token: str, body: dict) -> tuple[int, object]:
    request = urllib.request.Request(
        url,
        data=json.dumps(body).encode(),
        method="PUT",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(
            request, timeout=UPLOAD_TIMEOUT_SECONDS
        ) as response:
            return response.status, json.loads(response.read() or b"null")
    except urllib.error.HTTPError as error:
        return error.code, json.loads(error.read() or b"null")
    except (OSError, ValueError) as error:
        raise UploadError(f"Couldn't reach the server: {error}") from error


def reason(problem: object) -> str:
    if isinstance(problem, dict):
        location = ".".join(
            str(part) for part in problem.get("loc", []) if part != "body"
        )
        return (
            f"{location}: {problem.get('msg')}" if location else str(problem.get("msg"))
        )
    return str(problem)


def outcome(status: int, body: object) -> dict:
    detail = body.get("detail") if isinstance(body, dict) else None
    if status == 200 and isinstance(body, dict):
        return {"type": "uploaded", "daysSaved": body["days_saved"]}
    if status == 422:
        problems = detail if isinstance(detail, list) else [detail]
        return {
            "type": "rejected",
            "problems": [reason(problem) for problem in problems],
        }
    if status == 401:
        raise UploadError("The server didn't accept the admin token.")
    if status == 404:
        raise UploadError("The server doesn't know this mosque yet.")
    raise UploadError(f"The server replied with status {status}.")


def upload_to_server(place_id: str, days: list) -> dict:
    url = upload_url(server_host(RELEASE_CONFIG), place_id)
    status, body = put_json(url, admin_token(find_gcloud()), {"days": days})
    return outcome(status, body)
