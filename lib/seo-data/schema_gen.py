#!/usr/bin/env python3
"""Deterministic JSON-LD generators for four Schema.org types. Stdlib only.

Adapted from claude-seo (github.com/AgriciDaniel/claude-seo, MIT),
schema_generate.py — rewritten to the lib/seo-data fail-open contract.

Everywhere else in this repo we AUDIT existing markup (google_seo.py
`inspect`, geo-analyzer's JSON-LD rules); this is the one verb that
GENERATES it. Reservation + potentialAction matter now that AI Mode
executes restaurant reservations; DiscussionForumPosting is a live SERP
feature; ProfilePage with sameAs/knowsAbout is the cheapest entity-graph
builder for AI citation correlation. geo-analyzer's G2 batch calls this
instead of hand-writing the markup — it only generates STRUCTURE, unknown
field VALUES stay the caller's `[À COMPLÉTER]` placeholder, never invented
here.
"""
import argparse, json


def reservation(provider, start, *, end=None, party_size=None,
                 reservation_id=None, reservation_for_name=None,
                 customer_name=None, customer_email=None,
                 kind="FoodEstablishmentReservation"):
    """Reservation JSON-LD block. Defaults to FoodEstablishment."""
    payload = {
        "@context": "https://schema.org",
        "@type": kind,
        "reservationStatus": "https://schema.org/ReservationConfirmed",
        "provider": {"@type": "Organization", "name": provider},
        "reservationFor": {
            "@type": "FoodEstablishment"
                     if kind == "FoodEstablishmentReservation" else "Place",
            "name": reservation_for_name or provider,
        },
        "startTime": start,
        "endTime": end,
        "partySize": party_size,
        "reservationId": reservation_id,
    }
    if customer_name or customer_email:
        payload["underName"] = {"@type": "Person", "name": customer_name,
                                 "email": customer_email}
    return payload


def order_action(merchant, *, order_url, name="Order online",
                  accepted_payment_method=None, delivery_method=None):
    """OrderAction potentialAction block. Attach to a Product/Service via
    {"@type": "Product", "potentialAction": <this dict>}."""
    payload = {
        "@context": "https://schema.org",
        "@type": "OrderAction",
        "name": name,
        "target": {
            "@type": "EntryPoint",
            "urlTemplate": order_url,
            "inLanguage": "en-US",
            "actionPlatform": [
                "https://schema.org/DesktopWebPlatform",
                "https://schema.org/MobileWebPlatform",
            ],
        },
        "deliveryMethod": delivery_method or [
            "https://schema.org/OnSitePickup",
            "https://schema.org/ParcelService",
        ],
        "priceSpecification": {
            "@type": "PriceSpecification",
            "eligibleTransactionVolume": {
                "@type": "PriceSpecification",
                "minPrice": 0,
                "priceCurrency": "USD",
            },
        },
        "merchant": {"@type": "Organization", "name": merchant},
    }
    if accepted_payment_method:
        payload["acceptedPaymentMethod"] = [
            {"@type": "PaymentMethod", "name": m}
            for m in accepted_payment_method
        ]
    return payload


def discussion(headline, author, *, url, date_published, text=None,
               date_modified=None, interaction_count=None,
               comment_count=None):
    """DiscussionForumPosting JSON-LD block."""
    payload = {
        "@context": "https://schema.org",
        "@type": "DiscussionForumPosting",
        "headline": headline,
        "author": {"@type": "Person", "name": author},
        "datePublished": date_published,
        "dateModified": date_modified,
        "url": url,
        "mainEntityOfPage": {"@type": "WebPage", "@id": url},
        "text": text,
        "commentCount": comment_count,
    }
    if interaction_count:
        payload["interactionStatistic"] = [
            {"@type": "InteractionCounter",
             "interactionType": "https://schema.org/%s" % k,
             "userInteractionCount": v}
            for k, v in interaction_count.items()
        ]
    return payload


def profile(name, *, url, description=None, same_as=None, knows_about=None,
            works_for=None, image=None, job_title=None):
    """ProfilePage JSON-LD block. sameAs + knowsAbout is the entity-graph
    helper for AI citation correlation — Wikipedia/GitHub/LinkedIn/ORCID
    URLs in sameAs disambiguate the person across knowledge graphs."""
    person = {
        "@type": "Person",
        "name": name,
        "url": url,
        "description": description,
        "sameAs": list(same_as) if same_as else None,
        "knowsAbout": list(knows_about) if knows_about else None,
        "worksFor": {"@type": "Organization", "name": works_for}
                    if works_for else None,
        "image": image,
        "jobTitle": job_title,
    }
    return {"@context": "https://schema.org", "@type": "ProfilePage",
            "mainEntity": person, "url": url}


def _strip_nones(value):
    """Recursively drop dict keys AND list elements whose value is None —
    the emitted JSON-LD must never contain a null."""
    if isinstance(value, dict):
        return {k: _strip_nones(v) for k, v in value.items() if v is not None}
    if isinstance(value, list):
        return [_strip_nones(v) for v in value if v is not None]
    return value


def _need(value, field):
    """Raise on a schema-required field that is present but empty — the
    case argparse's `required=True` cannot catch (an empty string is a
    given flag, not a missing one)."""
    if value is None or not str(value).strip():
        raise ValueError("missing required field: %s" % field)
    return value


