# 0001: Deploy to Korea Central

**Status:** accepted, 2026-11-01

## Context

The Azure for Students subscription carries the policy "Allowed resource deployment regions". It permits only Austria East, Malaysia West, UAE North, Southeast Asia and Korea Central. Central India, the closest region, is blocked: a deployment there fails with `RequestDisallowedByPolicy`.

## Decision

Deploy everything to **Korea Central**.

## Why

- Allowed by the subscription policy, and Azure Container Instances is offered there.
- Already proven for the registry, managed identities and networking on this subscription.
- Telemetry goes to Datadog (US5) and New Relic (US) in any case, so the Azure region does not change where the observability data is analysed.

## Consequences

- Higher latency from India to any public endpoint. Acceptable for a demo service.
- No personal data is processed, so data residency is not a concern.
