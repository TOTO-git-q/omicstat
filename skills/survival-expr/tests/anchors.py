"""Independent small-fixture Cox/Efron and product-limit arithmetic.

Uses only Python's standard library, never calls survival/OmicStat or copies a
fitted coefficient into an expected value. Inputs are the original fixture CSVs.
This is a replay/math reference, not a published numerical anchor.
"""
import csv
import json
import math
import pathlib
import sys


def rows(path):
    with pathlib.Path(path).open(newline="") as stream:
        return list(csv.DictReader(stream))


def solve(a, b):
    n = len(b)
    aug = [list(a[i]) + [b[i]] for i in range(n)]
    for j in range(n):
        k = max(range(j, n), key=lambda i: abs(aug[i][j]))
        if abs(aug[k][j]) < 1e-12:
            raise ValueError("Singular independent reference information matrix")
        aug[j], aug[k] = aug[k], aug[j]
        pivot = aug[j][j]
        aug[j] = [x / pivot for x in aug[j]]
        for i in range(n):
            if i != j:
                z = aug[i][j]
                aug[i] = [x - z * y for x, y in zip(aug[i], aug[j])]
    return [x[-1] for x in aug]


def partial_likelihood(beta, x, time, event):
    p = len(beta)
    score = [0.0] * p
    info = [[0.0] * p for _ in range(p)]
    eta = [sum(a * b for a, b in zip(row, beta)) for row in x]
    weight = [math.exp(z) for z in eta]
    likelihood = 0.0
    for t in sorted({t for t, e in zip(time, event) if e}):
        death = [i for i in range(len(x)) if time[i] == t and event[i]]
        risk = [i for i in range(len(x)) if time[i] >= t]
        count = len(death)
        likelihood += sum(eta[i] for i in death)
        for j in range(p):
            score[j] += sum(x[i][j] for i in death)
        for step in range(count):
            fraction = step / count
            adjusted = [(i, weight[i] * (1 - fraction if i in death else 1)) for i in risk]
            s0 = sum(w for _, w in adjusted)
            s1 = [sum(w * x[i][j] for i, w in adjusted) for j in range(p)]
            likelihood -= math.log(s0)
            for j in range(p):
                score[j] -= s1[j] / s0
                for k in range(p):
                    s2 = sum(w * x[i][j] * x[i][k] for i, w in adjusted)
                    info[j][k] += s2 / s0 - s1[j] * s1[k] / s0**2
    return likelihood, score, info


def cox_reference(x, time, event):
    beta = [0.0] * len(x[0])
    for iteration in range(80):
        likelihood, score, info = partial_likelihood(beta, x, time, event)
        step = solve(info, score)
        if max(abs(s) for s in score) < 1e-9:
            break
        factor = 1.0
        while factor > 2**-24:
            trial = [a + factor * b for a, b in zip(beta, step)]
            if partial_likelihood(trial, x, time, event)[0] >= likelihood - 1e-11:
                beta = trial
                break
            factor /= 2
        else:
            raise ValueError("Independent Cox line search did not converge")
    else:
        raise ValueError("Independent Cox Newton solver did not converge")
    _, score, info = partial_likelihood(beta, x, time, event)
    if max(abs(s) for s in score) > 1e-7:
        raise ValueError("Independent Cox score residual too large")
    se = [math.sqrt(solve(info, [float(i == j) for i in range(len(beta))])[j]) for j in range(len(beta))]
    return beta, se


def audit(fixtures, run, gene="SIM_SIGNAL", covariates=("covar1", "covar2")):
    fixtures, run = pathlib.Path(fixtures), pathlib.Path(run)
    clinical = rows(fixtures / "clinical.csv")
    expression = rows(fixtures / "expression.csv")
    expression = next(row for row in expression if row["feature_id"] == gene)
    x = [[float(expression[row["unit"]])] + [float(row[c]) for c in covariates] for row in clinical]
    time = [float(row["time"]) for row in clinical]
    event = [int(row["event"]) for row in clinical]
    beta, se = cox_reference(x, time, event)
    actual = rows(run / "tables/coefficients.csv")
    actual = {row["term"]: row for row in actual if row["gene"] == gene}
    expected = {}
    normal_quantile = 1.959963984540054
    for term, b, s in zip(("expression",) + tuple(covariates), beta, se):
        expected[term] = dict(coefficient=b, se=s, z=b/s,
            p_value=math.erfc(abs(b/s)/math.sqrt(2)), estimate=math.exp(b),
            ci_low=math.exp(b-normal_quantile*s), ci_high=math.exp(b+normal_quantile*s))
    result = {name + "_max_error": max(abs(float(actual[term][name]) - expected[term][name]) for term in expected)
              for name in ("coefficient", "se", "z", "p_value", "estimate", "ci_low", "ci_high")}
    signal = sorted(row[0] for row in x)
    n = len(signal)
    median = (signal[(n-1)//2] + signal[n//2]) / 2
    groups = ["low" if row[0] <= median else "high" for row in x]
    curves = {}
    for group in ("low", "high"):
        indices = [i for i, g in enumerate(groups) if g == group]
        value = 1.0
        curves[(group, 0.0)] = value
        for t in sorted({time[i] for i in indices}):
            risk = sum(time[i] >= t for i in indices)
            death = sum(time[i] == t and event[i] for i in indices)
            value *= 1 - death / risk
            curves[(group, t)] = value
    result["km_product_limit_max_error"] = max(abs(float(row["survival"]) - curves[(row["group"], float(row["time"]))]) for row in rows(run / "tables/km_curves.csv"))
    result["risk_count_max_error"] = max(abs(int(row["n_risk"]) - sum(g == row["group"] and t >= float(row["time"]) for g, t in zip(groups, time))) for row in rows(run / "tables/km_risk.csv"))
    effects = rows(run / "tables/effect_table.csv")
    result["sample_event_count_max_error"] = max(abs(int(effects[0]["n_biological"]) - n), abs(int(effects[0]["n_events"]) - sum(event)))
    return result


if __name__ == "__main__":
    output, run, fixtures = sys.argv[1:4]
    values = audit(fixtures, run, *( [sys.argv[4], tuple(sys.argv[5].split(","))] if len(sys.argv) > 4 else []))
    pathlib.Path(output).write_text(json.dumps(values, indent=2) + "\n")
    print("Independent Cox/Efron and product-limit reference: 10 numerical diagnostics")
