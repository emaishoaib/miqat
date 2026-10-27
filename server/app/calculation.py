import enum


class Method(enum.IntEnum):
    """
    Prayer time calculation methods numbered as AlAdhan's API numbers them.

    Each value is the ID AlAdhan expects in its method parameter so a member
    can be sent as it is. The gaps in the numbering are AlAdhan's -- 0 is the
    Shia Ithna-Ashari method which no country here uses and 6 is unassigned.
    AlAdhan lists every method at https://api.aladhan.com/v1/methods.
    """

    KARACHI = 1
    ISNA = 2
    MUSLIM_WORLD_LEAGUE = 3
    UMM_AL_QURA = 4
    EGYPT = 5
    TEHRAN = 7
    GULF = 8
    KUWAIT = 9
    QATAR = 10
    SINGAPORE = 11
    FRANCE = 12
    TURKEY = 13
    RUSSIA = 14
    MOONSIGHTING_COMMITTEE = 15
    DUBAI = 16
    MALAYSIA = 17
    TUNISIA = 18
    ALGERIA = 19
    INDONESIA = 20
    MOROCCO = 21
    PORTUGAL = 22
    JORDAN = 23


class School(enum.IntEnum):
    """
    Schools of law for when Asr begins numbered as AlAdhan's API numbers them.

    Each value is what AlAdhan expects in its school parameter.
    """

    STANDARD = 0
    HANAFI = 1


METHOD_BY_COUNTRY = {
    "AE": Method.DUBAI,
    "AF": Method.KARACHI,
    "BD": Method.KARACHI,
    "BH": Method.GULF,
    "CA": Method.ISNA,
    "DZ": Method.ALGERIA,
    "EG": Method.EGYPT,
    "FR": Method.FRANCE,
    "GB": Method.MOONSIGHTING_COMMITTEE,
    "ID": Method.INDONESIA,
    "IN": Method.KARACHI,
    "IR": Method.TEHRAN,
    "JO": Method.JORDAN,
    "KW": Method.KUWAIT,
    "MA": Method.MOROCCO,
    "MY": Method.MALAYSIA,
    "OM": Method.GULF,
    "PK": Method.KARACHI,
    "PT": Method.PORTUGAL,
    "QA": Method.QATAR,
    "RU": Method.RUSSIA,
    "SA": Method.UMM_AL_QURA,
    "SG": Method.SINGAPORE,
    "TN": Method.TUNISIA,
    "TR": Method.TURKEY,
    "US": Method.ISNA,
}

METHOD_NAMES = {
    Method.KARACHI: "University of Islamic Sciences, Karachi",
    Method.ISNA: "Islamic Society of North America",
    Method.MUSLIM_WORLD_LEAGUE: "Muslim World League",
    Method.UMM_AL_QURA: "Umm al-Qura University, Makkah",
    Method.EGYPT: "Egyptian General Authority of Survey",
    Method.TEHRAN: "Institute of Geophysics, University of Tehran",
    Method.GULF: "Gulf Region",
    Method.KUWAIT: "Kuwait",
    Method.QATAR: "Qatar",
    Method.SINGAPORE: "Majlis Ugama Islam Singapura",
    Method.FRANCE: "Union des Organisations Islamiques de France",
    Method.TURKEY: "Diyanet, Turkey",
    Method.RUSSIA: "Spiritual Administration of Muslims of Russia",
    Method.MOONSIGHTING_COMMITTEE: "Moonsighting Committee Worldwide",
    Method.DUBAI: "Dubai",
    Method.MALAYSIA: "JAKIM, Malaysia",
    Method.TUNISIA: "Tunisia",
    Method.ALGERIA: "Algeria",
    Method.INDONESIA: "Kementerian Agama, Indonesia",
    Method.MOROCCO: "Morocco",
    Method.PORTUGAL: "Comunidade Islamica de Lisboa",
    Method.JORDAN: "Ministry of Awqaf, Jordan",
}

SCHOOL_NAMES = {
    School.STANDARD: "Shafi'i",
    School.HANAFI: "Hanafi",
}

HANAFI_COUNTRIES = {
    "AF",
    "BD",
    "GB",
    "IN",
    "KG",
    "KZ",
    "PK",
    "TJ",
    "TM",
    "TR",
    "UZ",
}


def method_for(country: str) -> Method:
    return METHOD_BY_COUNTRY.get(country.upper(), Method.MUSLIM_WORLD_LEAGUE)


def school_for(country: str) -> School:
    if country.upper() in HANAFI_COUNTRIES:
        return School.HANAFI
    return School.STANDARD
