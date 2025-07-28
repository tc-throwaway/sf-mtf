public with sharing class LoanChargeTriggerHandler {

    public static void handle() {

        if(TriggerControl.isBypassed('LoanChargeTrigger')) {
            return;
        }

        if (Trigger.isAfter) {
            if (Trigger.isInsert) {
                handleAfterInsert((List<Loan_Charge__c>)Trigger.new, (Map<Id, Loan_Charge__c>)Trigger.newMap);
            }
        }
    }
    
    private static void handleAfterInsert(List<Loan_Charge__c> newLoanCharges, Map<Id, Loan_Charge__c> newLoanChargeMap) {
        LoanChargeService.adjustReleaseChargeDates(newLoanCharges);
    }
}