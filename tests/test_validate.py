from spike.validate import normalize_amount, normalize_date, normalize_iban


def test_numeric_dates():
    assert normalize_date("15-08-2026") == "2026-08-15"
    assert normalize_date("03/07/2026") == "2026-07-03"
    assert normalize_date("31-02-2026") is None  # impossible date
    assert normalize_date("2026-08-15") == "2026-08-15"  # already ISO


def test_written_dates_all_languages():
    assert normalize_date("3 juli 2026") == "2026-07-03"  # nl
    assert normalize_date("3. Juli 2026") == "2026-07-03"  # de
    assert normalize_date("3 July 2026") == "2026-07-03"  # en
    assert normalize_date("12 maart 2026") == "2026-03-12"
    assert normalize_date("1. März 2026") == "2026-03-01"
    assert normalize_date("28 February 2026") == "2026-02-28"


def test_date_garbage():
    assert normalize_date(None) is None
    assert normalize_date("") is None
    assert normalize_date("no date here") is None


def test_amounts_eu_and_en():
    assert normalize_amount("€ 1.234,56") == "1234.56"
    assert normalize_amount("1.234,56 €") == "1234.56"
    assert normalize_amount("€1,234.56") == "1234.56"
    assert normalize_amount("EUR 123,45") == "123.45"
    assert normalize_amount("997.87") == "997.87"
    assert normalize_amount("5,00") == "5.00"
    assert normalize_amount(None) is None
    assert normalize_amount("free") is None


def test_iban_normalization():
    # NL91ABNA0417164300 is the canonical example IBAN with a valid checksum
    assert normalize_iban("NL91 ABNA 0417 1643 00") == "NL91ABNA0417164300"
    assert normalize_iban("IBAN: NL91 ABNA 0417 1643 00") == "NL91ABNA0417164300"
    assert normalize_iban("NL92 ABNA 0417 1643 00") is None  # bad checksum
    assert normalize_iban(None) is None
    assert normalize_iban("not an iban") is None
