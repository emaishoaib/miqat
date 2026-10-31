import datetime
import enum

from sqlalchemy import DateTime, Engine, Enum, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Prayer(enum.StrEnum):
    FAJR = "fajr"
    SUNRISE = "sunrise"
    DHUHR = "dhuhr"
    ASR = "asr"
    MAGHRIB = "maghrib"
    ISHA = "isha"


PRAYER_TYPE = Enum(
    Prayer,
    native_enum=False,
    values_callable=lambda prayers: [prayer.value for prayer in prayers],
)


class Mosque(Base):
    __tablename__ = "mosques"

    place_id: Mapped[str] = mapped_column(primary_key=True)
    name: Mapped[str]
    address: Mapped[str]
    website: Mapped[str | None]
    latitude: Mapped[float]
    longitude: Mapped[float]
    time_zone: Mapped[str]
    timetable_version: Mapped[int] = mapped_column(default=0)
    timetable_updated_at: Mapped[datetime.datetime | None] = mapped_column(
        DateTime(timezone=True), default=None
    )

    prayer_times: Mapped[list["PrayerTime"]] = relationship(
        back_populates="mosque", cascade="all, delete-orphan"
    )


class PrayerTime(Base):
    __tablename__ = "prayer_times"
    __table_args__ = (UniqueConstraint("place_id", "date", "prayer"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    place_id: Mapped[str] = mapped_column(ForeignKey("mosques.place_id"))
    date: Mapped[datetime.date]
    prayer: Mapped[Prayer] = mapped_column(PRAYER_TYPE)
    begins: Mapped[datetime.time]
    jamaat: Mapped[datetime.time | None]

    mosque: Mapped[Mosque] = relationship(back_populates="prayer_times")


class City(Base):
    __tablename__ = "cities"

    place_id: Mapped[str] = mapped_column(primary_key=True)
    name: Mapped[str]
    country: Mapped[str]
    latitude: Mapped[float]
    longitude: Mapped[float]
    time_zone: Mapped[str]
    method: Mapped[int]
    school: Mapped[int]
    timetable_version: Mapped[int] = mapped_column(default=0)

    prayer_times: Mapped[list["CityPrayerTime"]] = relationship(
        back_populates="city", cascade="all, delete-orphan"
    )


class CityPrayerTime(Base):
    __tablename__ = "city_prayer_times"
    __table_args__ = (UniqueConstraint("place_id", "date", "prayer"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    place_id: Mapped[str] = mapped_column(ForeignKey("cities.place_id"))
    date: Mapped[datetime.date]
    prayer: Mapped[Prayer] = mapped_column(PRAYER_TYPE)
    begins: Mapped[datetime.time]

    city: Mapped[City] = relationship(back_populates="prayer_times")


def create_tables(engine: Engine) -> None:
    Base.metadata.create_all(engine)
