"""Device-token management CLI (see auth.py).

    uv run python -m server.tokens_cli add "niels-iphone"
    uv run python -m server.tokens_cli list
    uv run python -m server.tokens_cli revoke "niels-iphone"
"""

from __future__ import annotations

import argparse

from . import auth


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)
    p_add = sub.add_parser("add")
    p_add.add_argument("name")
    p_rev = sub.add_parser("revoke")
    p_rev.add_argument("name")
    sub.add_parser("list")
    args = parser.parse_args()

    if args.cmd == "add":
        token = auth.add_device(args.name)
        print(f"device {args.name!r} added; token (store it in the app, shown once):")
        print(token)
    elif args.cmd == "revoke":
        print("revoked" if auth.revoke_device(args.name) else "no such device")
    else:
        for name in auth.list_devices():
            print(name)


if __name__ == "__main__":
    main()
