# Summary

* Most requirements have been implemented, including the bonus ones - the majority of the implementation is in [`LoanService.cls`](/force-app/main/default/classes/LoanService.cls) and [`LoanChargeService.cls`](/force-app/main/default/classes/LoanChargeService.cls)
* Unit tests with good coverage - [`LoanServiceTest.cls`](/force-app/main/default/classes/LoanServiceTest.cls) and [`LoanChargeServiceTest.cls`](/force-app/main/default/classes/LoanChargeServiceTest.cls)
* Loan charges sum is handled via RUS - not Apex.
* Trigger recursion caused my Loan term changes is handled via [`TriggerControl.cls`](/force-app/main/default/classes/TriggerControl.cls). This is a trivial implementation of recursion control - in the "real world" a more comprehensive trigger framework is likely to be used.
* Preventing multiple Release Charges is handled via a RUS + Validation Rule. Would consider doing in Apex if this was production code.
* I implemented limited error handling, as my preferred aproach would be via Platform Events, but that seemed beyond the scope of this. In a real world implementation I would use an event based logging framework e.g. [sf-logger](https://github.com/tomcarman/sf-logger) or [NebulaLogger](https://github.com/jongpie/NebulaLogger).
* Should be deployable to a fresh dev org via the sf cli, although I don't have time to test! The only dependency should be to enable PersonAccounts with default RecordType name.

# Issues

The following requirements weren't clear / or I misunderstood them:

> If the Charge Date of the new charge is on or after the Release Charge Date, the Release Charge Date must be automatically extended by one month

The intention seems to be to progress the Release Charge date by +1 month, but if the date of the new charge is more than 1 month away, the Release Charge would still fall before the new charge - and my assumption was that the Release Charge should always have the furthest date - so instead I set the Release Charge to the date of the new charge + 1 month. This might be incorrect, but unable to clarify!

> Order of Operations: If the Admin Fee's Charge Date falls on the same day as an existing Interest Charge, the Admin Fee must always be processed and applied before the Interest Charge for calculation purposes.

I imagine in a real world scenario the "Interest Charge" is applied as a percentage of the loan - in which case the ordering could matter. But based on the object configuration earlier in the requirements, its just a flat fee like the other Loan Charges. Given that, the order in which the charges are applied has no impact - so I didn't implement any ordering.


# Unit Tests

```
❯ sf apex run test  --class-names LoanServiceTest --class-names LoanChargeServiceTest --code-coverage --wait 20000
=== Test Results
TEST NAME                                                               OUTCOME  MESSAGE  RUNTIME (MS)
──────────────────────────────────────────────────────────────────────  ───────  ───────  ────────────
LoanServiceTest.testAdminFeeCreatedWhenTermChanged                      Pass              648
LoanServiceTest.testLoanChargeAndBalancesAreUpdated                     Pass              285
LoanServiceTest.testMultipleTermChanges                                 Pass              805
LoanServiceTest.testNoChangesWhenTermRemainsTheSame                     Pass              249
LoanServiceTest.testReleaseChargeCreatedOnLoanInsert                    Pass              178
LoanServiceTest.testReleaseChargeCreatedOnLoanInsertBulk                Pass              1236
LoanServiceTest.testTermModificationUpdatesReleaseChargeDate            Pass              833
LoanChargeServiceTest.testPreventDuplicateReleaseCharges                Pass              91
LoanChargeServiceTest.testReleaseChargeDateAdjustmentForNewCharge       Pass              233
LoanChargeServiceTest.testReleaseChargeDateNotAdjustedForEarlierCharge  Pass              160


=== Apex Code Coverage by Class
CLASSES                   PERCENT  UNCOVERED LINES
────────────────────────  ───────  ───────────────
LoanTrigger               100%
LoanService               98%      10
LoanTriggerHandler        92%      6
LoanChargeTriggerHandler  100%
LoanChargeService         100%
LoanChargeTrigger         100%
TriggerControl            100%


=== Test Setup Time by Test Class for Run 707Qy00000YWIZt
TEST SETUP METHOD NAME       SETUP TIME
───────────────────────────  ──────────
LoanServiceTest.setup        430
LoanChargeServiceTest.setup  967


=== Test Summary
NAME                 VALUE
───────────────────  ──────────────────────────────
Outcome              Passed
Tests Ran            12
Pass Rate            100%
Fail Rate            0%
Skip Rate            0%
Test Run Id          707Qy00000YWIZt
Test Setup Time      1397 ms
Test Execution Time  4718 ms
Test Total Time      6115 ms
Org Id               00DQy00000VDP0QMAX
Org Wide Coverage    98%
```
