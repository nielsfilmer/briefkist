from spike.validate import normalize_date


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


def test_curate_keywords_drops_financial_noise():
    from spike.validate import curate_keywords

    raw = [
        "Brightside Plumbing Ltd",   # keep
        "Mr A. Whitfield",           # keep
        "€1,294.29",                 # amount -> drop
        "IBAN NL38 RABO 8964 5819 40",  # drop
        "Payment due by 13-04-2026",    # date -> drop
        "Bristol BS1 4QD",           # UK postcode -> drop
        "1234 AB",                   # NL postcode -> drop
        "857640111",                 # digit-heavy -> drop
        "2023",                      # standalone year -> KEEP
        "Inkomstenbelasting",        # keep
        "inkomstenbelasting",        # dupe (case) -> drop
        "ab",                        # too short -> drop
    ]
    assert curate_keywords(raw) == [
        "Brightside Plumbing Ltd", "Mr A. Whitfield", "2023", "Inkomstenbelasting",
    ]


def test_curate_keywords_caps_at_limit():
    from spike.validate import curate_keywords

    raw = [f"onderwerp{i}" for i in range(12)]
    assert len(curate_keywords(raw)) == 8


def test_normalize_place():
    from spike.validate import normalize_place

    assert normalize_place("Utrecht") == "Utrecht"
    assert normalize_place("14 Harbour Road, Bristol BS1 4QD") == "Bristol"
    assert normalize_place("3542 AD Utrecht") == "Utrecht"
    assert normalize_place("Den Haag") == "Den Haag"
    assert normalize_place("Bussum, Nederland") == "Bussum"
    assert normalize_place("Frankfurt am Main") == "Frankfurt am Main"
    assert normalize_place(None) is None
    assert normalize_place("1234 AB") is None


def test_curate_keywords_keeps_year_bearing_terms():
    from spike.validate import curate_keywords

    assert curate_keywords(["Euro 2024", "aangifte 2023", "belastingjaar 2023"]) == [
        "Euro 2024", "aangifte 2023", "belastingjaar 2023",
    ]
