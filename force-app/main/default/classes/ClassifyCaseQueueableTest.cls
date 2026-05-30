@isTest
private class ClassifyCaseQueueableTest {

    @isTest
    static void successfullyUpdatesCaseAndInsertsAudit() {
        CaseTriggerHandler.bypass();
        Case c = new Case(Subject = 'Test', Description = 'Test description');
        insert c;
        CaseTriggerHandler.unbypass();

        MockLLMService mock = new MockLLMService();
        LLMServiceFactory.setMock(mock);

        Test.startTest();
        System.enqueueJob(new ClassifyCaseQueueable(new Set<Id>{ c.Id }));
        Test.stopTest();

        Case updated = [
            SELECT AI_Category__c, AI_Priority__c, AI_Sentiment__c,
                   AI_Classification_Status__c, AI_Confidence_Score__c,
                   AI_Last_Classified__c, AI_Summary__c, AI_Suggested_Response__c
            FROM Case
            WHERE Id = :c.Id
        ];
        System.assertEquals('Billing', updated.AI_Category__c);
        System.assertEquals('High', updated.AI_Priority__c);
        System.assertEquals('Frustrated', updated.AI_Sentiment__c);
        System.assertEquals('Completed', updated.AI_Classification_Status__c);
        System.assertEquals(0.92, updated.AI_Confidence_Score__c);
        System.assertNotEquals(null, updated.AI_Last_Classified__c);
        System.assertNotEquals(null, updated.AI_Summary__c);
        System.assertNotEquals(null, updated.AI_Suggested_Response__c);

        List<Case_AI_Analysis__c> audits = [
            SELECT Status__c, Model_Used__c, Input_Tokens__c, Output_Tokens__c,
                   Processing_Time_Ms__c, Raw_Request__c, Raw_Response__c
            FROM Case_AI_Analysis__c
            WHERE Case__c = :c.Id
        ];
        System.assertEquals(1, audits.size(), 'Exactly one audit record expected');
        Case_AI_Analysis__c audit = audits[0];
        System.assertEquals('Success', audit.Status__c);
        System.assertEquals('mock-model', audit.Model_Used__c);
        System.assertEquals(100, audit.Input_Tokens__c);
        System.assertEquals(50, audit.Output_Tokens__c);
        System.assertEquals(250, audit.Processing_Time_Ms__c);
        System.assertNotEquals(null, audit.Raw_Request__c);
        System.assertNotEquals(null, audit.Raw_Response__c);
    }

    @isTest
    static void failureMarksStatusFailedAndCapturesError() {
        CaseTriggerHandler.bypass();
        Case c = new Case(Subject = 'Test', Description = 'Test description');
        insert c;
        CaseTriggerHandler.unbypass();

        MockLLMService mock = new MockLLMService();
        mock.resultToReturn = MockLLMService.failureResult('Simulated API failure');
        LLMServiceFactory.setMock(mock);

        Test.startTest();
        System.enqueueJob(new ClassifyCaseQueueable(new Set<Id>{ c.Id }));
        Test.stopTest();

        Case updated = [
            SELECT AI_Classification_Status__c, AI_Category__c
            FROM Case
            WHERE Id = :c.Id
        ];
        System.assertEquals('Failed', updated.AI_Classification_Status__c);
        System.assertEquals(null, updated.AI_Category__c,
            'Category should not be set on failure');

        List<Case_AI_Analysis__c> audits = [
            SELECT Status__c, Error_Message__c
            FROM Case_AI_Analysis__c
            WHERE Case__c = :c.Id
        ];
        System.assertEquals(1, audits.size());
        System.assertEquals('Failed', audits[0].Status__c);
        System.assertEquals('Simulated API failure', audits[0].Error_Message__c);
    }

    @isTest
    static void handlesMultipleCasesInOneRun() {
        CaseTriggerHandler.bypass();
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < 3; i++) {
            cases.add(new Case(Subject = 'Test ' + i, Description = 'Desc ' + i));
        }
        insert cases;
        CaseTriggerHandler.unbypass();

        Set<Id> caseIds = new Set<Id>();
        for (Case c : cases) caseIds.add(c.Id);

        MockLLMService mock = new MockLLMService();
        LLMServiceFactory.setMock(mock);

        Test.startTest();
        System.enqueueJob(new ClassifyCaseQueueable(caseIds));
        Test.stopTest();

        System.assertEquals(3, mock.capturedInputs.size(),
            'LLM should be called once per case');

        Integer completedCount = [
            SELECT COUNT()
            FROM Case
            WHERE Id IN :caseIds AND AI_Classification_Status__c = 'Completed'
        ];
        System.assertEquals(3, completedCount);

        Integer auditCount = [
            SELECT COUNT()
            FROM Case_AI_Analysis__c
            WHERE Case__c IN :caseIds
        ];
        System.assertEquals(3, auditCount);
    }

    @isTest
    static void emptyCaseIdSetExitsGracefully() {
        MockLLMService mock = new MockLLMService();
        LLMServiceFactory.setMock(mock);

        Test.startTest();
        System.enqueueJob(new ClassifyCaseQueueable(new Set<Id>()));
        Test.stopTest();

        System.assertEquals(0, mock.capturedInputs.size());
    }

    @isTest
    static void nullCaseIdSetExitsGracefully() {
        MockLLMService mock = new MockLLMService();
        LLMServiceFactory.setMock(mock);

        Test.startTest();
        System.enqueueJob(new ClassifyCaseQueueable(null));
        Test.stopTest();

        System.assertEquals(0, mock.capturedInputs.size());
    }
}
