@isTest
private class LoanServiceTest {
    
    @testSetup
    static void setup() {

        // Create Person Accounts
        List<Account> personAccountsToInsert = new List<Account>();

        Id personAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();

        for (Integer i = 0; i < 5; i++) {
            Account personAccount = new Account();
            personAccount.FirstName = 'Badzt';
            personAccount.LastName = 'Maru ' + 1;
            personAccount.RecordTypeId = personAccountRecordTypeId;
            personAccountsToInsert.add(personAccount);
        }

        insert personAccountsToInsert;
    }
    
    @isTest
    static void testReleaseChargeCreatedOnLoanInsert() {

        // Given an Account with a Loan
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Loan__c loan = new Loan__c(
            Name = 'Test Loan',
            Account__c = acc.Id,
            Gross_Loan_Amount__c = 10000,
            Date_Loan_Issued__c = Date.today(),
            Term__c = 12,
            Security_Address__Street__s = '123 Test Street'
        );
        
        // When the Loan is inserted
        Test.startTest();
        insert loan;
        Test.stopTest();
        
        // Then a single Release Charge should be created with the correct details
        List<Loan_Charge__c> charges = [
            SELECT Id, Charge_Type__c, Amount__c, Date__c
            FROM Loan_Charge__c
            WHERE Loan__c = :loan.Id
        ];
        
        System.assertEquals(1, charges.size(), 'Should create one and only one  Release Charge');
        System.assertEquals(LoanChargeService.LOAN_CHARGE_TYPE_RELEASE, charges[0].Charge_Type__c,  'Charge Type should be Release Charge');
        System.assertEquals(LoanChargeService.LOAN_CHARGE_AMOUNT_RELEASE, charges[0].Amount__c, 'Release Charge should be the correct amount');
        System.assertEquals(Date.today().addMonths(12), charges[0].Date__c, 'Release Charge date should be Loan Issue Date + Term');
    }
    
    @isTest
    static void testReleaseChargeCreatedOnLoanInsertBulk() {

        // Given multiple Accounts with multiple related Loans
        List<Account> accounts = [SELECT Id FROM Account];
        List<Loan__c> loans = new List<Loan__c>();
        
        for(Integer i = 0; i < 200; i++) {
            // Create loan, semi-randomise the values
            Loan__c loan = new Loan__c();
            loan.Name = 'Test Loan ' + i;
            loan.Account__c = accounts[Math.mod(i, accounts.size())].Id;
            loan.Gross_Loan_Amount__c = 10000 + i;
            loan.Date_Loan_Issued__c = Date.today().addDays(-i);
            loan.Term__c = 12 + Math.mod(i, 24);
            loan.Security_Address__Street__s = i + ' Test Street';
            loans.add(loan); 
        }
        
        // When you insert 200 loans
        Test.startTest();
        insert loans;
        Test.stopTest();
        
        // Then each loan has a one and only one Release Charge
        List<Loan_Charge__c> loanReleaseCharges = [
            SELECT Id, Loan__c, Charge_Type__c
            FROM Loan_Charge__c
            WHERE Charge_Type__c = :LoanChargeService.LOAN_CHARGE_TYPE_RELEASE
        ];
        
        System.assertEquals(200, loanReleaseCharges.size(), 'One Release Charge should be created per loan');
        
        Map<Id, Integer> releaseChargesPerLoan = new Map<Id, Integer>();
        
        for(Loan_Charge__c loanReleaseCharge : loanReleaseCharges) {
            Integer count = releaseChargesPerLoan.get(loanReleaseCharge.Loan__c) ?? 0;
            releaseChargesPerLoan.put(loanReleaseCharge.Loan__c, count + 1);
        }
        
        for(Integer count : releaseChargesPerLoan.values()) {
            System.assertEquals(1, count, 'Each loan should have one and only one Release Charge');
        }
    }
    
