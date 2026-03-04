@IsTest
private class StandardDuplicateFinderControllerTest {

    @IsTest
    static void scan_contacts_email_phone() {
        List<Contact> cs = new List<Contact>{
            new Contact(FirstName='A', LastName='Roy', Email='test@example.com', Phone='+1 (415) 555-0101'),
            new Contact(FirstName='B', LastName='Roy', Email=' TEST@EXAMPLE.COM ', Phone='4155550101'),
            new Contact(FirstName='C', LastName='Roy', Email='unique@example.com', Phone='(212) 555-0101')
        };
        insert cs;

        StandardDuplicateFinderController.ScanRequest req = new StandardDuplicateFinderController.ScanRequest();
        req.objectApiName = 'Contact';
        req.matchEmail = true;
        req.matchPhone = true;
        req.matchName = false;
        req.scope = 'LAST_365_DAYS';
        req.recordLimit = 200;

        Test.startTest();
        StandardDuplicateFinderController.ScanResponse resp = StandardDuplicateFinderController.scan(req);
        Test.stopTest();

        System.assertNotEquals(null, resp, 'response should exist');
        System.assert(resp.scannedCount > 0, 'should scan at least inserted contacts');

        Boolean foundEmailGroup = false;
        Boolean foundPhoneGroup = false;

        for (StandardDuplicateFinderController.DupGroup g : resp.groups) {
            if (g.matchType == 'EMAIL' && g.key == 'test@example.com') {
                foundEmailGroup = true;
                System.assertEquals(2, g.count);
            }
            if (g.matchType == 'PHONE' && g.key != null) {
                if (g.key.endsWith('5550101') && g.count == 2) foundPhoneGroup = true;
            }
        }
        System.assertEquals(true, foundEmailGroup, 'should find email duplicate group');
        System.assertEquals(true, foundPhoneGroup, 'should find phone duplicate group');
    }

    @IsTest
    static void scan_leads_name() {
        List<Lead> ls = new List<Lead>{
            new Lead(LastName='Patel', Company='Acme', Email='p1@acme.com', Phone='999-888-7777'),
            new Lead(LastName='Patel', Company='Acme', Email='p2@acme.com', Phone='9998887777')
        };
        insert ls;

        StandardDuplicateFinderController.ScanRequest req = new StandardDuplicateFinderController.ScanRequest();
        req.objectApiName = 'Lead';
        req.matchEmail = false;
        req.matchPhone = false;
        req.matchName = true;
        req.scope = 'LAST_365_DAYS';
        req.recordLimit = 200;

        StandardDuplicateFinderController.ScanResponse resp = StandardDuplicateFinderController.scan(req);
        System.assertNotEquals(null, resp);
        System.assert(resp.groupCount >= 1, 'should find at least one duplicate group by name');
    }
}
