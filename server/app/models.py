import datetime
import enum

from sqlalchemy import Engine, Enum, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Prayer(enum.StrEnum):
    FAJR = "fajr"
    SUNRISE = "sunrise"
    DHUHR = "dhuhr"
    ASR = "asr"
    MAGHRIB = "maghrib"
    ISHA = "isha"


class Mosque(Base):
    __tablename__ = "mosques"

    place_id: Mapped[str] = mapped_column(primary_key=True)
    name: Mapped[str]
    address: Mapped[str]
    latitude: Mapped[float]
    longitude: Mapped[float]
    time_zone: Mapped[str]
    timetable_version: Mapped[int] = mapped_column(default=0)

    prayer_times: Mapped[list["PrayerTime"]] = relationship(
        back_populates="mosque", cascade="all, delete-orphan"
    )


class PrayerTime(Base):
    __tablename__ = "prayer_times"
    __table_args__ = (UniqueConstraint("place_id", "date", "prayer"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    place_id: Mapped[str] = mapped_column(ForeignKey("mosques.place_id"))
    date: Mapped[datetime.date]
    prayer: Mapped[Prayer] = mapped_column(
        Enum(
            Prayer,
            native_enum=False,
            values_callable=lambda prayers: [prayer.value for prayer in prayers],
        )
    )
    begins: Mapped[datetime.time]
    jamaat: Mapped[datetime.time | None]

    mosque: Mapped[Mosque] = relationship(back_populates="prayer_times")


def create_tables(engine: Engine) -> None:
    Base.metadata.create_all(engine)