    @isTest
    static void testLoanChargeAndBalancesAreUpdated() {

        // Given an Account with a Loan
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Loan__c loan = new Loan__c();
        loan.Name = 'Test Loan';
        loan.Account__c = acc.Id;
        loan.Gross_Loan_Amount__c = 10000;
        loan.Date_Loan_Issued__c = Date.today();
        loan.Term__c = 12;
        loan.Security_Address__Street__s = '123 Test Street';
        insert loan;
        
        // When additional Loan Charges are added
        List<Loan_Charge__c> additionalLoanCharges = new List<Loan_Charge__c>();

        Loan_Charge__c loanInterestCharge = new Loan_Charge__c();
        loanInterestCharge.Loan__c = loan.Id;
        loanInterestCharge.Charge_Type__c = LoanChargeService.LOAN_CHARGE_TYPE_INTEREST;
        loanInterestCharge.Amount__c = 1500;
        loanInterestCharge.Date__c = Date.today().addMonths(1);
            
        Loan_Charge__c loanLegalCharge = new Loan_Charge__c();
        loanLegalCharge.Loan__c = loan.Id;
        loanLegalCharge.Charge_Type__c = LoanChargeService.LOAN_CHARGE_TYPE_LEGAL;
        loanLegalCharge.Amount__c = 750;
        loanLegalCharge.Date__c = Date.today().addMonths(2);
        
        additionalLoanCharges.add(loanInterestCharge);
        additionalLoanCharges.add(loanLegalCharge);
        
        Test.startTest();
        insert additionalLoanCharges;
        Test.stopTest();
        
        // Then the Total Charges on the Loan field is updated (via RUS)
        // and the Balance of the Loan field is updated (formula)
        Loan__c updatedLoan = [
            SELECT Balance_of_the_Loan__c, Total_Charges_on_the_Loan__c
            FROM Loan__c
            WHERE Id = :loan.Id
        ];
        
        System.assertEquals(2750, updatedLoan.Total_Charges_on_the_Loan__c, 'Sum of related Loan Charges');
        System.assertEquals(12750, updatedLoan.Balance_of_the_Loan__c, 'Loan Gross Amount + Total Charges');
    }
    
    @isTest
    static void testAdminFeeCreatedWhenTermChanged() {
       
        // Given an Account with a Laon
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Loan__c loan = new Loan__c();
        loan.Name = 'Test Loan';
        loan.Account__c = acc.Id;
        loan.Gross_Loan_Amount__c = 10000;
        loan.Date_Loan_Issued__c = Date.today().addMonths(-6);
        loan.Term__c = 12;
        loan.Security_Address__Street__s = '123 Test Street';

        insert loan;
        
        // When the Loan Term is changed
        loan.Term__c = 24;
        
        Test.startTest();
        update loan;
        Test.stopTest();
        
        // Then a Loan Charge of type Admin Fee is created
        List<Loan_Charge__c> loanCharges = [
            SELECT Charge_Type__c, Amount__c, Date__c
            FROM Loan_Charge__c
            WHERE Loan__c = :loan.Id
            ORDER BY CreatedDate
        ];
        
        System.assertEquals(2, loanCharges.size(), 'Should have Release Charge and Admin Fee');
        
        Loan_Charge__c loanChargeAdminFee = null;
        
        for(Loan_Charge__c loanCharge : loanCharges) {
            if(loanCharge.Charge_Type__c == LoanChargeService.LOAN_CHARGE_TYPE_ADMIN) {
                loanChargeAdminFee = loanCharge;
                break;
            }
        }
        
        System.assertNotEquals(null, loanChargeAdminFee, 'Admin Fee should have been created');
        System.assertEquals(LoanChargeService.LOAN_CHARGE_AMOUNT_ADMIN, loanChargeAdminFee.Amount__c, 'Admin Fee should be the correct amount');
        System.assertEquals(Date.today(), loanChargeAdminFee.Date__c, 'Admin Fee date should be today');
    }
    
