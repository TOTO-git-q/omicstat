# Method basis and scope

ported_from: TOTO-git-q/medstat@12292d020ef4a8575a3a1db880b81786ee3547fa:skills/sample-size/

The production formulas are copied calls to pwr::pwr.t.test, pwr::pwr.t2n.test,
pwr::ES.h, pwr::pwr.2p.test, pwr::pwr.2p2n.test, pwr::pwr.anova.test and
gsDesign::nEvents. OmicStat maintains the copied code independently. There is no
MedStat environment, library, command, MCP call or update synchronization at runtime.

Original independently calculated oracles SS-V1 and SS-V2 are transcribed into
tests/test_helpers.R: stats::power.t.test for the independent-mean count and the
balanced Schoenfeld quantile equation for the event count. These equations are
test oracles only, never fallback production estimators. The original source's
SS-V3 noninferiority case is explicitly outside this five-design port. Paired,
ANOVA and proportions have supplementary native-package consistency tests; these
are labelled replay and are not independent printed anchors.

Planning alpha, power, effect and allocation are not scientific defaults. The
source's SS warnings retain their original conditions but are not recommendations.
Both one-sided orientations use the original magnitude-based native call after
OmicStat explicitly checks the signed declared direction. Group1 minus group2 and
group1/group2 hazard-ratio semantics are written into the output.

Two supplied independent SDs use sqrt((sd1^2 + sd2^2)/2), not a Welch power model.
Paired SD is supplied directly or sqrt(sd1^2 + sd2^2 - 2*corr*sd1*sd2).
ANOVA f is supplied directly or calculated from the population RMS of declared
group means divided by common SD. The variance and distribution assumptions must
be justified by the caller; the code does not inspect observed outcomes to choose a test.

The copied integer allocation search formerly returned 3 when power at n1=2 already
satisfied the target. The adaptation checks the lower endpoint first and makes both
arms' minimum two units explicit via max(2,floor(1/ratio)+1); native formula, target,
200000 ceiling and rounding are unchanged. Since n2=ceiling(n1*ratio), its valid lower endpoint is the smallest integer n1 with n1*ratio>1; using ceiling(2/ratio) would unnecessarily exclude valid rounded allocations. Native lower-bound and minimality tests
are pending, not reported as successful here.

Installed versions and function defaults require new capture in the authorized
OmicStat R4.6.1 image. Empty version/default bindings cannot authorize acceptance;
tests/check_native_readiness.py deliberately fails until a reviewed exact source
closure and validator update exist. No package lock is guessed or rewritten.
