---
name: miqat-timetables
description: Read and update mosque prayer timetables on the Miqat server. Use when the user asks about mosques near a location, which mosques have prayer times, a mosque's times for today or a range of days, how far ahead a mosque's times go, which mosques need times, or asks to load a timetable from a PDF, image or pasted text, or to change specific prayer times.
---

# Miqat timetables

Everything goes through one command, run from the `server/` folder of this repo:

```bash
uv run python -m app.cli <command> ...
```

It prints the server's reply as JSON. It exits with status 1 and prints the server's reasons when a request fails.

## Before running anything

- `MIQAT_ADMIN_TOKEN` must be set in the environment. If it is missing, ask the user to set it in their shell. Never ask them to paste the token into the conversation, and never write it into a file.
- `MIQAT_SERVER_URL` picks the server. It defaults to `http://localhost:8000`. For the local server, Postgres must be running (`docker compose up -d` in `server/`) and the server started.

## Commands

| Question | Command |
|---|---|
| Which mosques are near a location, and which have times? | `nearby LATITUDE LONGITUDE` |
| Which mosque is the one the user means? | `search TEXT` (part of its name) |
| How far ahead do a mosque's times go? | `mosque PLACE_ID` (see `first_day` and `last_day`) |
| What are a mosque's times today? | `times PLACE_ID` |
| What are its times for a range of days? | `times PLACE_ID --from YYYY-MM-DD --to YYYY-MM-DD` |
| Which mosques have no times or are running low? | `needing` (or `needing --days N`) |
| Save times | `upload PLACE_ID FILE.json` (or `-` to read from stdin) |

Mosques are identified by their Google place ID. Use `search` or `nearby` to find it from a name or location. A mosque can only receive times once it is in the database, which happens when the app looks for mosques near it. `nearby` shows this as `in_database`.

## Timetable format

`upload` takes, and `times` returns, this shape:

```json
{
  "days": [
    {
      "date": "2026-11-01",
      "times": {
        "fajr": {"begins": "05:52", "jamaat": "06:30"},
        "sunrise": {"begins": "07:48"},
        "dhuhr": {"begins": "12:49", "jamaat": "13:30"},
        "asr": {"begins": "15:14", "jamaat": "15:45"},
        "maghrib": {"begins": "17:50", "jamaat": "17:55"},
        "isha": {"begins": "19:21", "jamaat": "19:45"}
      }
    }
  ]
}
```

- Dates are `YYYY-MM-DD`. Times are the mosque's local time on the 24-hour clock, `HH:MM`.
- `fajr`, `dhuhr`, `asr`, `maghrib` and `isha` are required on every day. `sunrise` is optional.
- `jamaat` is optional for every prayer.
- Uploading a day replaces everything stored for that day, so always send every prayer for each day you upload.

The server rejects an upload, saving nothing, if a required prayer is missing, prayers are out of order, a jamaat is before its prayer begins, or days are repeated or have gaps between them.

## Loading a timetable from a file

1. Identify the mosque and get its place ID with `search` or `nearby`.
2. Read every day in the file into the format above. Timetables often label prayers differently: Zuhr or Dhuhr, Shuruq or Sunrise, Iqamah or Jama'ah for jamaat. Convert 12-hour times to 24-hour ones.
3. If any value is unreadable or ambiguous, ask the user rather than guessing.
4. Show the user the full table and get their confirmation before uploading.
5. Write the JSON to a temporary file and run `upload`.
6. If the server rejects it, read its reasons, fix those days, show the user what changed, and upload again.

## Changing specific times

1. Run `times PLACE_ID` for the days involved.
2. Change only what the user asked for, keeping every other prayer as it was.
3. Show the user the before and after, then `upload` those days.