def _generate(kind, args):
    """Route to the matching generator, enforcing schema-required fields."""
    if kind == "reservation":
        return reservation(
            _need(args.provider, "provider"), _need(args.start, "start"),
            end=args.end, party_size=args.party_size,
            reservation_id=args.reservation_id,
            reservation_for_name=args.reservation_for_name,
            customer_name=args.customer_name,
            customer_email=args.customer_email, kind=args.reservation_kind,
        )
    if kind == "order":
        return order_action(
            _need(args.merchant, "merchant"),
            order_url=_need(args.order_url, "order_url"), name=args.name,
            accepted_payment_method=args.accepted_payment_method,
            delivery_method=args.delivery_method,
        )
    if kind == "discussion":
        interaction = {"LikeAction": args.likes} if args.likes else None
        return discussion(
            _need(args.headline, "headline"), _need(args.author, "author"),
            url=_need(args.url, "url"),
            date_published=_need(args.date_published, "date_published"),
            text=args.text, date_modified=args.date_modified,
            interaction_count=interaction, comment_count=args.comment_count,
        )
    if kind == "profile":
        return profile(
            _need(args.name, "name"), url=_need(args.url, "url"),
            description=args.description, same_as=args.same_as,
            knows_about=args.knows_about, works_for=args.works_for,
            image=args.image, job_title=args.job_title,
        )
    raise ValueError("unknown kind: %r" % kind)  # pragma: no cover — argparse


def _envelope(payload, script_tag):
    cleaned = _strip_nones(payload)
    out = {"status": "ok", "source": "schema_gen",
           "type": cleaned.get("@type"), "jsonld": cleaned}
    if script_tag:
        pretty = json.dumps(cleaned, indent=2, ensure_ascii=False)
        out["script"] = ('<script type="application/ld+json">\n%s\n</script>'
                          % pretty)
    return out


def _script_tag_parent():
    """`--script-tag` as a shared parent parser, so it is valid on every
    subcommand — `fetch.sh schema_gen <type> [flags]` puts the type FIRST,
    and argparse only accepts a flag after a subcommand token if that flag
    was declared on the subparser, not the top-level one."""
    parent = argparse.ArgumentParser(add_help=False)
    parent.add_argument(
        "--script-tag", action="store_true",
        help="Wrap jsonld in <script type=application/ld+json>.",
    )
    return parent


def _add_reservation_args(sub, parents):
    p = sub.add_parser("reservation", parents=parents,
                        help="FoodEstablishmentReservation et al.")
    p.add_argument("--provider", required=True)
    p.add_argument("--start", required=True, help="ISO 8601 startTime.")
    p.add_argument("--end")
    p.add_argument("--party-size", type=int)
    p.add_argument("--reservation-id")
    p.add_argument("--reservation-for-name")
    p.add_argument("--customer-name")
    p.add_argument("--customer-email")
    p.add_argument(
        "--reservation-kind", dest="reservation_kind",
        default="FoodEstablishmentReservation",
        choices=(
            "FoodEstablishmentReservation", "LodgingReservation",
            "RentalCarReservation", "TaxiReservation", "EventReservation",
            "TrainReservation", "FlightReservation",
        ),
    )


def _add_order_args(sub, parents):
    p = sub.add_parser("order", parents=parents,
                        help="OrderAction (potentialAction).")
    p.add_argument("--merchant", required=True)
    p.add_argument("--order-url", required=True)
    p.add_argument("--name", default="Order online")
    p.add_argument("--accepted-payment-method", nargs="*", default=None)
    p.add_argument("--delivery-method", nargs="*", default=None)


def _add_discussion_args(sub, parents):
    p = sub.add_parser("discussion", parents=parents,
                        help="DiscussionForumPosting.")
    p.add_argument("--headline", required=True)
    p.add_argument("--author", required=True)
    p.add_argument("--url", required=True)
    p.add_argument("--date", dest="date_published", required=True)
    p.add_argument("--text")
    p.add_argument("--date-modified")
    p.add_argument("--comment-count", type=int)
    p.add_argument("--likes", type=int, default=None,
                   help="LikeAction count (interactionStatistic).")


def _add_profile_args(sub, parents):
    p = sub.add_parser("profile", parents=parents,
                        help="ProfilePage with sameAs / knowsAbout.")
    p.add_argument("--name", required=True)
    p.add_argument("--url", required=True)
    p.add_argument("--description")
    p.add_argument("--same-as", nargs="*", default=None)
    p.add_argument("--knows-about", nargs="*", default=None)
    p.add_argument("--works-for")
    p.add_argument("--image")
    p.add_argument("--job-title")


def _build_parser():
    p = argparse.ArgumentParser(
        description="Schema.org JSON-LD generators (stdlib, deterministic)."
    )
    p.add_argument("--store", default=None)  # accepted+ignored (dispatch)
    sub = p.add_subparsers(dest="kind", required=True)
    parents = [_script_tag_parent()]
    _add_reservation_args(sub, parents)
    _add_order_args(sub, parents)
    _add_discussion_args(sub, parents)
    _add_profile_args(sub, parents)
    return p


def _cli():
    try:
        args = _build_parser().parse_args()
        payload = _generate(args.kind, args)
        print(json.dumps(_envelope(payload, args.script_tag), indent=2))
    except SystemExit as e:
        if e.code not in (0, None):
            print(json.dumps({"status": "error", "reason": "bad_usage"}))
        raise
    except Exception as e:
        # Fail-open: a missing required field or any other unexpected error
        # is a normal outcome here, never a traceback or empty stdout.
        print(json.dumps({"status": "degraded", "reason": str(e)}))


if __name__ == "__main__":
    _cli()
