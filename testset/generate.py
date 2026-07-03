"""Generate the Phase 0 synthetic test set.

Usage:
    uv run python -m testset.generate [--count 30] [--seed 42] [--out data/testset]

Output layout (gitignored; regenerate with the same seed for the identical set):
    data/testset/clean/<id>.png     rendered page (flatbed baseline)
    data/testset/images/<id>.jpg    photo-degraded capture (what the pipeline sees)
    data/testset/truth/<id>.json    ground-truth metadata incl. full_text
    data/testset/manifest.json      run parameters + per-letter index
"""

from __future__ import annotations

import argparse
import json
import random
from pathlib import Path

from .degrade import TIERS, degrade
from .render import render_letter
from .templates import DOC_TYPES, LANGUAGES, compose


def generate(count: int, seed: int, out_dir: Path) -> list[dict]:
    rng = random.Random(seed)
    index = []
    for i in range(count):
        lang = LANGUAGES[i % len(LANGUAGES)]
        doc_type = DOC_TYPES[(i // len(LANGUAGES)) % len(DOC_TYPES)]
        tier = TIERS[i % len(TIERS)]
        letter_id = f"{i:03d}_{lang}_{doc_type}_{tier}"

        letter = compose(rng, letter_id, lang, doc_type)
        clean_path = out_dir / "clean" / f"{letter_id}.png"
        image_path = out_dir / "images" / f"{letter_id}.jpg"
        truth_path = out_dir / "truth" / f"{letter_id}.json"

        render_letter(letter.text, clean_path)
        degrade(clean_path, image_path, tier, rng)
        truth_path.parent.mkdir(parents=True, exist_ok=True)
        truth_path.write_text(json.dumps(letter.truth, ensure_ascii=False, indent=2))

        index.append({"letter_id": letter_id, "lang": lang, "doc_type": doc_type, "tier": tier})
    return index


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--count", type=int, default=30)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--out", type=Path, default=Path("data/testset"))
    args = parser.parse_args()

    index = generate(args.count, args.seed, args.out)
    manifest = {"count": args.count, "seed": args.seed, "letters": index}
    (args.out / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2))
    print(f"generated {len(index)} letters in {args.out}/ (seed={args.seed})")


if __name__ == "__main__":
    main()
