"""Closed-form and differential checks for the independent synthetic reference."""
import math
import unittest
from anchors import cox_reference, partial_likelihood, solve


class ReferenceMath(unittest.TestCase):
    def test_one_event_closed_form(self):
        beta = .4
        likelihood, score, info = partial_likelihood([beta], [[-1.], [1.]], [2., 1.], [0, 1])
        self.assertAlmostEqual(likelihood, beta - math.log(2 * math.cosh(beta)), places=13)
        self.assertAlmostEqual(score[0], 1 - math.tanh(beta), places=13)
        self.assertAlmostEqual(info[0][0], 1 / math.cosh(beta)**2, places=13)

    def test_balanced_efron_ties_closed_form(self):
        x = [[a] for _ in range(10) for a in [-1., 1.]]
        time = [float(t) for t in range(1, 11) for _ in range(2)]
        event = [int(t <= 8) for t in time]
        beta, se = cox_reference(x, time, event)
        self.assertAlmostEqual(beta[0], 0., places=13)
        self.assertAlmostEqual(se[0], .25, places=13)

    def test_balanced_multivariate_information(self):
        x = [[a, b] for _ in range(4) for a in [-1., 1.] for b in [-1., 1.]]
        time = [float(t) for t in range(1, 5) for _ in range(4)]
        beta, se = cox_reference(x, time, [int(t <= 3) for t in time])
        self.assertTrue(all(abs(b) < 1e-13 for b in beta))
        self.assertTrue(all(abs(s - 1/math.sqrt(12)) < 1e-13 for s in se))

    def test_score_and_information_are_derivatives(self):
        x = [[-.5, .2], [1.2, -.8], [.3, .7], [-.4, -.2]]
        time, event, beta = [1., 1., 2., 3.], [1, 1, 1, 0], [.17, -.3]
        likelihood, score, info = partial_likelihood(beta, x, time, event)
        h = 1e-5
        for j in range(2):
            plus, minus = beta.copy(), beta.copy()
            plus[j] += h; minus[j] -= h
            lp, sp, _ = partial_likelihood(plus, x, time, event)
            lm, sm, _ = partial_likelihood(minus, x, time, event)
            self.assertAlmostEqual((lp-lm)/(2*h), score[j], places=8)
            for k in range(2):
                self.assertAlmostEqual(-(sp[k]-sm[k])/(2*h), info[j][k], places=8)

    def test_risk_set_order_invariance(self):
        x = [[math.sin(i), math.cos(i)] for i in range(20)]
        time = [float(i//2+1) for i in range(20)]
        event = [int(i % 3 != 0) for i in range(20)]
        a, sa = cox_reference(x, time, event)
        b, sb = cox_reference(x[::-1], time[::-1], event[::-1])
        self.assertTrue(all(abs(v-w) < 1e-10 for v, w in zip(a+sa, b+sb)))

    def test_singular_reference_is_refused(self):
        with self.assertRaises(ValueError):
            solve([[1., 1.], [1., 1.]], [1., 1.])
        with self.assertRaises(ValueError):
            cox_reference([[1.], [2.]], [1., 2.], [0, 0])


if __name__ == "__main__":
    unittest.main()
