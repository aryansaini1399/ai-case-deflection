@isTest
private class CaseTriggerHandlerTest {

    @isTest
    static void afterInsertEnqueuesClassificationJob() {
        MockLLMService mock = new MockLLMService();
        LLMServiceFactory.setMock(mock);

        Test.startTest();
        insert new Case(Subject = 'Login broken', Description = 'Cannot sign in');
        Test.stopTest();

        System.assertEquals(1, mock.capturedInputs.size(),
            'Expected Queueable to run and invoke LLM once');
        System.assert(mock.capturedInputs[0].contains('Login broken'),
            'Captured input should include the Subject');
    }

    @isTest
    static void blankSubjectAndDescriptionDoesNotEnqueue() {
        MockLLMService mock = new MockLLMService();
        LLMServiceFactory.setMock(mock);

        Test.startTest();
        insert new Case();
        Test.stopTest();

        System.assertEquals(0, mock.capturedInputs.size(),
            'Empty case should not trigger LLM call');
    }

    @isTest
    static void bulkInsertEnqueuesSingleJobWithAllCaseIds() {
        MockLLMService mock = new MockLLMService();
        LLMServiceFactory.setMock(mock);

        List<Case> bulkCases = new List<Case>();
        for (Integer i = 0; i < 5; i++) {
            bulkCases.add(new Case(Subject = 'Bulk ' + i, Description = 'Desc ' + i));
        }

        Test.startTest();
        insert bulkCases;
        Test.stopTest();

        System.assertEquals(5, mock.capturedInputs.size(),
            'All 5 cases should have been classified by the single Queueable run');
    }

    @isTest
    static void updateWithDescriptionChangeReclassifies() {
        MockLLMService mock = new MockLLMService();
        LLMServiceFactory.setMock(mock);

        // Initial insert — bypass to isolate the update test
        CaseTriggerHandler.bypass();
        Case c = new Case(Subject = 'Initial', Description = 'Initial description');
        insert c;
        CaseTriggerHandler.unbypass();

        Test.startTest();
        c.Description = 'Updated description — completely different';
        update c;
        Test.stopTest();

        System.assertEquals(1, mock.capturedInputs.size(),
            'Description change should trigger reclassification');
    }

    @isTest
    static void updateWithoutSubjectOrDescriptionChangeDoesNotReclassify() {
        MockLLMService mock = new MockLLMService();
        LLMServiceFactory.setMock(mock);

        CaseTriggerHandler.bypass();
        Case c = new Case(Subject = 'Test', Description = 'Test');
        insert c;
        CaseTriggerHandler.unbypass();

        Test.startTest();
        c.Status = 'Working';
        update c;
        Test.stopTest();

        System.assertEquals(0, mock.capturedInputs.size(),
            'Status-only change should not reclassify');
    }

    @isTest
    static void bypassPreventsAllTriggerLogic() {
        MockLLMService mock = new MockLLMService();
        LLMServiceFactory.setMock(mock);

        Test.startTest();
        CaseTriggerHandler.bypass();
        try {
            insert new Case(Subject = 'Test', Description = 'Test');
        } finally {
            CaseTriggerHandler.unbypass();
        }
        Test.stopTest();

        System.assertEquals(0, mock.capturedInputs.size(),
            'Bypass flag should prevent enqueue');
    }
}
