public class LoanTriggerHandler {

    public static void handle() {

        if(TriggerControl.isBypassed('LoanTrigger')) {
            return;
        }

        if (Trigger.isAfter) {
            if (Trigger.isInsert) {
                handleAfterInsert((List<Loan__c>)Trigger.new, (Map<Id, Loan__c>)Trigger.newMap);
            } else if (Trigger.isUpdate) {
                handleAfterUpdate((Map<Id, Loan__c>)Trigger.oldMap, (Map<Id, Loan__c>)Trigger.newMap);
            }
        }
        
    }
    
    private static void handleAfterInsert(List<Loan__c> newLoans, Map<Id, Loan__c> newLoanMap) {
        LoanService.createReleaseCharges(newLoans);
    }

    private static void handleAfterUpdate(Map<Id, Loan__c> oldLoanMap, Map<Id, Loan__c> newLoanMap) {
        LoanService.processLoanTermChanges(oldLoanMap, newLoanMap);
    }
}