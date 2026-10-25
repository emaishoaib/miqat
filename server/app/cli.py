import argparse
import json
import os
import sys

import httpx

DEFAULT_SERVER_URL = "http://localhost:8000"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="python -m app.cli",
        description="Read and update mosque timetables on the Miqat server.",
    )
    commands = parser.add_subparsers(dest="command", required=True)

    nearby = commands.add_parser(
        "nearby", help="Mosques near a location, and which have times."
    )
    nearby.add_argument("latitude", type=float)
    nearby.add_argument("longitude", type=float)

    search = commands.add_parser("search", help="Mosques whose name contains text.")
    search.add_argument("text")

    mosque = commands.add_parser(
        "mosque", help="A mosque's details and the days it has times for."
    )
    mosque.add_argument("place_id")

    times = commands.add_parser(
        "times", help="A mosque's times for a range of days, today by default."
    )
    times.add_argument("place_id")
    times.add_argument("--from", dest="start", metavar="YYYY-MM-DD")
    times.add_argument("--to", dest="end", metavar="YYYY-MM-DD")

    needing = commands.add_parser(
        "needing", help="Mosques with no times or running low."
    )
    needing.add_argument("--days", type=int, metavar="N")

    upload = commands.add_parser(
        "upload", help="Save a mosque's times from a JSON file, or - for stdin."
    )
    upload.add_argument("place_id")
    upload.add_argument("file")

    return parser


def request(api: httpx.Client, args: argparse.Namespace) -> httpx.Response:
    match args.command:
        case "nearby":
            return api.get(
                "/admin/mosques/nearby",
                params={"latitude": args.latitude, "longitude": args.longitude},
            )
        case "search":
            return api.get("/admin/mosques", params={"search": args.text})
        case "mosque":
            return api.get(f"/admin/mosques/{args.place_id}")
        case "times":
            params = {"from": args.start, "to": args.end}
            return api.get(
                f"/admin/mosques/{args.place_id}/timetable",
                params={name: value for name, value in params.items() if value},
            )
        case "needing":
            params = {"days_ahead": args.days} if args.days is not None else {}
            return api.get("/admin/mosques/needing-times", params=params)
        case "upload":
            if args.file == "-":
                body = json.load(sys.stdin)
            else:
                with open(args.file) as file:
                    body = json.load(file)
            return api.put(f"/admin/mosques/{args.place_id}/timetable", json=body)
    raise ValueError(f"Unknown command {args.command}")


def main(
    argv: list[str] | None = None, transport: httpx.BaseTransport | None = None
) -> int:
    args = build_parser().parse_args(argv)
    token = os.environ.get("MIQAT_ADMIN_TOKEN")
    if not token:
        print("Set MIQAT_ADMIN_TOKEN to the server's admin token.", file=sys.stderr)
        return 1

    with httpx.Client(
        base_url=os.environ.get("MIQAT_SERVER_URL", DEFAULT_SERVER_URL),
        headers={"Authorization": f"Bearer {token}"},
        timeout=30,
        transport=transport,
    ) as api:
        response = request(api, args)

    body = response.json() if response.content else None
    output = sys.stderr if response.is_error else sys.stdout
    print(json.dumps(body, indent=2, ensure_ascii=False), file=output)
    return 1 if response.is_error else 0


if __name__ == "__main__":
    sys.exit(main())
