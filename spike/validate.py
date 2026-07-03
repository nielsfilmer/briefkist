"""Deterministic post-validation and normalization (plan.md §6.4, v0.4): never
trust the model on format-critical fields. Dates are the remaining
format-critical field after the archive pivot (decision log v0.4 removed the
financial fields); the parser accepts the display formats letters actually use
(NL/DE/EN month names, dd-mm-yyyy) and emits the ISO form the archive stores.
"""

from __future__ import annotations

import datetime as dt
import re

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


# --- keyword curation (decision log v0.4) -----------------------------------
# The 4B model does not reliably obey "no raw numbers" prompt rules (measured:
# IBANs, amounts and postcodes kept appearing), so curation is deterministic —
# same §6.4 philosophy as date validation: never trust the model on it.

_KW_IBANISH = re.compile(r"\b[A-Z]{2}\d{2}[A-Z0-9 ]{8,}")
_KW_DATEISH = re.compile(r"\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4}")
# NL (1234 AB) and UK (BS1 4QD) postcodes
_KW_POSTCODEISH = re.compile(r"\b\d{4}\s?[A-Z]{2}\b|\b[A-Z]{1,2}\d{1,2}[A-Z]?\s?\d[A-Z]{2}\b")
_KW_YEAR = re.compile(r"(19|20)\d{2}")


def curate_keywords(raw: list[str] | None, limit: int = 8) -> list[str]:
    """Keep only keywords someone would actually search an archive by:
    no amounts/IBANs/phone numbers, no bare dates, no postcodes, no dupes.
    Standalone years are explicitly allowed ('belasting 2023' is a real query).
    """
    out: list[str] = []
    seen: set[str] = set()
    for keyword in raw or []:
        keyword = keyword.strip()
        if len(keyword) < 3:
            continue
        if not _KW_YEAR.fullmatch(keyword):
            # strip embedded years before the digit-ratio check so terms like
            # "Euro 2024" or "aangifte 2023" aren't killed by their year part
            base = _KW_YEAR.sub("", keyword)
            digits = sum(c.isdigit() for c in base)
            if base and digits / len(base) > 0.4:
                continue  # amounts, phone numbers, bare identifiers
            if "€" in keyword or "$" in keyword:
                continue
            if (
                _KW_IBANISH.search(keyword)
                or _KW_DATEISH.search(keyword)
                or _KW_POSTCODEISH.search(keyword)
            ):
                continue
        lowered = keyword.lower()
        if lowered in seen:
            continue
        seen.add(lowered)
        out.append(keyword)
    return out[:limit]


def normalize_place(raw: str | None) -> str | None:
    """Reduce a sender place to the bare city/town name: the model tends to
    return full address lines despite instructions. Prefer the segment that
    carries a postcode (digits) — that's the postcode+city line — and strip
    the postcode tokens from it; with no digits anywhere, the FIRST segment is
    the city ("Bussum, Nederland" → "Bussum")."""
    if not raw:
        return None
    segments = [s for s in raw.split(",") if s.strip()]
    if not segments:
        return None
    with_digits = [s for s in segments if any(c.isdigit() for c in s)]
    segment = with_digits[-1] if with_digits else segments[0]
    words = [
        w
        for w in segment.split()
        if not any(c.isdigit() for c in w) and not (w.isupper() and len(w) <= 3)
    ]
    return " ".join(words).strip(" .") or None


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
