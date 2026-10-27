import datetime

from sqlalchemy import select

from app.aladhan import CalculatedMonth
from app.calculation import Method, School
from app.cities import save_city_month
from app.models import City, CityPrayerTime, Prayer

NOVEMBER_1 = datetime.date(2026, 11, 1)
NOVEMBER_2 = datetime.date(2026, 11, 2)


def solihull():
    return City(
        place_id="place-solihull",
        name="Solihull",
        country="GB",
        latitude=52.4118,
        longitude=-1.7776,
        time_zone="Europe/London",
        method=Method.MOONSIGHTING_COMMITTEE,
        school=School.HANAFI,
    )


def month_with(days):
    return CalculatedMonth(
        time_zone="Europe/London",
        days={
            day: {Prayer.FAJR: fajr, Prayer.DHUHR: datetime.time(11, 51)}
            for day, fajr in days.items()
        },
    )


def stored_times(session):
    return [
        (time.date, time.prayer, time.begins)
        for time in session.scalars(
            select(CityPrayerTime).order_by(CityPrayerTime.date, CityPrayerTime.begins)
        )
    ]


def test_saving_a_month_stores_its_times_for_the_city(session):
    city = solihull()
    session.add(city)

    save_city_month(session, city, month_with({NOVEMBER_1: datetime.time(5, 26)}))
    session.flush()

    assert stored_times(session) == [
        (NOVEMBER_1, Prayer.FAJR, datetime.time(5, 26)),
        (NOVEMBER_1, Prayer.DHUHR, datetime.time(11, 51)),
    ]
    assert city.timetable_version == 1


def test_saving_days_again_replaces_them_and_bumps_the_version(session):
    city = solihull()
    session.add(city)
    save_city_month(
        session,
        city,
        month_with(
            {NOVEMBER_1: datetime.time(5, 26), NOVEMBER_2: datetime.time(5, 28)}
        ),
    )
    session.flush()

    save_city_month(session, city, month_with({NOVEMBER_2: datetime.time(5, 30)}))
    session.flush()

    assert stored_times(session) == [
        (NOVEMBER_1, Prayer.FAJR, datetime.time(5, 26)),
        (NOVEMBER_1, Prayer.DHUHR, datetime.time(11, 51)),
        (NOVEMBER_2, Prayer.FAJR, datetime.time(5, 30)),
        (NOVEMBER_2, Prayer.DHUHR, datetime.time(11, 51)),
    ]
    assert city.timetable_version == 2
