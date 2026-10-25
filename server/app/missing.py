import datetime

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.database import SessionLocal
from app.models import Mosque, PrayerTime

DAYS_AHEAD = 7


def mosques_needing_times(
    session: Session, today: datetime.date, days_ahead: int = DAYS_AHEAD
) -> list[tuple[Mosque, datetime.date | None]]:
    rows = session.execute(
        select(Mosque, func.max(PrayerTime.date))
        .outerjoin(PrayerTime)
        .group_by(Mosque.place_id)
    ).all()
    enough = today + datetime.timedelta(days=days_ahead)
    needing = [
        (mosque, last_day)
        for mosque, last_day in rows
        if last_day is None or last_day < enough
    ]
    return sorted(
        needing,
        key=lambda row: (
            row[0].timetable_updated_at is not None,
            row[0].timetable_updated_at.timestamp()
            if row[0].timetable_updated_at
            else 0,
        ),
    )


if __name__ == "__main__":
    with SessionLocal() as session:
        for mosque, last_day in mosques_needing_times(session, datetime.date.today()):
            updated = mosque.timetable_updated_at
            updated_text = f"{updated:%Y-%m-%d}" if updated else "never"
            print(
                f"{mosque.place_id}  {mosque.name}  "
                f"last day: {last_day or 'none'}  updated: {updated_text}"
            )
