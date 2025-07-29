/**
 * @author @tomcarman
 * @since Q3 2025
 * @description Trigger Handler for LoanTrigger
 * @group Loan Management
 */
public class LoanTriggerHandler {

    /**
     * @description Entrypoint for trigger handler, dispatches based on trigger context
     */
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
    
    /**
     * @description All Loan after insert operations 
     * @param newLoans Loans from Trigger.new()
     * @param newLoanMap Loans from Trigger.newMap()
     */
    private static void handleAfterInsert(List<Loan__c> newLoans, Map<Id, Loan__c> newLoanMap) {
        LoanService.createReleaseCharges(newLoans);
    }

    /**
     * @description All Loan after update operations 
     * @param oldLoanMap Loans from Trigger.oldMap()
     * @param newLoanMap Loans from Trigger.newMap()
     */
    private static void handleAfterUpdate(Map<Id, Loan__c> oldLoanMap, Map<Id, Loan__c> newLoanMap) {
        LoanService.processLoanTermChanges(oldLoanMap, newLoanMap);
    }
}