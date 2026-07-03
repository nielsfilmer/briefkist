"""Letter composition: (language, doc_type) -> full letter text + ground truth.

The output of `compose()` is the single source of truth for the benchmark:
`text` is exactly what gets rendered (used for OCR character accuracy) and
`truth` holds the normalized fields the extractor must recover (used for
field accuracy). Keep them in lockstep — never edit one without the other.
"""

from __future__ import annotations

import datetime as dt
import random
from dataclasses import dataclass, field

from .entities import (
    format_amount,
    format_date,
    group_iban,
    make_iban,
    make_reference,
    pick_recipient,
    pick_sender,
    random_date,
)

LANGUAGES = ["nl", "de", "en"]
DOC_TYPES = ["invoice", "government_tax", "insurance", "medical", "bank", "subscription"]

# Controlled tag vocabulary from plan.md §6.4, mapped per doc type.
CONTROLLED_TAGS = {
    "invoice": ["bill"],
    "government_tax": ["government"],
    "insurance": ["insurance"],
    "medical": ["medical", "bill"],
    "bank": ["bank"],
    "subscription": ["subscription", "bill"],
}


@dataclass
class Letter:
    letter_id: str
    lang: str
    doc_type: str
    text: str  # exact rendered text, line-per-line
    truth: dict = field(default_factory=dict)


_STRINGS = {
    "nl": {
        "subject": "Betreft",
        "date_prefix": "",
        "salutation": "Geachte heer/mevrouw,",
        "closing": "Met vriendelijke groet,",
        "reference": "Kenmerk",
        "amount_due": "Te betalen bedrag",
        "due_date": "Uiterste betaaldatum",
        "pay_to": "o.v.v. het kenmerk op rekening",
        "invoice_subject": "Factuur {ref}",
        "invoice_body": (
            "Hierbij ontvangt u de factuur voor de uitgevoerde werkzaamheden. "
            "Wij verzoeken u het bedrag voor de vervaldatum over te maken."
        ),
        "government_tax_subject": "Aanslag inkomstenbelasting {year}",
        "government_tax_body": (
            "U ontvangt deze brief omdat de aanslag over belastingjaar {year} is "
            "vastgesteld. Het te betalen bedrag en de betaaltermijn vindt u hieronder."
        ),
        "insurance_subject": "Uw polis — jaarlijkse prolongatie",
        "insurance_body": (
            "Uw verzekering wordt per de genoemde datum verlengd. De nieuwe premie "
            "voor het komende jaar treft u hieronder aan."
        ),
        "medical_subject": "Factuur behandeling",
        "medical_body": (
            "Voor de behandeling op onze polikliniek brengen wij onderstaand "
            "bedrag in rekening. Dit betreft het eigen risico."
        ),
        "bank_subject": "Wijziging tarieven betaalrekening",
        "bank_body": (
            "Per de genoemde datum wijzigen de tarieven van uw betaalrekening. "
            "Het nieuwe maandbedrag staat hieronder vermeld."
        ),
        "subscription_subject": "Uw maandfactuur",
        "subscription_body": (
            "Hierbij de factuur voor uw abonnement. Het bedrag wordt niet "
            "automatisch geïncasseerd; maak het zelf over voor de vervaldatum."
        ),
    },
    "de": {
        "subject": "Betreff",
        "date_prefix": "den ",
        "salutation": "Sehr geehrte Damen und Herren,",
        "closing": "Mit freundlichen Grüßen",
        "reference": "Aktenzeichen",
        "amount_due": "Zu zahlender Betrag",
        "due_date": "Zahlbar bis",
        "pay_to": "unter Angabe des Aktenzeichens auf das Konto",
        "invoice_subject": "Rechnung Nr. {ref}",
        "invoice_body": (
            "anbei erhalten Sie die Rechnung für die ausgeführten Arbeiten. "
            "Bitte überweisen Sie den Betrag bis zum Fälligkeitsdatum."
        ),
        "government_tax_subject": "Einkommensteuerbescheid {year}",
        "government_tax_body": (
            "Sie erhalten dieses Schreiben, da der Steuerbescheid für das Jahr "
            "{year} festgesetzt wurde. Betrag und Zahlungsfrist finden Sie unten."
        ),
        "insurance_subject": "Ihre Police — jährliche Verlängerung",
        "insurance_body": (
            "Ihre Versicherung verlängert sich zum genannten Datum. Den neuen "
            "Jahresbeitrag entnehmen Sie bitte der folgenden Übersicht."
        ),
        "medical_subject": "Rechnung über ambulante Behandlung",
        "medical_body": (
            "Für die Behandlung in unserer Ambulanz stellen wir Ihnen den unten "
            "stehenden Betrag in Rechnung."
        ),
        "bank_subject": "Änderung der Kontoführungsgebühren",
        "bank_body": (
            "Zum genannten Datum ändern sich die Gebühren Ihres Girokontos. "
            "Der neue Monatsbetrag ist unten aufgeführt."
        ),
        "subscription_subject": "Ihre Monatsrechnung",
        "subscription_body": (
            "anbei die Rechnung für Ihren Vertrag. Bitte überweisen Sie den "
            "Betrag bis zum Fälligkeitsdatum."
        ),
    },
    "en": {
        "subject": "Re",
        "date_prefix": "",
        "salutation": "Dear Sir or Madam,",
        "closing": "Yours faithfully,",
        "reference": "Reference",
        "amount_due": "Amount due",
        "due_date": "Payment due by",
        "pay_to": "quoting the reference to account",
        "invoice_subject": "Invoice {ref}",
        "invoice_body": (
            "Please find below the invoice for the work carried out. We kindly "
            "ask you to transfer the amount before the due date."
        ),
        "government_tax_subject": "Income tax assessment {year}",
        "government_tax_body": (
            "You are receiving this letter because your tax assessment for {year} "
            "has been finalised. The amount payable and deadline are shown below."
        ),
        "insurance_subject": "Your policy — annual renewal",
        "insurance_body": (
            "Your insurance policy will renew on the date shown. Your new premium "
            "for the coming year is set out below."
        ),
        "medical_subject": "Invoice for outpatient treatment",
        "medical_body": (
            "Following your recent visit to our outpatient clinic, please find "
            "the amount charged below."
        ),
        "bank_subject": "Changes to your account fees",
        "bank_body": (
            "From the date shown, the fees on your current account will change. "
            "The new monthly amount is shown below."
        ),
        "subscription_subject": "Your monthly bill",
        "subscription_body": (
            "Please find your bill for this month below. Kindly transfer the "
            "amount before the due date."
        ),
    },
}

