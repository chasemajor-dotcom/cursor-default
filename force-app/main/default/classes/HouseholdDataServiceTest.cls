@IsTest
private class HouseholdDataServiceTest {

    @IsTest
    static void fetchSnapshot_withStandardData() {
        Account household = new Account(Name = 'Test Household');
        insert household;

        Contact primary = new Contact(
            LastName = 'Primary',
            AccountId = household.Id,
            Email = 'primary@example.com',
            Phone = '555-0100'
        );
        insert primary;

        Task followUp = new Task(
            Subject = 'Intro Call',
            Status = 'Not Started',
            Priority = 'Normal',
            ActivityDate = Date.today(),
            WhatId = household.Id
        );
        insert followUp;

        Case serviceCase = new Case(
            AccountId = household.Id,
            Subject = 'Address update',
            Status = 'New',
            Origin = 'Phone'
        );
        insert serviceCase;

        Opportunity opp = new Opportunity(
            Name = 'Investment Review',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 10000,
            AccountId = household.Id
        );
        insert opp;

        Test.startTest();
        HouseholdDataService.HouseholdSnapshot snapshot = HouseholdDataService.fetchSnapshot(household.Id);
        Test.stopTest();

        System.assertEquals(household.Id, snapshot.household.id);
        System.assertEquals('Test Household', snapshot.household.name);
        System.assertEquals(1, snapshot.members.size(), 'Expected one household member via contact fallback');
        System.assertEquals(primary.Email, snapshot.members[0].email);
        System.assertGreaterThan(0, snapshot.recentActivities.size());
        System.assertEquals(1, snapshot.recentCases.size());
        System.assertEquals(serviceCase.Id, snapshot.recentCases[0].id);
        System.assertEquals(1, snapshot.pipeline.size());
        System.assertEquals(opp.Id, snapshot.pipeline[0].id);
        System.assertNotNull(snapshot.communications, 'Communications list should be non-null');
        System.assertNotNull(snapshot.serviceRequests, 'Service request list should be non-null even without FSC data');
    }
}
