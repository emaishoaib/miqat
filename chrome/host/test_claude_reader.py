import datetime
import json

import pytest
from claude_reader import TimetableError, claude_command, timetable_from

TIMETABLE = {"days": [], "problems": ["There is no timetable on this page."]}


def test_runs_claude_with_only_the_read_tool():
    command = claude_command("/usr/local/bin/claude", datetime.date(2026, 11, 4), [])

    assert command[0] == "/usr/local/bin/claude"
    assert "--restricted" in command
    assert command[command.index("--tools") + 1] == "Read"
    assert command[command.index("--permission-mode") + 1] == "dontAsk"


def test_tells_claude_what_day_it_is():
    command = claude_command("claude", datetime.date(2026, 11, 4), [])

    assert "Today is 2026-11-04." in command[command.index("--print") + 1]


def test_reads_the_structured_answer():
    output = json.dumps(
        {"is_error": False, "result": "", "structured_output": TIMETABLE}
    )

    assert timetable_from(output) == TIMETABLE


def test_reports_an_answer_that_is_not_json():
    with pytest.raises(TimetableError, match="wasn't JSON"):
        timetable_from("Not logged in")


def test_reports_an_error_from_claude():
    output = json.dumps({"is_error": True, "result": "Invalid API key"})

    with pytest.raises(TimetableError, match="Invalid API key"):
        timetable_from(output)


def test_reports_an_answer_without_a_timetable():
    output = json.dumps({"is_error": False, "result": "I couldn't find one."})

    with pytest.raises(TimetableError, match="didn't return a timetable"):
        timetable_from(output)


def test_asks_only_for_a_fresh_read_the_first_time():
    command = claude_command("claude", datetime.date(2026, 11, 4), [])

    assert "answer.json" not in command[command.index("--print") + 1]


def test_asks_claude_to_fix_what_the_server_rejected():
    rejections = ["2026-11-05: isha begins before or with maghrib."]

    command = claude_command("claude", datetime.date(2026, 11, 4), rejections)

    prompt = command[command.index("--print") + 1]
    assert "answer.json holds your previous answer" in prompt
    assert "- 2026-11-05: isha begins before or with maghrib." in prompt
