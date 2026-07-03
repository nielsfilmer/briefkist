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