_AMOUNT_RANGES = {
    "invoice": (80, 2400),
    "government_tax": (150, 5200),
    "insurance": (120, 1600),
    "medical": (35, 900),
    "bank": (2, 25),
    "subscription": (15, 95),
}


def compose(rng: random.Random, letter_id: str, lang: str, doc_type: str) -> Letter:
    s = _STRINGS[lang]
    sender = pick_sender(rng, lang, doc_type)
    recipient = pick_recipient(rng, lang)
    doc_date = random_date(rng, dt.date(2026, 1, 5), dt.date(2026, 6, 25))
    due_date = doc_date + dt.timedelta(days=rng.choice([14, 21, 30]))
    lo, hi = _AMOUNT_RANGES[doc_type]
    amount = round(rng.uniform(lo, hi), 2)
    iban_country = {"nl": "NL", "de": "DE", "en": "NL"}[lang]
    iban = make_iban(rng, iban_country)
    ref = make_reference(rng)
    year = doc_date.year - 1

    subject = s[f"{doc_type}_subject"].format(ref=ref, year=year)
    body = s[f"{doc_type}_body"].format(year=year)
    doc_date_str = format_date(doc_date, lang, rng)
    due_date_str = format_date(due_date, lang, rng)
    amount_str = format_amount(amount, lang)
    sender_city_short = sender.city.split(" ", 1)[1] if lang != "en" else sender.city

    lines = [
        sender.name,
        sender.street,
        sender.city,
        "",
        recipient.name,
        recipient.street,
        recipient.city,
        "",
        f"{sender_city_short}, {s['date_prefix']}{doc_date_str}",
        "",
        f"{s['subject']}: {subject}",
        f"{s['reference']}: {ref}",
        "",
        s["salutation"],
        "",
        body,
        "",
        f"{s['amount_due']}: {amount_str}",
        f"{s['due_date']}: {due_date_str}",
        f"IBAN: {group_iban(iban)}",
        "",
        s["closing"],
        sender.name,
    ]
    text = "\n".join(lines)

    truth = {
        "letter_id": letter_id,
        "language": lang,
        "doc_type": doc_type,
        "sender_name": sender.name,
        "recipient_name": recipient.name,
        "document_date": doc_date.isoformat(),
        "due_date": due_date.isoformat(),
        "amount_due": f"{amount:.2f}",
        "currency": "EUR",
        "iban": iban,
        "reference": ref,
        "subject": subject,
        "controlled_tags": CONTROLLED_TAGS[doc_type],
        "full_text": text,
    }
    return Letter(letter_id=letter_id, lang=lang, doc_type=doc_type, text=text, truth=truth)
