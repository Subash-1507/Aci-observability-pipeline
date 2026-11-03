"""Load generator: steady order traffic to the API over localhost, for the container group that has no public IP.

Runs as its own container from the API image (`python -m src.loadgen`), so the group needs no extra image.
Standard library only and not instrumented: the telemetry comes from the API, not from the traffic source.
"""

import os
import random
import time
import urllib.error
import urllib.request
from collections import Counter

TARGET = os.environ.get("LOADGEN_TARGET", "http://localhost:8000")
INTERVAL_SECONDS = float(os.environ.get("LOADGEN_INTERVAL_SECONDS", "2"))
FAULT_PERCENT = float(os.environ.get("LOADGEN_FAULT_PERCENT", "0"))  # share of orders that hit the payment-gateway fault
SUMMARY_EVERY = 30  # print one line per 30 requests, not one per request
ITEMS = ["laptop", "phone", "headphones"]


def send_order() -> int:
    """Send one order and return its HTTP status, or 0 if the API is not reachable yet."""
    fault = random.uniform(0, 100) < FAULT_PERCENT  # traffic shaping, not security: no need for a secure random source
    url = f"{TARGET}/order/{random.choice(ITEMS)}" + ("?simulate_fault=true" if fault else "")
    try:
        with urllib.request.urlopen(urllib.request.Request(url, method="POST"), timeout=10) as response:
            return response.status
    except urllib.error.HTTPError as error:
        return error.code
    except OSError:
        return 0


def main() -> None:
    print(f"loadgen: POST {TARGET}/order every {INTERVAL_SECONDS}s with {FAULT_PERCENT}% faults")
    statuses: Counter[int] = Counter()
    while True:
        statuses[send_order()] += 1
        if sum(statuses.values()) == SUMMARY_EVERY:
            print("loadgen: last %d requests by status: %s" % (SUMMARY_EVERY, dict(sorted(statuses.items()))))
            statuses.clear()
        time.sleep(INTERVAL_SECONDS)


if __name__ == "__main__":
    main()
