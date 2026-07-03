"""VLM extraction (plan.md §6.4): image + OCR text → schema-constrained JSON.

Schema enforcement happens at the decoding layer — the Pydantic model's JSON
Schema is passed as Ollama's `format`, so the model *cannot* emit non-schema
output. Structural validity ≠ correct values: everything format-critical is
re-validated deterministically in validate.py afterwards.
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

DOC_TYPES = ["invoice", "government_tax", "insurance", "medical", "bank", "subscription", "other"]
CONTROLLED_VOCAB = [
    "bill", "insurance", "government", "bank", "medical", "subscription", "legal", "personal",
]


class LetterExtraction(BaseModel):
    """What the VLM must return for every letter.

    Every field is REQUIRED but nullable: with constrained decoding, an optional
    field lets the grammar skip the key entirely — and small models then omit
    fields that are plainly on the page (observed with the dates). Forcing every
    key makes the model decide null-vs-value per field.
    """

    doc_type: Literal[
        "invoice", "government_tax", "insurance", "medical", "bank", "subscription", "other"
    ] = Field(
        description="The SENDER'S DOMAIN decides, not whether money is requested: "
        "tax office/municipality assessment → government_tax; hospital/clinic/dentist "
        "(even a bill) → medical; insurer → insurance; bank → bank; telecom/utility "
        "recurring service → subscription; a general business invoice fitting none of "
        "the above → invoice"
    )
    language: Literal["nl", "de", "en", "other"] = Field(
        description="Language of the letter text"
    )
    sender_name: str | None
    recipient_name: str | None
    document_date: str | None = Field(description="Date on the letter, as printed")
    due_date: str | None = Field(description="Payment/response deadline, as printed")
    amount_due: str | None = Field(description="Amount to pay, as printed")
    iban: str | None = Field(description="IBAN exactly as printed")
    reference: str | None = Field(
        description="Reference / customer / invoice number — the identifier only, "
        "without label words like 'Kenmerk' or 'Factuur'"
    )
    subject: str | None
    tags: list[
        Literal[
            "bill", "insurance", "government", "bank", "medical",
            "subscription", "legal", "personal",
        ]
    ] = Field(
        max_length=2,
        description="The letter's domain tag (matching doc_type), plus 'bill' "
        "only if it requests a payment. Nothing speculative.",
    )


_PROMPT = """You are extracting metadata from a letter that arrived in the post.

Below is the OCR transcript of the letter (it may contain small character errors).
Trust it for exact strings: numbers, IBAN, references, amounts, dates.

OCR transcript:
---
{ocr_text}
---

Fill EVERY schema field from the letter. Copy dates, amounts and the IBAN exactly
as printed — do not reformat, translate or invent values. Look carefully for a
payment amount, a due/pay-by date and an IBAN; letters about money almost always
have them. Use null only for fields genuinely absent from the letter.
For doc_type, the sender's domain decides — a hospital bill is medical, a tax
assessment is government_tax, even though both ask for money.
For reference, give the bare identifier only (e.g. "525808631", never
"Factuur 525808631")."""


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
    benchmarking and for a later escalation path when OCR confidence is low.
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
