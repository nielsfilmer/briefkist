"""Deterministic post-validation and normalization (plan.md §6.4): never trust
the model on format-critical fields. Parsers accept the display formats the
letters actually use (NL/DE/EN month names, dd-mm-yyyy, EU amount formats) and
emit the normalized forms the archive stores (ISO dates, decimal amounts,
compact IBAN).
"""

from __future__ import annotations

import datetime as dt
import re

from testset.entities import iban_is_valid

# month-name -> number, lowercased; nl/de/en overlap freely (same key, same value)
_MONTHS = {
    # nl
    "januari": 1, "februari": 2, "maart": 3, "april": 4, "mei": 5, "juni": 6,
    "juli": 7, "augustus": 8, "september": 9, "oktober": 10, "november": 11,
    "december": 12,
    # de
    "januar": 1, "februar": 2, "märz": 3, "mai": 5, "august": 8, "dezember": 12,
    # en
    "january": 1, "february": 2, "march": 3, "may": 5, "june": 6, "july": 7,
    "october": 10,
}

_NUMERIC_DATE = re.compile(r"\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})\b")
_WRITTEN_DATE = re.compile(r"\b(\d{1,2})\.?\s+([A-Za-zäöüÄÖÜ]+)\s+(\d{4})\b")
_IBAN_PATTERN = re.compile(r"\b([A-Z]{2}\d{2}(?:\s?[A-Z0-9]{1,4})+)\b")
_AMOUNT_PATTERN = re.compile(
    r"(?:€\s*|EUR\s*)?(\d{1,3}(?:[.,]\d{3})*|\d+)([.,]\d{2})?(?:\s*€)?"
)


def normalize_date(raw: str | None) -> str | None:
    """Printed date (any supported display form) → ISO yyyy-mm-dd, or None."""
    if not raw:
        return None
    raw = raw.strip()
    m = _NUMERIC_DATE.search(raw)
    if m:
        day, month, year = int(m.group(1)), int(m.group(2)), int(m.group(3))
        try:
            return dt.date(year, month, day).isoformat()
        except ValueError:
            return None
    m = _WRITTEN_DATE.search(raw)
    if m:
        day, month_name, year = int(m.group(1)), m.group(2).lower(), int(m.group(3))
        month = _MONTHS.get(month_name)
        if month:
            try:
                return dt.date(year, month, day).isoformat()
            except ValueError:
                return None
    # the model may already have normalized despite instructions — accept ISO
    try:
        return dt.date.fromisoformat(raw).isoformat()
    except ValueError:
        return None


def normalize_amount(raw: str | None) -> str | None:
    """Printed amount ('€ 1.234,56', '1.234,56 €', '€1,234.56') → '1234.56'."""
    if not raw:
        return None
    m = _AMOUNT_PATTERN.search(raw.strip())
    if not m:
        return None
    whole, cents = m.group(1), m.group(2)
    digits = re.sub(r"[.,]", "", whole)
    cents_digits = cents[1:] if cents else "00"
    try:
        return f"{int(digits)}.{cents_digits}"
    except ValueError:
        return None


DOMAIN_TAG = {
    "invoice": "bill",
    "government_tax": "government",
    "insurance": "insurance",
    "medical": "medical",
    "bank": "bank",
    "subscription": "subscription",
}

# tags with no deterministic doc_type mapping; kept only if the model chose them
_FREE_JUDGMENT_TAGS = {"legal", "personal"}


def reconcile_tags(doc_type: str, model_tags: list[str], has_amount: bool) -> list[str]:
    """The §6.4 reconciliation step: tags are anchored to deterministic facts —
    the domain tag follows doc_type, 'bill' follows the presence of a payment
    amount — and the model's judgment is only trusted for tags that have no
    deterministic source (legal/personal). Kills the small-model habit of
    filling the tag list with plausible-sounding vocabulary.
    """
    tags = set()
    domain = DOMAIN_TAG.get(doc_type)
    if domain:
        tags.add(domain)
    if has_amount:
        tags.add("bill")
    tags |= _FREE_JUDGMENT_TAGS & set(model_tags)
    return sorted(tags)


def normalize_iban(raw: str | None) -> str | None:
    """Extract, compact and checksum-validate an IBAN; None if invalid."""
    if not raw:
        return None
    m = _IBAN_PATTERN.search(raw.upper())
    if not m:
        return None
    compact = m.group(1).replace(" ", "")
    return compact if iban_is_valid(compact) else None