    @isTest
    static void testTermModificationUpdatesReleaseChargeDate() {
        
        // Given
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        Date issueDate = Date.today().addMonths(-3);

        Loan__c loan = new Loan__c();
        loan.Name = 'Test Loan';
        loan.Account__c = acc.Id;
        loan.Gross_Loan_Amount__c = 10000;
        loan.Date_Loan_Issued__c = issueDate;
        loan.Term__c = 12;
        loan.Security_Address__Street__s = '123 Test Street';
        insert loan;
        
        // Get the original Release Charge
        Loan_Charge__c loanReleaseCharge = [
            SELECT Date__c
            FROM Loan_Charge__c
            WHERE Loan__c = :loan.Id
            AND Charge_Type__c = :LoanChargeService.LOAN_CHARGE_TYPE_RELEASE
        ];
        
        System.assertEquals(issueDate.addMonths(12), loanReleaseCharge.Date__c, 'Release Charge date is Issue Date + 12 months');
        
        // When the Loan Term is changed
        loan.Term__c = 24;
        
        Test.startTest();
        update loan;
        Test.stopTest();
        
        // Then the existing Release Charge's date should be updated to reflect the new term
        Loan_Charge__c updatedLoanReleaseCharge = [
            SELECT Date__c
            FROM Loan_Charge__c
            WHERE Loan__c = :loan.Id
            AND Charge_Type__c = :LoanChargeService.LOAN_CHARGE_TYPE_RELEASE
        ];
        
        System.assertEquals(issueDate.addMonths(24), updatedLoanReleaseCharge.Date__c, 'Release Charge date should update to issue date + new term');
    }
    
    @isTest
    static void testMultipleTermChanges() {
        // Given
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Loan__c loan = new Loan__c();
        loan.Name = 'Test Loan';
        loan.Account__c = acc.Id;
        loan.Gross_Loan_Amount__c = 10000;
        loan.Date_Loan_Issued__c = Date.today();
        loan.Term__c = 12;
        loan.Security_Address__Street__s = '123 Test Street';
        insert loan;
        
        // When the term is changed multiple times

        // NOTE: For testing, the TriggerControl has to be manually flushed. Obviously in a real
        // scenario, these would be discrete transactions

        Test.startTest();
        loan.Term__c = 18;
        update loan;

        // Flush processedTermChanges for subsequent update
        TriggerControl.processedTermChanges.remove(loan.Id);
        
        loan.Term__c = 24;
        update loan;

        // Flush processedTermChanges for subsequent update
        TriggerControl.processedTermChanges.remove(loan.Id);
        
        loan.Term__c = 36;
        update loan;
        Test.stopTest();
        
        // Then a Loan Charge of type Admin Fee should be created for each term change
        List<Loan_Charge__c> adminFees = [
            SELECT Id
            FROM Loan_Charge__c
            WHERE Loan__c = :loan.Id
            AND Charge_Type__c = :LoanChargeService.LOAN_CHARGE_TYPE_ADMIN
        ];
        
        System.assertEquals(3, adminFees.size(), 'Should create one Admin Fee per term change');
    }
    
    @isTest
    static void testNoChangesWhenTermRemainsTheSame() {
        
        // Given an Account with a Loan
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Loan__c loan = new Loan__c();
        loan.Name = 'Test Loan';
        loan.Account__c = acc.Id;
        loan.Gross_Loan_Amount__c = 10000;
        loan.Date_Loan_Issued__c = Date.today();
        loan.Term__c = 12;
        loan.Security_Address__Street__s = '123 Test Street';
        insert loan;
        
        Integer initialNumberOfLoanChargeRecords = [SELECT COUNT() FROM Loan_Charge__c WHERE Loan__c = :loan.Id];
        
        // When - Update loan without changing term
        loan.Security_Address__Street__s = '321 Test Street';
        
        Test.startTest();
        update loan;
        Test.stopTest();
        
        // Then there should be no addition Loan Charges added
        Integer currentNumberOfLoanChargeRecords = [SELECT COUNT() FROM Loan_Charge__c WHERE Loan__c = :loan.Id];
        System.assertEquals(initialNumberOfLoanChargeRecords, currentNumberOfLoanChargeRecords, 'There should be no additional Loan Charge records');
    }
}