"""Small independent invented numerical oracles, never native model/owner evidence."""
from __future__ import annotations
import math
from fractions import Fraction


def breslow_fixed_lp(times, events, lp):
    if not (len(times) == len(events) == len(lp)) or not times:
        raise ValueError("equal nonempty vectors required")
    if any(not math.isfinite(x) or x <= 0 for x in times) or any(x not in (0, 1) for x in events):
        raise ValueError("positive time and binary event required")
    if any(not math.isfinite(x) for x in lp):
        raise ValueError("finite predictor required")
    hazard = 0.0
    rows = []
    for time in sorted(set(times)):
        deaths = sum(t == time and event == 1 for t, event in zip(times, events))
        denominator = math.fsum(math.exp(score) for t, score in zip(times, lp) if t >= time)
        hazard += deaths / denominator
        rows.append((time, hazard))
    return rows


def km_event_risk(times, events, horizon):
    if len(times) != len(events) or not times or horizon > max(times):
        raise ValueError("unsupported horizon")
    survival = Fraction(1)
    for time in sorted(set(t for t in times if t <= horizon)):
        risk = sum(t >= time for t in times)
        deaths = sum(t == time and e == 1 for t, e in zip(times, events))
        survival *= 1 - Fraction(deaths, risk)
    return 1 - survival, sum(t >= horizon for t in times)


def ordinal_bins(probabilities, minimum=10, maximum=10):
    if minimum < 10 or maximum < 1 or maximum > 10 or any(not 0 <= p <= 1 for p in probabilities):
        raise ValueError("invalid bins")
    n = len(probabilities)
    k = min(maximum, n // minimum)
    groups = [[] for _ in range(k)]
    if not k:
        return groups
    order = sorted(range(n), key=lambda i: (probabilities[i], i))
    for rank, index in enumerate(order):
        groups[min(k - 1, rank * k // n)].append(index)
    return groups


def optimism(apparent, successful_train_test):
    if not successful_train_test or not math.isfinite(apparent):
        raise ValueError("no usable bootstrap")
    values = [a - b for a, b in successful_train_test]
    if any(not math.isfinite(x) for x in values):
        raise ValueError("nonfinite replicate")
    mean = math.fsum(values) / len(values)
    return mean, apparent - mean
