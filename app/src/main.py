"""Order API: a small FastAPI service built to be observed.

Telemetry is switched on outside the code, by opentelemetry-instrument and OTEL_* variables,
so the same image can send to any backend. This file adds only what auto-instrumentation
cannot know: a business span, a business metric and meaningful log lines.
"""
import logging
import os
import random
import time

import redis
from fastapi import FastAPI, HTTPException
from opentelemetry import metrics, trace

logger = logging.getLogger("order-api")
logger.setLevel(logging.INFO)

app = FastAPI(title="Order API")
cache = redis.Redis(host=os.getenv("REDIS_HOST", "localhost"), port=6379, decode_responses=True, socket_timeout=2)

tracer = trace.get_tracer("order-api")
meter = metrics.get_meter("order-api")
orders_processed = meter.create_counter(
    "orders.processed", unit="{order}", description="Orders handled, by item and outcome"
)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/order/{item_id}")
def create_order(item_id: str, simulate_fault: bool = False):
    with tracer.start_as_current_span("process_order") as span:
        span.set_attribute("order.item_id", item_id)

        if simulate_fault:
            # Fault switch for the incident drill: a slow, failing payment call
            delay = random.uniform(0.8, 2.0)
            time.sleep(delay)
            orders_processed.add(1, {"item_id": item_id, "outcome": "failed"})
            logger.error("Payment gateway timeout for item %s after %.2fs", item_id, delay)
            raise HTTPException(status_code=503, detail="Payment gateway timeout")

        count = cache.incr(f"item:{item_id}:count")
        orders_processed.add(1, {"item_id": item_id, "outcome": "processed"})
        logger.info("Order processed for item %s (total %d)", item_id, count)
        return {"item_id": item_id, "orders_count": count, "status": "processed"}
