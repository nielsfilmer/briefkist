"""Random-but-valid entity generation: IBANs (real mod-97 checksums), amounts,
dates, references, and name/address pools per language.

Everything takes an explicit `random.Random` so a seeded run is fully
reproducible — the benchmark must be able to regenerate the identical set.
"""

from __future__ import annotations

import datetime as dt
import random
import string
from dataclasses import dataclass

# ---------------------------------------------------------------- IBAN

_IBAN_FORMATS = {
    "NL": ("NL", 4, 10),  # NLkk BANK cccccccccc
    "DE": ("DE", 0, 18),  # DEkk bbbbbbbb cccccccccc (all digits)
}

_NL_BANK_CODES = ["INGB", "RABO", "ABNA", "TRIO", "BUNQ", "SNSB", "ASNB"]


def _iban_checksum(country: str, bban: str) -> str:
    """Compute the two ISO 13616 check digits for country + BBAN."""
    rearranged = bban + country + "00"
    digits = "".join(str(int(c, 36)) for c in rearranged)
    return f"{98 - int(digits) % 97:02d}"


def make_iban(rng: random.Random, country: str) -> str:
    if country == "NL":
        bban = rng.choice(_NL_BANK_CODES) + "".join(rng.choices(string.digits, k=10))
    elif country == "DE":
        bban = "".join(rng.choices(string.digits, k=18))
    else:
        raise ValueError(f"unsupported IBAN country {country!r}")
    return country + _iban_checksum(country, bban) + bban


def iban_is_valid(iban: str) -> bool:
    """Full mod-97 validation (used by tests and later by the pipeline validator)."""
    iban = iban.replace(" ", "")
    if len(iban) < 15:
        return False
    rearranged = iban[4:] + iban[:4]
    digits = "".join(str(int(c, 36)) for c in rearranged)
    return int(digits) % 97 == 1


def group_iban(iban: str) -> str:
    """Format in the usual groups of four for display on the letter."""
    return " ".join(iban[i : i + 4] for i in range(0, len(iban), 4))


# ---------------------------------------------------------------- dates

_MONTHS = {
    "nl": [
        "januari", "februari", "maart", "april", "mei", "juni",
        "juli", "augustus", "september", "oktober", "november", "december",
    ],
    "de": [
        "Januar", "Februar", "März", "April", "Mai", "Juni",
        "Juli", "August", "September", "Oktober", "November", "Dezember",
    ],
    "en": [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December",
    ],
}


def format_date(d: dt.date, lang: str, rng: random.Random) -> str:
    """A plausible printed form; numeric and written styles both occur in real mail."""
    if rng.random() < 0.4:
        return d.strftime("%d-%m-%Y")
    month = _MONTHS[lang][d.month - 1]
    if lang == "de":
        return f"{d.day}. {month} {d.year}"
    return f"{d.day} {month} {d.year}"


def random_date(rng: random.Random, start: dt.date, end: dt.date) -> dt.date:
    return start + dt.timedelta(days=rng.randrange((end - start).days + 1))


# ---------------------------------------------------------------- amounts

def format_amount(value: float, lang: str) -> str:
    """EU comma-decimal for nl/de, point-decimal for en. Returns display string."""
    whole, cents = divmod(round(value * 100), 100)
    if lang == "en":
        return f"€{whole:,}.{cents:02d}"
    grouped = f"{whole:,}".replace(",", ".")
    if lang == "de":
        return f"{grouped},{cents:02d} €"
    return f"€ {grouped},{cents:02d}"


# ---------------------------------------------------------------- pools

@dataclass(frozen=True)
class Party:
    name: str
    street: str
    city: str  # "postcode City"


_SENDERS: dict[str, dict[str, list[Party]]] = {
    "nl": {
        "invoice": [
            Party("Van Dijk Installatietechniek B.V.", "Industrieweg 42", "3542 AD Utrecht"),
            Party("Tandartspraktijk De Molen", "Molenstraat 8", "6811 KG Arnhem"),
        ],
        "government_tax": [
            Party("Belastingdienst", "Postbus 2536", "6401 DA Heerlen"),
            Party("Gemeente Amersfoort", "Postbus 4000", "3800 EA Amersfoort"),
        ],
        "insurance": [
            Party("Univé Verzekeringen", "Postbus 15", "9400 AA Assen"),
            Party("Centraal Beheer", "Postbus 9150", "7300 HZ Apeldoorn"),
        ],
        "medical": [
            Party("Meander Medisch Centrum", "Maatweg 3", "3813 TZ Amersfoort"),
        ],
        "bank": [
            Party("Triodos Bank N.V.", "Postbus 55", "3700 AB Zeist"),
        ],
        "subscription": [
            Party("KPN B.V.", "Postbus 30000", "2500 GA Den Haag"),
        ],
    },
    "de": {
        "invoice": [
            Party("Müller Sanitär GmbH", "Hauptstraße 17", "50667 Köln"),
        ],
        "government_tax": [
            Party("Finanzamt Aachen", "Krefelder Straße 210", "52070 Aachen"),
        ],
        "insurance": [
            Party("Allianz Versicherungs-AG", "Königinstraße 28", "80802 München"),
        ],
        "medical": [
            Party("Universitätsklinikum Münster", "Albert-Schweitzer-Campus 1", "48149 Münster"),
        ],
        "bank": [
            Party("GLS Gemeinschaftsbank eG", "Christstraße 9", "44789 Bochum"),
        ],
        "subscription": [
            Party("Telekom Deutschland GmbH", "Landgrabenweg 151", "53227 Bonn"),
        ],
    },
    "en": {
        "invoice": [
            Party("Brightside Plumbing Ltd", "14 Harbour Road", "Bristol BS1 4QD"),
        ],
        "government_tax": [
            Party("HM Revenue & Customs", "PO Box 4000", "Cardiff CF14 8HR"),
        ],
        "insurance": [
            Party("Aviva Insurance Ltd", "Wellington Row", "York YO90 1WR"),
        ],
        "medical": [
            Party("St Mary's Hospital", "Praed Street", "London W2 1NY"),
        ],
        "bank": [
            Party("Monzo Bank Ltd", "Broadwalk House, 5 Appold St", "London EC2A 2AG"),
        ],
        "subscription": [
            Party("British Gas", "PO Box 227", "Rotherham S98 1PD"),
        ],
    },
}

_RECIPIENTS: dict[str, list[Party]] = {
    "nl": [
        Party("J. de Vries", "Lindenlaan 23", "3818 GK Amersfoort"),
        Party("Fam. Jansen", "Kerkstraat 101-B", "1017 GC Amsterdam"),
    ],
    "de": [
        Party("K. Schneider", "Birkenweg 5", "52062 Aachen"),
    ],
    "en": [
        Party("Mr A. Whitfield", "7 Elm Grove", "Bath BA2 3AR"),
    ],
}


def pick_sender(rng: random.Random, lang: str, doc_type: str) -> Party:
    return rng.choice(_SENDERS[lang][doc_type])


def pick_recipient(rng: random.Random, lang: str) -> Party:
    return rng.choice(_RECIPIENTS[lang])


def make_reference(rng: random.Random) -> str:
    style = rng.randrange(3)
    if style == 0:
        return f"{rng.randrange(2024, 2027)}/{rng.randrange(100000, 999999)}"
    if style == 1:
        return (
            "".join(rng.choices(string.ascii_uppercase, k=3))
            + "-"
            + "".join(rng.choices(string.digits, k=7))
        )
    return "".join(rng.choices(string.digits, k=9))
