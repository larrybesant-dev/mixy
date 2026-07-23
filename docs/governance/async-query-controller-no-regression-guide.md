# Async Query Controller No-Regression Guide

Status: Active
Scope: Feature-local async query flows (search, lookup, typeahead)

## Purpose

Keep async query behavior stable as features scale by enforcing one boundary:

- UI owns rendering state and intent forwarding.
- Controller owns timing, query policy, and stale-response safety.
- Data layer owns fetching only.

## Required Controller Contract

Every feature-level async query controller must implement all of the following:

1. Minimum query threshold gate.
2. Debounce execution window.
3. Monotonic request token/id for stale response rejection.
4. Lifecycle-safe dispose that:
   - cancels debounce timer,
   - clears timer reference,
   - invalidates in-flight requests.

## Strict Separation Rules

Controller must not:

- store widget instances or BuildContext,
- store rendered UI state models,
- navigate routes,
- show snackbars/toasts,
- mutate provider trees directly.

UI must not:

- implement debounce,
- implement request-id race guards,
- implement threshold policy.

## Wiring Pattern (Required)

1. UI constructs controller once per screen lifecycle.
2. UI disposes controller in dispose().
3. UI calls controller.search(...) from onChanged.
4. UI passes callbacks for:
   - threshold-not-met handling,
   - search-start handling,
   - success result handling,
   - error handling.

## Verification Checklist

Run before merge:

1. flutter analyze
2. Manual behavior checks:
   - 1-2 chars: no network query,
   - 3+ chars: debounced query runs,
   - rapid typing: only latest result applies,
   - dispose/navigate away: no delayed overwrite.

## Drift Prevention Rule

When a new feature needs query control (rooms/social/speed dating), copy this pattern shape first.
Do not extend an existing feature controller across domains unless a shared contract is approved in governance docs.

## Current Reference Implementation

- lib/features/messaging/controllers/messaging_search_controller.dart
- lib/features/messaging/screens/new_message_screen.dart
