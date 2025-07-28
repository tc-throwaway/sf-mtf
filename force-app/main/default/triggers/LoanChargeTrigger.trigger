trigger LoanChargeTrigger on Loan_Charge__c (before insert, before update, after insert, after update) {
    LoanChargeTriggerHandler.handle();
}