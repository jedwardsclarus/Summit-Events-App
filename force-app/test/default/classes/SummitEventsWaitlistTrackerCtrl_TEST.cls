@IsTest
private class SummitEventsWaitlistTrackerCtrl_TEST {

    private static Summit_Events_Instance__c makeInstance(Decimal capacity) {
        Summit_Events__c evt = new Summit_Events__c(
                Event_Name__c = 'Waitlist Tracker Test Event',
                Template__c = 'GeneralSLDS',
                Event_Status__c = 'Active'
        );
        insert evt;
        Summit_Events_Instance__c inst = new Summit_Events_Instance__c(
                Event__c = evt.Id,
                Instance_Title__c = 'WL Tracker Instance',
                Active_Status__c = 'Active',
                Capacity__c = capacity,
                Instance_Start_Date__c = Date.today().addDays(7),
                Instance_End_Date__c = Date.today().addDays(7)
        );
        insert inst;
        return inst;
    }

    private static Summit_Events_Registration__c makeReg(Summit_Events_Instance__c inst, String status, String firstName) {
        Summit_Events_Registration__c r = new Summit_Events_Registration__c(
                Event__c = inst.Event__c,
                Event_Instance__c = inst.Id,
                Registrant_First_Name__c = firstName,
                Registrant_Last_Name__c = 'WLTest',
                Registrant_Email__c = firstName.toLowerCase() + '.wl@test.example',
                Status__c = status
        );
        insert r;
        return r;
    }

    @IsTest static void testCheckInFlipsToAttended() {
        Summit_Events_Instance__c inst = makeInstance(10);
        Summit_Events_Registration__c reg = makeReg(inst, 'Registered', 'CheckMe');

        Test.startTest();
        SummitEventsWaitlistTrackerController.checkInRegistration(reg.Id);
        Test.stopTest();

        Summit_Events_Registration__c after = [SELECT Status__c, Substatus__c FROM Summit_Events_Registration__c WHERE Id = :reg.Id];
        System.assertEquals('Attended', after.Status__c, 'Check In button should stamp Status=Attended');
        System.assertEquals(null, after.Substatus__c, 'Substatus should be cleared on manual check-in');
    }

    @IsTest static void testCancelFlipsToCancelled() {
        Summit_Events_Instance__c inst = makeInstance(10);
        Summit_Events_Registration__c reg = makeReg(inst, 'Registered', 'CancelMe');

        Test.startTest();
        SummitEventsWaitlistTrackerController.cancelRegistration(reg.Id);
        Test.stopTest();

        Summit_Events_Registration__c after = [SELECT Status__c FROM Summit_Events_Registration__c WHERE Id = :reg.Id];
        System.assertEquals('Cancelled', after.Status__c);
    }

    @IsTest static void testReinstateWithCapacityGoesToRegistered() {
        Summit_Events_Instance__c inst = makeInstance(10);
        Summit_Events_Registration__c reg = makeReg(inst, 'Cancelled', 'Comeback');

        Test.startTest();
        SummitEventsWaitlistTrackerController.reinstateRegistration(reg.Id);
        Test.stopTest();

        Summit_Events_Registration__c after = [SELECT Status__c FROM Summit_Events_Registration__c WHERE Id = :reg.Id];
        System.assertEquals('Registered', after.Status__c, 'Reinstate with open capacity should promote to Registered');
    }

    @IsTest static void testReinstateFullGoesToWaitlisted() {
        Summit_Events_Instance__c inst = makeInstance(1);
        Summit_Events_Registration__c filler = makeReg(inst, 'Registered', 'Filler');
        Summit_Events_Registration__c reg = makeReg(inst, 'Cancelled', 'BackFromDead');

        Test.startTest();
        SummitEventsWaitlistTrackerController.reinstateRegistration(reg.Id);
        Test.stopTest();

        Summit_Events_Registration__c after = [SELECT Status__c FROM Summit_Events_Registration__c WHERE Id = :reg.Id];
        System.assertEquals('Waitlisted', after.Status__c, 'Reinstate when full should go to Waitlisted');
    }

    @IsTest static void testReinstateUntrackedCapacityGoesToRegistered() {
        Summit_Events_Instance__c inst = makeInstance(null);
        Summit_Events_Registration__c reg = makeReg(inst, 'Cancelled', 'Unlimited');

        Test.startTest();
        SummitEventsWaitlistTrackerController.reinstateRegistration(reg.Id);
        Test.stopTest();

        Summit_Events_Registration__c after = [SELECT Status__c FROM Summit_Events_Registration__c WHERE Id = :reg.Id];
        System.assertEquals('Registered', after.Status__c, 'Untracked capacity always reinstates to Registered');
    }

    @IsTest static void testGetWaitlistReturnsSortedEntries() {
        Summit_Events_Instance__c inst = makeInstance(10);
        makeReg(inst, 'Cancelled', 'A');
        makeReg(inst, 'Waitlisted', 'B');
        makeReg(inst, 'Pre-Registered', 'C');
        makeReg(inst, 'Registered', 'D');
        makeReg(inst, 'Attended', 'E');

        Test.startTest();
        List<SummitEventsWaitlistTrackerController.WaitlistEntry> entries = SummitEventsWaitlistTrackerController.getWaitlist(inst.Id);
        Test.stopTest();

        System.assertEquals(5, entries.size());
        System.assertEquals(true, entries[0].isCheckedIn, 'First should be checked in (Attended)');
        System.assertEquals(true, entries[1].isRegistered, 'Second should be Registered');
        System.assertEquals(true, entries[2].isPreRegistered, 'Third should be Pre-Registered');
        System.assertEquals(true, entries[3].isWaitlisted, 'Fourth should be Waitlisted');
        System.assertEquals(true, entries[4].isCancelled, 'Fifth should be Cancelled');
    }

    @IsTest static void testWaitlistedEntriesGetPositions() {
        Summit_Events_Instance__c inst = makeInstance(1);
        makeReg(inst, 'Registered', 'Seat');
        makeReg(inst, 'Waitlisted', 'W1');
        makeReg(inst, 'Waitlisted', 'W2');
        makeReg(inst, 'Waitlisted', 'W3');

        Test.startTest();
        List<SummitEventsWaitlistTrackerController.WaitlistEntry> entries = SummitEventsWaitlistTrackerController.getWaitlist(inst.Id);
        Test.stopTest();

        Integer positioned = 0;
        for (SummitEventsWaitlistTrackerController.WaitlistEntry e : entries) {
            if (e.isWaitlisted) {
                positioned++;
                System.assertNotEquals(null, e.position, 'Waitlisted entries should have a numeric position');
            } else {
                System.assertEquals(null, e.position, 'Non-waitlisted entries should have null position');
            }
        }
        System.assertEquals(3, positioned, 'Should be 3 waitlisted entries with positions');
    }
}
