"""
SES inbound email forwarder.

Triggered by an SES receipt rule. Reads the raw email from S3 (stored by the
preceding S3 action in the same rule), rewrites the From/To/Reply-To headers,
and re-sends via SES to the configured destination address.

Environment variables:
  FORWARDING_MAP   JSON object mapping lower-case local-part → destination email.
                   Use "*" as a catch-all key.
                   Example: {"infrastructure":"me@gmail.com","felipefuhrdosreis":"me@gmail.com"}
  FROM_EMAIL       SES-verified sender address used for the forwarded message.
  EMAIL_BUCKET     S3 bucket where SES stores raw emails.
  EMAIL_KEY_PREFIX S3 key prefix (no trailing slash). Default: "emails".
"""

import boto3
import copy
import email
import json
import logging
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

FORWARDING_MAP: dict = json.loads(os.environ["FORWARDING_MAP"])
FROM_EMAIL: str = os.environ["FROM_EMAIL"]
EMAIL_BUCKET: str = os.environ["EMAIL_BUCKET"]
EMAIL_KEY_PREFIX: str = os.environ.get("EMAIL_KEY_PREFIX", "emails")

s3 = boto3.client("s3")
ses = boto3.client("ses")

# Headers that must be removed before re-sending to avoid delivery failures.
_STRIP_HEADERS = [
    "DKIM-Signature",
    "DomainKey-Signature",
    "Received",
    "Return-Path",
    "Sender",
    "Message-ID",
]


def _forward(raw: bytes, recipient: str) -> None:
    local_part = recipient.split("@")[0].lower()
    destination = FORWARDING_MAP.get(local_part) or FORWARDING_MAP.get("*")

    if not destination:
        logger.warning("No forwarding rule for %s — skipping", recipient)
        return

    msg = email.message_from_bytes(raw)
    original_from = msg.get("From", recipient)

    # Work on a fresh copy so multiple recipients don't see mutated headers.
    fwd = copy.deepcopy(msg)

    for hdr in _STRIP_HEADERS + ["From", "To", "Cc", "Reply-To"]:
        while hdr in fwd:
            del fwd[hdr]

    fwd["From"] = FROM_EMAIL
    fwd["To"] = destination
    fwd["Reply-To"] = original_from

    ses.send_raw_email(
        Source=FROM_EMAIL,
        Destinations=[destination],
        RawMessage={"Data": fwd.as_bytes()},
    )
    logger.info("Forwarded %s → %s", recipient, destination)


def handler(event, context):
    for record in event["Records"]:
        message_id = record["ses"]["mail"]["messageId"]
        recipients = record["ses"]["receipt"]["recipients"]

        logger.info("Processing message %s for %s", message_id, recipients)

        key = f"{EMAIL_KEY_PREFIX}/{message_id}"
        raw = s3.get_object(Bucket=EMAIL_BUCKET, Key=key)["Body"].read()

        for recipient in recipients:
            try:
                _forward(raw, recipient)
            except Exception as exc:
                logger.error("Failed to forward %s to %s: %s", message_id, recipient, exc)
                raise
