"""Collect reproducible, public network context without treating it as claims data.

The script downloads two official INT reports, records cryptographic provenance,
publishes a small set of manually verified report metrics, and takes a public
RIPE Atlas probe snapshot for Tunisia. RIPE Atlas probes are a volunteer
convenience sample; their counts are not operator market share or outage rates.
"""

from __future__ import annotations

import csv
import hashlib
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import requests

try:
    import truststore

    truststore.inject_into_ssl()
except ImportError:
    pass


ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw" / "network"
PUBLIC = ROOT / "artifacts" / "public"
COLLECTED_AT = datetime.now(timezone.utc).replace(microsecond=0).isoformat()

SOURCES = [
    {
        "source_id": "int_mobile_qos_2019",
        "publisher": "Instance Nationale des Telecommunications (INT)",
        "title": "Rapport d'evaluation de la QoS data mobile - Grand Tunis",
        "report_year": 2019,
        "geography": "Grand Tunis",
        "access_type": "Mobile 3G/4G",
        "filename": "int-mobile-qos-grand-tunis-2019.pdf",
        "url": "https://www.intt.tn/upload/files/Rapport_final_campagne_QoS_mobile_GT_2019_Version_Finale.pdf",
    },
    {
        "source_id": "int_fixed_qos_2020",
        "publisher": "Instance Nationale des Telecommunications (INT)",
        "title": "Evaluation de la QoS Internet fixe - Rapport de synthese 2020",
        "report_year": 2020,
        "geography": "24 governorates",
        "access_type": "Fixed ADSL 8 Mbps",
        "filename": "int-fixed-internet-qos-2020.pdf",
        "url": "https://www.intt.tn/upload/files/QoS%20Internet%202020%20Final.pdf",
    },
]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def download_sources(session: requests.Session) -> list[dict[str, Any]]:
    RAW.mkdir(parents=True, exist_ok=True)
    rows: list[dict[str, Any]] = []
    for source in SOURCES:
        target = RAW / source["filename"]
        response = session.get(source["url"], timeout=90)
        response.raise_for_status()
        target.write_bytes(response.content)
        rows.append(
            {
                **{key: value for key, value in source.items() if key != "filename"},
                "local_filename": source["filename"],
                "bytes": target.stat().st_size,
                "sha256": sha256(target),
                "collected_at_utc": COLLECTED_AT,
                "public_role": "Context only; not joined to firm-level WBES records.",
            }
        )
    return rows


def write_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    if not rows:
        raise ValueError(f"No rows available for {path.name}")
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def collect_ripe_atlas(session: requests.Session) -> list[dict[str, Any]]:
    endpoint = "https://atlas.ripe.net/api/v2/probes/"
    response = session.get(
        endpoint,
        params={"country_code": "TN", "page_size": 500},
        timeout=60,
    )
    response.raise_for_status()
    probes = response.json()["results"]
    grouped: dict[int | None, dict[str, int]] = defaultdict(lambda: {"observed": 0, "connected": 0})
    for probe in probes:
        asn = probe.get("asn_v4") or probe.get("asn_v6")
        grouped[asn]["observed"] += 1
        if (probe.get("status") or {}).get("id") == 1:
            grouped[asn]["connected"] += 1

    rows: list[dict[str, Any]] = []
    for asn, counts in sorted(grouped.items(), key=lambda item: item[1]["observed"], reverse=True):
        if asn is None:
            holder = "ASN unavailable"
        else:
            overview = session.get(
                "https://stat.ripe.net/data/as-overview/data.json",
                params={"resource": f"AS{asn}"},
                timeout=30,
            )
            overview.raise_for_status()
            holder = overview.json().get("data", {}).get("holder") or "Holder unavailable"
        rows.append(
            {
                "asn": "" if asn is None else asn,
                "asn_holder": holder,
                "observed_public_probes": counts["observed"],
                "connected_public_probes": counts["connected"],
                "country_code": "TN",
                "snapshot_at_utc": COLLECTED_AT,
                "source_url": "https://atlas.ripe.net/api/v2/probes/?country_code=TN&page_size=500",
                "interpretation": "Volunteer measurement footprint; not market share, QoS ranking or outage frequency.",
            }
        )
    return rows


