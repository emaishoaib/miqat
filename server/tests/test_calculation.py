from app.calculation import Method, School, method_for, school_for


def test_the_uk_uses_the_moonsighting_committee_and_the_hanafi_school():
    assert method_for("GB") == Method.MOONSIGHTING_COMMITTEE
    assert school_for("GB") == School.HANAFI


def test_an_arab_country_uses_its_own_method_and_the_standard_school():
    assert method_for("SA") == Method.UMM_AL_QURA
    assert school_for("SA") == School.STANDARD


def test_a_country_without_an_entry_uses_the_muslim_world_league_and_standard():
    assert method_for("NO") == Method.MUSLIM_WORLD_LEAGUE
    assert school_for("NO") == School.STANDARD


def test_country_codes_are_matched_regardless_of_case():
    assert method_for("pk") == Method.KARACHI
    assert school_for("pk") == School.HANAFI
