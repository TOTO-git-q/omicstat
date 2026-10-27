"""Deterministic local CLI; daily collection does not call an LLM.

Curator-only commands (promote, demote, list-reviews, domain-*) exist only
here, never as MCP tools; run them through ``docker exec`` on GT103.
"""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import sys
import service


def _curation_call(fn, *args, **kwargs) -> dict:
    return service.invoke(fn, *args, **kwargs)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("status")
    daily = sub.add_parser("harvest")
    daily.add_argument("--target", type=int, default=10, choices=range(1, 11))
    daily.add_argument("--transport", default="gt103", choices=("gt103", "direct"))
    daily.add_argument("--max-requests", type=int, default=60)
    search = sub.add_parser("search")
    search.add_argument("query", nargs="?", default="")
    search.add_argument("--module")
    search.add_argument("--limit", type=int, default=10)
    search.add_argument("--offset", type=int, default=0)
    search.add_argument("--no-discovery", action="store_true")
    candidates = sub.add_parser("candidates")
    candidates.add_argument("--module")
    candidates.add_argument("--limit", type=int, default=10)
    candidates.add_argument("--offset", type=int, default=0)
    candidates.add_argument("--include-legacy", action="store_true")
    advice = sub.add_parser("advise")
    advice.add_argument("module")
    advice.add_argument("--contract", type=Path, required=True)
    promote = sub.add_parser("promote", help="curator: promote a review proposal of a screened candidate")
    promote.add_argument("--review-id", required=True)
    promote.add_argument("--curator", required=True)
    promote.add_argument("--note")
    demote = sub.add_parser("demote", help="curator: mark a reviewed_supplement record invalid (kept, not deleted)")
    demote.add_argument("--supplement-id", required=True)
    demote.add_argument("--reason", required=True)
    demote.add_argument("--curator")
    reviews = sub.add_parser("list-reviews", help="list review proposals and their promotion state")
    reviews.add_argument("--pending", action="store_true")
    domains = sub.add_parser("domain-list", help="list domain proposals")
    domains.add_argument("--status")
    accept = sub.add_parser("domain-accept", help="curator: accept a knowledge_domain/method_family proposal")
    accept.add_argument("--id", required=True)
    accept.add_argument("--curator", required=True)
    accept.add_argument("--discovery-profile", type=Path, help="JSON profile; must pass a live validation probe to join rotation")
    ack = sub.add_parser("domain-ack", help="curator: acknowledge an analysis_module_request into the engineering backlog")
    ack.add_argument("--id", required=True)
    ack.add_argument("--curator", required=True)
    ack.add_argument("--note")
    backup = sub.add_parser("backup", help="write a timestamped tar of the data directory to <data>/backups")
    backup.add_argument("--label", default="manual")
    reconcile = sub.add_parser("map-reconcile", help="curator: rebind the stored method-map state to the current method_map.json after a non-extending change")
    reconcile.add_argument("--to-module", required=True, help="module at which the rotation continues")
    reconcile.add_argument("--confirm", action="store_true", help="apply; without it only the plan is printed")
    probe = sub.add_parser("probe", help="coverage probe (Europe PMC hitCounts only, <= 400 requests/month); the worker runs it automatically")
    probe.add_argument("--dry-run", action="store_true", help="show the plan; no request is sent")
    probe.add_argument("--until-done", action="store_true", help="repeat chunks until the month's plan or budget is finished")
    probe.add_argument("--max-requests", type=int, default=60, choices=range(1, 401), metavar="1..400")
    requests = sub.add_parser("request-status", help="show one literature request")
    requests.add_argument("request_id")
    args = parser.parse_args()
    if args.command == "status":
        result = service.invoke(service.status)
    elif args.command == "harvest":
        if (service.ROOT / "REMOTE_DEPLOYED.json").exists() and os.environ.get("OMICSTAT_REFERENCE_DEPLOYMENT") != "gt103-docker":
            print(json.dumps(service.fail("remote_authoritative", "The active reference store and worker are on GT103 Docker. Do not fork daily collection into the archived local database. Use the registered reference MCP or remote docker exec.")))
            return 1
        from harvest import harvest_daily
        result = service.invoke(harvest_daily, service.harvest_store(), target=args.target,
                                transport=args.transport, seed_catalog=service.SEED,
                                max_requests=args.max_requests)
    elif args.command == "search":
        result = service.invoke(service.search, args.query, args.module, args.limit, args.offset, not args.no_discovery)
    elif args.command == "candidates":
        result = service.invoke(service.list_candidates, args.module, args.limit, args.offset, args.include_legacy)
    elif args.command in {"promote", "demote", "list-reviews", "domain-list", "domain-accept", "domain-ack"}:
        import curation
        data = service.data_dir()
        if args.command == "promote":
            result = _curation_call(curation.promote, data, service.harvest_store(), review_id=args.review_id, curator=args.curator, note=args.note)
        elif args.command == "demote":
            result = _curation_call(curation.demote, data, supplement_id=args.supplement_id, reason=args.reason, curator=args.curator)
        elif args.command == "list-reviews":
            result = _curation_call(curation.list_reviews, data, service.harvest_store(), pending_only=args.pending)
        elif args.command == "domain-list":
            result = _curation_call(curation.list_domains, data, args.status)
        elif args.command == "domain-accept":
            profile = None
            if args.discovery_profile is not None:
                try:
                    if args.discovery_profile.stat().st_size > 20000:
                        raise ValueError("discovery profile exceeds 20000 bytes")
                    profile = json.loads(args.discovery_profile.read_text(encoding="utf-8-sig"))
                except (OSError, ValueError) as exc:
                    result = service.fail("invalid_profile", str(exc)[:1000])
                    sys.stdout.reconfigure(encoding="utf-8")
                    print(json.dumps(result, ensure_ascii=False, indent=2))
                    return 1
            result = _curation_call(curation.domain_accept, data, service.harvest_store(), proposal_id=args.id, curator=args.curator, profile=profile)
        else:
            result = _curation_call(curation.domain_ack, data, proposal_id=args.id, curator=args.curator, note=args.note)
    elif args.command == "map-reconcile":
        import discovery
        from harvest import HarvestError, _load_method_map

        def _map_reconcile() -> dict:
            method_map = _load_method_map()
            if set(discovery.load_profiles()["profiles"]) != set(method_map["order"]):
                raise HarvestError("method_map_profile_mismatch", "Method map and discovery profiles must name the same modules")
            return service.harvest_store().reconcile_method_map(method_map, args.to_module, confirm=args.confirm)
        result = service.invoke(_map_reconcile)
    elif args.command == "probe":
        import probe as probe_module

        def _probe() -> dict:
            if args.until_done and not args.dry_run:
                return probe_module.run_to_completion(service.harvest_store(), max_requests=args.max_requests)
            return probe_module.run_probe(service.harvest_store(), max_requests=args.max_requests, dry_run=args.dry_run)
        result = service.invoke(_probe)
    elif args.command == "backup":
        from backup import backup_data_dir
        result = service.invoke(lambda: {"backup": str(backup_data_dir(service.data_dir(), args.label))})
    elif args.command == "request-status":
        result = service.invoke(service.request_status, args.request_id)
    else:
        try:
            if args.contract.stat().st_size > 100000:
                raise ValueError("contract exceeds 100000 bytes")
            contract = json.loads(args.contract.read_text(encoding="utf-8-sig"))
            result = service.invoke(lambda: service.core().advise(args.module, contract))
        except (OSError, ValueError) as exc:
            result = service.fail("invalid_contract", str(exc)[:1000])
    sys.stdout.reconfigure(encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2, allow_nan=False))
    return 1 if result.get("error") else 0


if __name__ == "__main__":
    raise SystemExit(main())
