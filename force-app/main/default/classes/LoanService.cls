/**
 * @description Business logic to support Loan automations
 * @author @tomcarman
 * @since Q3 2025
 * @group Loan Management
 */
public class LoanService {

    /**
     * @description Automation to create a Loan Charge of type Release Charge when a new Loan is created
     * @param loans List of Loans, typically Trigger.new() fron LoanTriggerHandler
     */
    public static void createReleaseCharges(List<Loan__c> loans) {
        
        List<Loan_Charge__c> releaseChargesToInsert = new List<Loan_Charge__c>();

        for(Loan__c loan : loans) {

            if(loan.Date_Loan_Issued__c == null || loan.Term__c == null) {
                continue;
                // TODO: Log or error - depending on requirements
            }

            Loan_Charge__c releaseCharge = new Loan_Charge__c();
            releaseCharge.Loan__c = loan.Id;
            releaseCharge.Charge_Type__c = LoanChargeService.LOAN_CHARGE_TYPE_RELEASE;
            releaseCharge.Amount__c = LoanChargeService.LOAN_CHARGE_AMOUNT_RELEASE;
            releaseCharge.Date__c = loan.Date_Loan_Issued__c.addMonths(Integer.valueOf(loan.Term__c));
            releaseChargesToInsert.add(releaseCharge);
        }

        insert releaseChargesToInsert;
        
    } 

    /**
     * @description Given some updated Loans, identify Laons which have had their
     *              Term changed and generate a `LoanService.TermChange`
     * @param oldLoanMap Map of Loans from Trigger.oldMap()
     * @param newLoanMap Map of Loans from Trigger.newMap()
     */
    public static void processLoanTermChanges(Map<Id, Loan__c> oldLoanMap, Map<Id, Loan__c> newLoanMap) {

        List<TermChange> termChanges = new List<TermChange>();

        for(Loan__c newLoan : newLoanMap.values()) {

            Loan__c oldLoan = oldLoanMap.get(newLoan.Id);

            if(oldLoan.Term__c != newLoan.Term__c && !TriggerControl.hasProcessedTermChange(newLoan.Id)) {

                TermChange termChange = new TermChange(newLoan.Id, 
                                                        newLoan.Date_Loan_Issued__c, 
                                                        Integer.valueOf(newLoan.Term__c));
                termChanges.add(termChange);
                
                TriggerControl.markTermChangeProcessed(newLoan.Id);

            }
        }

        updateLoanTerms(termChanges);
    }

    /**
     * description Update loan terms based on a list of TermChanges. Update the related Release Charge with a new date,
     *             and insert a new Admin Charge. IMPORTANT: Disables Loan Charge trigger whilst processing to prevent recursion.
     * @param termChanges List of LoanService.TermChange
     */
    private static void updateLoanTerms(List<TermChange> termChanges) {
        
        // Bypass the Loan Charge Trigger to preent recursion
        // Total Charges are implemented as RUS, so will unaffected
        TriggerControl.bypass('LoanChargeTrigger');

        try {
            
            // Get existing Release Charges to update
            Set<Id> loanIds = new Set<Id>();
            for(TermChange termChange : termChanges) {
                loanIds.add(termChange.loanId);
            }

            Map<Id, Loan_Charge__c> releaseCharges = LoanChargeService.getReleaseCharges(loanIds);


            List<Loan_Charge__c> releaseChargesToUpdate = new List<Loan_Charge__c>();
            List<Loan_Charge__c> newAdminChargesToInsert = new List<Loan_Charge__c>();

            for(TermChange termChange : termChanges) {

                if(releaseCharges.containsKey(termChange.loanId)) {

                    // Update release charge date
                    Loan_Charge__c releaseCharge = releaseCharges.get(termChange.loanId);
                    releaseCharge.Date__c = termChange.dateLoanIssued.addMonths(termChange.newTerm);
                    
                    releaseChargesToUpdate.add(releaseCharge);

                    // Create new admin loan charge
                    Loan_Charge__c newAdminLoanCharge = new Loan_Charge__c();
                    newAdminLoanCharge.Loan__c = termChange.loanId;
                    newAdminLoanCharge.Charge_Type__c = LoanChargeService.LOAN_CHARGE_TYPE_ADMIN;
                    newAdminLoanCharge.Amount__c = LoanChargeService.LOAN_CHARGE_AMOUNT_ADMIN;
                    newAdminLoanCharge.Date__c = Date.today();

                    newAdminChargesToInsert.add(newAdminLoanCharge);
                }
            }

            // TODO: In real world, would implement some robust error handling here to 
            // potentially rollback if either transaction fails.
            update releaseChargesToUpdate;
            insert newAdminChargesToInsert;

        } finally {
            // Remove bypass once Loan Charge DML has been done
            TriggerControl.clearBypass('LoanChargeTrigger');
        }
    }


    /**
     * @description Represents an "item of work" for when a loan has a change in term length
     */
    private class TermChange {
        Id loanId;
        Date dateLoanIssued;
        Integer newTerm;

        TermChange(Id loanId, Date dateLoanIssued, Integer newTerm) {
            this.loanId = loanId;
            this.dateLoanIssued = dateLoanIssued;
            this.newTerm = newTerm;
        }
    }
}