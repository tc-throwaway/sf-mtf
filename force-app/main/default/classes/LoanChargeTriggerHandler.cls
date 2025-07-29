/**
 * @author @tomcarman
 * @since Q3 2025
 * @description Trigger Handler for LoanChargeTrigger
 * @group Loan Management
 */
public with sharing class LoanChargeTriggerHandler {

    /**
     * @description Entrypoint for trigger handler, dispatches based on trigger context
     */
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
    
    /**
     * @description All Loan Charge after insert operations 
     * @param newLoans Loan Charges from Trigger.new()
     * @param newLoanMap Loan Charges from Trigger.newMap()
     */
    private static void handleAfterInsert(List<Loan_Charge__c> newLoanCharges, Map<Id, Loan_Charge__c> newLoanChargeMap) {
        LoanChargeService.adjustReleaseChargeDates(newLoanCharges);
    }
}