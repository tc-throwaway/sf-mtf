trigger LoanTrigger on Loan__c (before insert, before update, after insert, after update) {
    LoanTriggerHandler.handle();
}