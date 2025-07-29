/**
 * @description Business logic to support Loan Charge automations
 * @author @tomcarman
 * @since Q3 2025
 * @group Loan Management
 */
public with sharing class LoanChargeService {

    public static final String LOAN_CHARGE_TYPE_RELEASE = 'Release Charge';
    public static final String LOAN_CHARGE_TYPE_ADMIN = 'Admin Fee';
    public static final String LOAN_CHARGE_TYPE_LEGAL = 'Legal Fee';
    public static final String LOAN_CHARGE_TYPE_INTEREST = 'Interest Charge';
    public static final Integer LOAN_CHARGE_AMOUNT_RELEASE = 500;
    public static final Integer LOAN_CHARGE_AMOUNT_ADMIN = 300;

    /**
     * @description Logic to extend the date of a Release Charge when an new Loan Charge with a later date is added.
     * @param loanCharges List of Loan Charges, typically from Trigger.new()
     */
    public static void adjustReleaseChargeDates(List<Loan_Charge__c> loanCharges) {

        Set<Id> loanIds = getRelatedLoanIds(loanCharges);
        Map<Id, Loan_Charge__c> relatedReleaseCharges = getReleaseCharges(loanIds);
        List<Loan_Charge__c> releaseChargesToUpdate = new List<Loan_Charge__c>();

        for(Loan_Charge__c newCharge: loanCharges) {

            if(newCharge.Charge_Type__c != LOAN_CHARGE_TYPE_RELEASE) {
                if(relatedReleaseCharges.containsKey(newCharge.Loan__c)) {
                    Loan_Charge__c releaseCharge = relatedReleaseCharges.get(newCharge.Loan__c);

                    if(newCharge.Date__c >= releaseCharge.Date__c) {
                        // ASSUMPTION: The requirements state: 
                        // "If the Charge Date of the new charge is on or after the Release Charge Date, 
                        // the Release Charge Date must be automatically extended by one month"
                        // But if the new charge is more than one month away, the release charge would
                        // still fall before the new charge date. Without being able to clarify, 
                        // I am interpreting it to mean 1 month after the new charge date.
                        releaseCharge.Date__c = newCharge.Date__c.addMonths(1);
                        releaseChargesToUpdate.add(releaseCharge);
                    }
                }
            } 
        }

        update releaseChargesToUpdate;
    }

    /**
     * @description Given a set of Loan Charges, return a set of related Loan Ids
     * @param loanCharges List of Loan Charges to retrieve the Loan Ids from
     * @return  `Set<Id>` Set of Loan__c Ids
     */    
    private static Set<Id> getRelatedLoanIds(List<Loan_Charge__c> loanCharges) {
        Set<Id> loanIds = new Set<Id>();
        for(Loan_Charge__c loanCharge : loanCharges) {
            loanIds.add(loanCharge.Loan__c);
        }
        return loanIds;
    }

    /**
     * @description Given a set of Loan Ids, return the associated Release Charge
     * @param loanIds Set of Loan Ids to get the Release Charges for
     * @return  `Map<Id, Loan_Charge__c>` Map of Loan Id | Loan Charge record (of type Release Charge)
     */
    public static Map<Id, Loan_Charge__c> getReleaseCharges(Set<Id> loanIds) {

        // Assumes single release charge per loan, based on constraint.
        // For a real implementation, I would probably still validate this here,
        // even if its being constrained elsewhere.
        Map<Id, Loan_Charge__c> releaseChargeMap = new Map<Id, Loan_Charge__c>();

        List<Loan_Charge__c> releaseCharges = [
            SELECT Id, Loan__c, Date__c, Amount__c, Charge_Type__c
            FROM Loan_Charge__c
            WHERE Loan__c IN :loanIds
            AND Charge_Type__c = :LOAN_CHARGE_TYPE_RELEASE
        ];

        for(Loan_Charge__c loanCharge : releaseCharges) {
            releaseChargeMap.put(loanCharge.Loan__c, loanCharge);
        }

        return releaseChargeMap;
    }

}