def main() -> None:
    session = requests.Session()
    session.headers.update({"User-Agent": "tunisia-internet-risk-research/0.1"})
    manifest = download_sources(session)
    write_csv(PUBLIC / "network_source_manifest.csv", manifest)

    qos_rows = [
        {
            "report_id": "int_fixed_qos_2020",
            "metric": "Download throughput",
            "value": 6.59,
            "unit": "Mbps",
            "scope": "National mean; all five ISPs; 8 Mbps ADSL",
            "reported_assessment": "Good",
            "table_reference": "Table 2",
        },
        {
            "report_id": "int_fixed_qos_2020",
            "metric": "Upload throughput",
            "value": 0.83,
            "unit": "Mbps",
            "scope": "National mean; all five ISPs; 8 Mbps ADSL",
            "reported_assessment": "Good",
            "table_reference": "Table 2",
        },
        {
            "report_id": "int_fixed_qos_2020",
            "metric": "Network latency",
            "value": 41.31,
            "unit": "ms",
            "scope": "National mean; all five ISPs; 8 Mbps ADSL",
            "reported_assessment": "Within threshold",
            "table_reference": "Table 2",
        },
        {
            "report_id": "int_fixed_qos_2020",
            "metric": "DNS resolution time",
            "value": 62.80,
            "unit": "ms",
            "scope": "National mean; all five ISPs; 8 Mbps ADSL",
            "reported_assessment": "Within threshold",
            "table_reference": "Table 2",
        },
        {
            "report_id": "int_fixed_qos_2020",
            "metric": "Access availability",
            "value": 98.62,
            "unit": "%",
            "scope": "National mean; all five ISPs; 8 Mbps ADSL",
            "reported_assessment": "Within 98% threshold",
            "table_reference": "Table 2",
        },
        {
            "report_id": "int_fixed_qos_2020",
            "metric": "VoIP packet-loss rate",
            "value": 0.023,
            "unit": "ratio",
            "scope": "National mean; all five ISPs; 8 Mbps ADSL",
            "reported_assessment": "Outside threshold",
            "table_reference": "Table 2",
        },
    ]
    write_csv(PUBLIC / "int_qos_benchmark.csv", qos_rows)

    operator_scope = [
        {
            "operator": "Tunisie Telecom",
            "measurement_attempts": 3723,
            "campaign": "INT mobile data QoS 2019",
            "geography": "Grand Tunis",
            "technologies": "3G/4G",
            "indicators": "download/upload success; throughput; latency",
            "source_table": "Table 5",
            "interpretation": "Campaign coverage count, not an outage or quality ranking.",
        },
        {
            "operator": "Ooredoo Tunisia",
            "measurement_attempts": 4011,
            "campaign": "INT mobile data QoS 2019",
            "geography": "Grand Tunis",
            "technologies": "3G/4G",
            "indicators": "download/upload success; throughput; latency",
            "source_table": "Table 5",
            "interpretation": "Campaign coverage count, not an outage or quality ranking.",
        },
        {
            "operator": "Orange Tunisia",
            "measurement_attempts": 3667,
            "campaign": "INT mobile data QoS 2019",
            "geography": "Grand Tunis",
            "technologies": "3G/4G",
            "indicators": "download/upload success; throughput; latency",
            "source_table": "Table 5",
            "interpretation": "Campaign coverage count, not an outage or quality ranking.",
        },
    ]
    write_csv(PUBLIC / "int_mobile_campaign_scope.csv", operator_scope)
    write_csv(PUBLIC / "ripe_atlas_probe_snapshot.csv", collect_ripe_atlas(session))
    print("Public network context and provenance written to artifacts/public.")


if __name__ == "__main__":
    main()
