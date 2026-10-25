import datetime

from pydantic import BaseModel

from app.models import Prayer
from app.timetables import DayTimes

PRAYER_ORDER = list(Prayer)
REQUIRED_PRAYERS = [prayer for prayer in Prayer if prayer is not Prayer.SUNRISE]


class TimeIn(BaseModel):
    begins: datetime.time
    jamaat: datetime.time | None = None


class DayIn(BaseModel):
    date: datetime.date
    times: dict[Prayer, TimeIn]


class TimetableIn(BaseModel):
    days: list[DayIn]


def problems_with(timetable: TimetableIn) -> list[str]:
    if not timetable.days:
        return ["The timetable has no days."]

    problems = []
    dates = [day.date for day in timetable.days]
    for date in sorted({date for date in dates if dates.count(date) > 1}):
        problems.append(f"{date} appears more than once.")

    unique_dates = sorted(set(dates))
    for earlier, later in zip(unique_dates, unique_dates[1:]):
        if (later - earlier).days > 1:
            problems.append(f"Days are missing between {earlier} and {later}.")

    for day in timetable.days:
        problems.extend(problems_on(day))
    return problems


def problems_on(day: DayIn) -> list[str]:
    problems = [
        f"{day.date}: {prayer.value} is missing."
        for prayer in REQUIRED_PRAYERS
        if prayer not in day.times
    ]

    ordered = [prayer for prayer in PRAYER_ORDER if prayer in day.times]
    for earlier, later in zip(ordered, ordered[1:]):
        if day.times[earlier].begins >= day.times[later].begins:
            problems.append(
                f"{day.date}: {later.value} begins before or with {earlier.value}."
            )

    for prayer, time in day.times.items():
        if time.jamaat is not None and time.jamaat < time.begins:
            problems.append(f"{day.date}: {prayer.value} jamaat is before it begins.")
    return problems


def as_day_times(timetable: TimetableIn) -> dict[datetime.date, DayTimes]:
    return {
        day.date: {
            prayer: (time.begins, time.jamaat) for prayer, time in day.times.items()
        }
        for day in timetable.days
    }
