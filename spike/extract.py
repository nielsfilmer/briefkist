"""VLM extraction (plan.md §6.4, amended by decision log v0.4): OCR text →
schema-constrained archive metadata.

Schema enforcement happens at the decoding layer — the Pydantic model's JSON
Schema is passed as Ollama's `format`, so the model *cannot* emit non-schema
output. Structural validity ≠ correct values: format-critical fields (dates)
are still re-validated deterministically in validate.py afterwards.

This is a pure snail-mail ARCHIVE, not an invoicing tool (decision log v0.4):
no financial fields. The metadata exists so a letter can be found again years
later — hence the summary and curated keywords.
"""

from __future__ import annotations

import base64
import io
import time
from pathlib import Path
from typing import Literal

import httpx
from PIL import Image
from pydantic import BaseModel, Field

OLLAMA_URL = "http://127.0.0.1:11434"
# The bare `qwen3-vl:4b` tag is the *thinking* variant: it burns thousands of
# reasoning tokens before the schema-constrained answer (observed: 12k chars of
# thinking, done_reason=length, empty content). Extraction is mechanical — use
# the instruct variant.
DEFAULT_MODEL = "qwen3-vl:4b-instruct"

CATEGORIES = [
    "government", "medical", "insurance", "bank", "utility", "telecom",
    "legal", "employment", "education", "housing", "commercial",
    "membership", "personal", "other",
]


class LetterExtraction(BaseModel):
    """Archive metadata the VLM must return for every letter.

    Every field is REQUIRED but nullable where sensible: with constrained
    decoding, an optional field lets the grammar skip the key entirely — and
    small models then omit fields that are plainly on the page. Forcing every
    key makes the model decide null-vs-value per field.
    """

    category: Literal[
        "government", "medical", "insurance", "bank", "utility", "telecom",
        "legal", "employment", "education", "housing", "commercial",
        "membership", "personal", "other",
    ] = Field(
        description="The SENDER'S DOMAIN decides: tax office/municipality → "
        "government; hospital/clinic/dentist → medical; insurer → insurance; "
        "bank → bank; energy/water → utility; phone/internet → telecom; "
        "lawyer/court/notary → legal; employer/pension fund → employment; "
        "school/university → education; landlord/housing corporation → "
        "housing; a business selling or billing something (including "
        "accountants, tax advisers, shops, contractors) → commercial; "
        "club/association → membership; a private person → personal. "
        "The sender's own business decides, not the letter's topic — a tax "
        "adviser writing about taxes is commercial, not government."
    )
    language: Literal["nl", "de", "en", "other"] = Field(
        description="Language of the letter text"
    )
    sender_name: str | None
    sender_place: str | None = Field(
        description="The sender's city/town name ONLY (e.g. 'Utrecht') — "
        "no street, no postcode"
    )
    recipient_name: str | None
    document_date: str | None = Field(description="Date on the letter, as printed")
    reference: str | None = Field(
        description="Reference / dossier / customer number — the identifier "
        "only, without label words like 'Kenmerk' or 'Betreft'"
    )
    subject: str | None
    summary: str = Field(
        description="2-4 sentences, in the letter's own language, saying who "
        "sent it, what it is, and what it says or asks. Written so the letter "
        "can be recognized from the summary alone years later."
    )
    keywords: list[str] = Field(
        max_length=8,
        description="3-8 specific, salient search terms someone would type to "
        "find this letter later: organizations, people, topics, case names, "
        "years. Specific beats generic — never filler like 'letter', "
        "'document' or 'post', and never raw numbers such as amounts, IBANs, "
        "account or phone numbers: nobody searches an archive by those.",
    )


_PROMPT = """You are extracting archive metadata from a letter that arrived in the post.

Below is the OCR transcript of the letter (it may contain small character errors).
Trust it for exact strings: names, references, dates.

OCR transcript:
---
{ocr_text}
---

Fill EVERY schema field from the letter. Copy dates and references exactly as
printed — do not reformat, translate or invent values. Use null only for fields
genuinely absent. Rules:
- category follows the SENDER'S OWN BUSINESS, not the letter's topic: a tax
  adviser or accountant writing about taxes is commercial, not government; a
  hospital bill is medical. Pick from the schema's category list.
- sender_place is the sender's city/town name ONLY (e.g. "Utrecht") — no
  street, no postcode.
- reference is the bare identifier only, without label words.
- summary: 2-4 sentences in the letter's own language saying who sent it, what
  it is, and what it says or asks — so the letter is recognizable from the
  summary alone years later.
- keywords: 3-8 specific search terms someone would type to find this letter
  later: organizations, people, topics, case names, years. NEVER raw numbers
  (amounts, IBANs, account or phone numbers), NEVER plain dates or postcodes,
  NEVER filler like "letter" or "document"."""


def _image_b64(image_path: Path, max_side: int) -> str:
    """Downscale for the VLM: vision tokens (and encode time) scale with pixels,
    and exact strings come from the OCR layer anyway (plan.md §6.4). ~1280 px on
    the long side keeps letter layout + logos readable at a fraction of the cost."""
    img = Image.open(image_path)
    if max(img.size) > max_side:
        img.thumbnail((max_side, max_side), Image.LANCZOS)
    buf = io.BytesIO()
    img.convert("RGB").save(buf, "JPEG", quality=90)
    return base64.b64encode(buf.getvalue()).decode()


def extract(
    image_path: Path,
    ocr_text: str,
    model: str = DEFAULT_MODEL,
    timeout: float = 300.0,
    max_image_side: int = 1280,
    use_image: bool = False,
) -> tuple[LetterExtraction, dict]:
    """Run one extraction. Returns (parsed result, timing/token stats).

    Spike finding (2026-07-03, qwen3-vl:4b-instruct on the 8 GB M1): attaching
    the page image DEGRADED structured extraction (fields the OCR text plainly
    contains came back null) and added ~50 s of vision encode per page. Default
    is therefore text-only over the OCR transcript; `use_image=True` remains for
    benchmarking and for a later escalation path when OCR quality is low.
    """
    message: dict = {"role": "user", "content": _PROMPT.format(ocr_text=ocr_text)}
    if use_image:
        message["images"] = [_image_b64(image_path, max_image_side)]
    start = time.perf_counter()
    response = httpx.post(
        f"{OLLAMA_URL}/api/chat",
        json={
            "model": model,
            "stream": False,
            # the bare qwen3-vl tags are thinking models; with constrained decoding
            # the thinking budget starves the answer (observed: 12k chars of
            # thinking, then done_reason=length with empty content). Belt and
            # suspenders: instruct variant AND think off.
            "think": False,
            "format": LetterExtraction.model_json_schema(),
            # num_ctx stays at 4096: on the 8 GB host a larger KV cache spills out
            # of the ~5.3 GiB Metal budget and generation collapses to ~1.4 tok/s
            # (measured; 13+ tok/s at 4096). Text-only prompts fit comfortably.
            "options": {"temperature": 0, "num_ctx": 4096, "num_predict": 1024},
            "messages": [message],
        },
        timeout=timeout,
    )
    response.raise_for_status()
    payload = response.json()
    parsed = LetterExtraction.model_validate_json(payload["message"]["content"])
    stats = {
        "seconds": round(time.perf_counter() - start, 2),
        "model": model,
        "prompt_tokens": payload.get("prompt_eval_count"),
        "output_tokens": payload.get("eval_count"),
        "load_seconds": round(payload.get("load_duration", 0) / 1e9, 2),
    }
    return parsed, stats
