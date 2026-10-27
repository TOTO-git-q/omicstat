"""Independent risk-set arithmetic on invented contracts, never clinical rows."""
from __future__ import annotations
from fractions import Fraction
import math

def aalen_johansen(time, status, times, code):
    if len(time) != len(status) or not time:
        raise ValueError("nonempty matching invented input vectors required")
    if any(not math.isfinite(t) or t <= 0 for t in time) or any(not math.isfinite(s) or s < 0 or int(s) != s for s in status):
        raise ValueError("positive time and explicit nonnegative event codes required")
    answer = []
    for at in times:
        s, f = Fraction(1), Fraction(0)
        for point in sorted({t for t in time if t <= at}):
            risk = sum(t >= point for t in time)
            nominated = sum(t == point and k == code for t, k in zip(time, status))
            all_events = sum(t == point and k > 0 for t, k in zip(time, status))
            f += s * Fraction(nominated, risk)
            s *= 1 - Fraction(all_events, risk)
        answer.append(f)
    return answer

def forbidden_one_minus_km(time, status, times, code):
    answer = []
    for at in times:
        s = Fraction(1)
        for point in sorted({t for t in time if t <= at}):
            risk = sum(t >= point for t in time)
            events = sum(t == point and k == code for t, k in zip(time, status))
            s *= 1 - Fraction(events, risk)
        answer.append(1 - s)
    return answer

def primitive_fixture():
    # Fully invented six units, closed-form cause1 at time5 = 7/18, not3/5.
    return {"time": [1, 2, 3, 4, 5, 6], "status": [2, 1, 0, 2, 1, 0],
            "times": [0, 1, 2, 3, 4, 5, 6], "real_owner_data": False,
            "source": "Project-invented exact-fraction risk sets; no package or patient dataset"}
