import datetime as dt
import random

from testset.entities import format_amount, iban_is_valid, make_iban
from testset.templates import DOC_TYPES, LANGUAGES, compose


def test_generated_ibans_pass_mod97():
    rng = random.Random(1)
    for country in ("NL", "DE"):
        for _ in range(50):
            assert iban_is_valid(make_iban(rng, country))


def test_iban_validator_rejects_bad_checksum():
    rng = random.Random(2)
    iban = make_iban(rng, "NL")
    bad = iban[:2] + f"{(int(iban[2:4]) + 1) % 100:02d}" + iban[4:]
    assert not iban_is_valid(bad)


def test_amount_formats():
    assert format_amount(1234.56, "nl") == "€ 1.234,56"
    assert format_amount(1234.56, "de") == "1.234,56 €"
    assert format_amount(1234.56, "en") == "€1,234.56"
    assert format_amount(5.00, "nl") == "€ 5,00"


def test_compose_truth_matches_text():
    """Every truth field that is supposed to appear on the page must be recoverable
    from the rendered text (dates/amounts appear in display form, so check via
    presence of their display markers instead)."""
    rng = random.Random(3)
    for lang in LANGUAGES:
        for doc_type in DOC_TYPES:
            letter = compose(rng, f"t_{lang}_{doc_type}", lang, doc_type)
            t = letter.truth
            assert t["sender_name"] in letter.text
            assert t["recipient_name"] in letter.text
            assert t["reference"] in letter.text
            assert t["iban"].replace(" ", "") == t["iban"]
            assert t["iban"][:2] in ("NL", "DE")
            grouped = " ".join(t["iban"][i : i + 4] for i in range(0, len(t["iban"]), 4))
            assert grouped in letter.text
            assert t["full_text"] == letter.text
            dt.date.fromisoformat(t["document_date"])
            dt.date.fromisoformat(t["due_date"])
            assert float(t["amount_due"]) > 0


def test_compose_is_deterministic_per_seed():
    a = compose(random.Random(7), "x", "nl", "invoice")
    b = compose(random.Random(7), "x", "nl", "invoice")
    assert a.text == b.text and a.truth == b.truth


def test_no_consecutive_spaces_in_any_template():
    """render._wrap's contract: consecutive spaces would be collapsed by wrapping,
    silently breaking the full_text == rendered-text guarantee."""
    rng = random.Random(11)
    for lang in LANGUAGES:
        for doc_type in DOC_TYPES:
            letter = compose(rng, f"s_{lang}_{doc_type}", lang, doc_type)
            assert "  " not in letter.text, (lang, doc_type)


def test_dateline_city_has_no_postcode():
    rng = random.Random(13)
    nl = compose(rng, "d_nl", "nl", "invoice").text.splitlines()
    de = compose(rng, "d_de", "de", "invoice").text.splitlines()
    en = compose(rng, "d_en", "en", "invoice").text.splitlines()
    # dateline is line index 8 (after sender block, blank, recipient block, blank)
    assert nl[8].split(",")[0].isalpha() or " " in nl[8].split(",")[0]  # city words only
    assert not any(ch.isdigit() for ch in nl[8].split(",")[0])
    assert not any(ch.isdigit() for ch in de[8].split(",")[0])
    assert "," not in en[8]  # en dateline is the bare date


def test_generation_axes_not_confounded(tmp_path):
    """Language, tier and doc type must vary independently — if language and tier
    share the same cycle, per-tier KPI buckets become per-language numbers."""
    from testset.degrade import TIERS
    from testset.generate import generate

    index = generate(count=27, seed=5, out_dir=tmp_path)
    combos = {(row["lang"], row["tier"]) for row in index}
    assert len(combos) == len(LANGUAGES) * len(TIERS)  # all 9 pairs occur
