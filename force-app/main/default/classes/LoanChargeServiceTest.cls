/**
 * @description Unit tests for LoanChargeService.cls
 * @author @tomcarman
 * @since Q3 2025
 * @group Loan Management
 */

@isTest
private class LoanChargeServiceTest {
    
    @testSetup
    static void setup() {

        Id personAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();

        // Create test account
        Account personAccount = new Account();
        personAccount.FirstName = 'Badzt';
        personAccount.LastName = 'Maru ' + 1;
        personAccount.RecordTypeId = personAccountRecordTypeId;
        insert personAccount;
        
        List<Loan__c> loans = new List<Loan__c>();

        Loan__c loan1 = new Loan__c();
        loan1.Name = 'Test Loan 1';
        loan1.Account__c = personAccount.Id;
        loan1.Gross_Loan_Amount__c = 10000;
        loan1.Date_Loan_Issued__c = Date.today();
        loan1.Term__c = 12;
        loan1.Security_Address__Street__s = '123 Test Street';
        
        Loan__c loan2 = new Loan__c();
        loan2.Name = 'Test Loan 2';
        loan2.Account__c = personAccount.Id;
        loan2.Gross_Loan_Amount__c = 20000;
        loan2.Date_Loan_Issued__c = Date.today().addMonths(-6);
        loan2.Term__c = 24;
        loan2.Security_Address__Street__s = '123 Test Street';

        loans.add(loan1);
        loans.add(loan2);
        insert loans;

    }
    
    @isTest
    static void testPreventDuplicateReleaseCharges() {
        
        // Given a loan
        Loan__c loan = [SELECT Id FROM Loan__c WHERE Name = 'Test Loan 1' LIMIT 1];
        
        // Release Charge should already exist from loan creation
        Integer existingReleaseCharges = [SELECT COUNT() FROM Loan_Charge__c WHERE Loan__c = :loan.Id AND Charge_Type__c = :LoanChargeService.LOAN_CHARGE_TYPE_RELEASE];

        System.assertEquals(1, existingReleaseCharges, 'Loan should have one Release Charge from loan creation');
        
        // When - Attempt to create another Release Charge
        Loan_Charge__c duplicateReleaseCharge = new Loan_Charge__c();
        duplicateReleaseCharge.Loan__c = loan.Id;
        duplicateReleaseCharge.Charge_Type__c = LoanChargeService.LOAN_CHARGE_TYPE_RELEASE;
        duplicateReleaseCharge.Amount__c = 500;
        duplicateReleaseCharge.Date__c = Date.today().addMonths(12);
    
        // Then the transaction should fail
        Test.startTest();
        try {
            insert duplicateReleaseCharge;
            System.assert(false, 'Should have hit validation rule preventing multiple Release Charges');
        } catch(DmlException e) {
            System.assert(e.getMessage().contains('A Release Charge already exists for this loan.'), 'The validation rule preventing multiple Release Charges should fire');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testReleaseChargeDateAdjustmentForNewCharge() {
        
        // Given a loan
        Loan__c loan = [SELECT Id FROM Loan__c WHERE Name = 'Test Loan 1' LIMIT 1];
        
        Loan_Charge__c releaseCharge = [
            SELECT Id, Date__c
            FROM Loan_Charge__c
            WHERE Loan__c = :loan.Id
            AND Charge_Type__c = :LoanChargeService.LOAN_CHARGE_TYPE_RELEASE
        ];
        Date originalReleaseDate = releaseCharge.Date__c;
        
        // When - Adding a charge with date on the Release Charge date (e.g. >= to it)
        Loan_Charge__c newAdminLoanCharge = new Loan_Charge__c();
        newAdminLoanCharge.Loan__c = loan.Id;
        newAdminLoanCharge.Charge_Type__c = LoanChargeService.LOAN_CHARGE_TYPE_ADMIN;
        newAdminLoanCharge.Amount__c = 100;
        newAdminLoanCharge.Date__c = originalReleaseDate;
        
        Test.startTest();
        insert newAdminLoanCharge;
        Test.stopTest();
        
        // Then the existing Release Charge date should be updated
        Loan_Charge__c updatedRelease = [
            SELECT Date__c
            FROM Loan_Charge__c
            WHERE Id = :releaseCharge.Id
        ];
        
        System.assertEquals(originalReleaseDate.addMonths(1), updatedRelease.Date__c, 'Release Charge date should be extended by one month');
    }
    
    @isTest
    static void testReleaseChargeDateNotAdjustedForEarlierCharge() {
        
        // Given a Loan
        Loan__c loan = [SELECT Id FROM Loan__c WHERE Name = 'Test Loan 1' LIMIT 1];
        
        Loan_Charge__c releaseCharge = [
            SELECT Id, Date__c
            FROM Loan_Charge__c
            WHERE Loan__c = :loan.Id
            AND Charge_Type__c = :LoanChargeService.LOAN_CHARGE_TYPE_RELEASE
        ];

        Date originalReleaseDate = releaseCharge.Date__c;
        
        // When - Adding a charge with date before the Release Charge date (e.g. < it)
        Loan_Charge__c newAdminLoanCharge = new Loan_Charge__c();
        newAdminLoanCharge.Loan__c = loan.Id;
        newAdminLoanCharge.Charge_Type__c = LoanChargeService.LOAN_CHARGE_TYPE_ADMIN;
        newAdminLoanCharge.Amount__c = 250;
        newAdminLoanCharge.Date__c = originalReleaseDate.addMonths(-6);
        
        Test.startTest();
        insert newAdminLoanCharge;
        Test.stopTest();
        
        // Then the existng Release Charge date should remain unchanged
        Loan_Charge__c unchangedRelease = [SELECT Date__c FROM Loan_Charge__c WHERE Id = :releaseCharge.Id];  
        System.assertEquals(originalReleaseDate, unchangedRelease.Date__c, 'Existng Release Charge date should remain unchanged');

    }
}