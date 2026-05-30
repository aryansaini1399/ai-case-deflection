@isTest
private class NvidiaLLMServiceTest {

    @isTest
    static void classifiesSuccessfully() {
        Test.setMock(HttpCalloutMock.class, NvidiaLLMHttpMock.success());

        Test.startTest();
        ILLMService service = LLMServiceFactory.getService();
        CaseClassificationResult result = service.classify('My card was charged twice for May.');
        Test.stopTest();

        System.assertEquals(true, result.isSuccess, 'Expected success but got error: ' + result.errorMessage);
        System.assertEquals('Billing', result.category);
        System.assertEquals('High', result.priority);
        System.assertEquals('Frustrated', result.sentiment);
        System.assertEquals(0.92, result.confidence);
        System.assertEquals(142, result.inputTokens);
        System.assertEquals(87, result.outputTokens);
        System.assertEquals('meta/llama-3.3-70b-instruct', result.modelUsed);
        System.assertNotEquals(null, result.processingTimeMs);
        System.assertNotEquals(null, result.rawRequest);
        System.assertNotEquals(null, result.rawResponse);
    }

    @isTest
    static void blankInputReturnsErrorWithoutCallout() {
        Test.startTest();
        CaseClassificationResult result = LLMServiceFactory.getService().classify('');
        Test.stopTest();

        System.assertEquals(false, result.isSuccess);
        System.assertEquals('Case text is required', result.errorMessage);
    }

    @isTest
    static void nullInputReturnsErrorWithoutCallout() {
        Test.startTest();
        CaseClassificationResult result = LLMServiceFactory.getService().classify(null);
        Test.stopTest();

        System.assertEquals(false, result.isSuccess);
        System.assertEquals('Case text is required', result.errorMessage);
    }

    @isTest
    static void handlesUnauthorizedResponse() {
        Test.setMock(HttpCalloutMock.class, NvidiaLLMHttpMock.unauthorized());

        Test.startTest();
        CaseClassificationResult result = LLMServiceFactory.getService().classify('test input');
        Test.stopTest();

        System.assertEquals(false, result.isSuccess);
        System.assert(result.errorMessage.contains('401'),
            'Expected 401 in errorMessage, got: ' + result.errorMessage);
    }

    @isTest
    static void handlesMalformedLLMOutput() {
        Test.setMock(HttpCalloutMock.class, NvidiaLLMHttpMock.malformedContent());

        Test.startTest();
        CaseClassificationResult result = LLMServiceFactory.getService().classify('test input');
        Test.stopTest();

        System.assertEquals(false, result.isSuccess);
        System.assert(result.errorMessage.startsWith('Parse error'),
            'Expected parse error, got: ' + result.errorMessage);
    }

    @isTest
    static void handlesEmptyChoicesArray() {
        Test.setMock(HttpCalloutMock.class, NvidiaLLMHttpMock.emptyChoices());

        Test.startTest();
        CaseClassificationResult result = LLMServiceFactory.getService().classify('test input');
        Test.stopTest();

        System.assertEquals(false, result.isSuccess);
        System.assertEquals('No choices in LLM response', result.errorMessage);
    }

    @isTest
    static void factoryReturnsNvidiaServiceByDefault() {
        ILLMService service = LLMServiceFactory.getService();
        System.assert(service instanceof NvidiaLLMService);
    }

    @isTest
    static void factoryAcceptsCustomModel() {
        Test.setMock(HttpCalloutMock.class, NvidiaLLMHttpMock.success());

        Test.startTest();
        ILLMService service = LLMServiceFactory.getService('nvidia/llama-3.1-nemotron-70b-instruct');
        CaseClassificationResult result = service.classify('test');
        Test.stopTest();

        System.assertEquals('nvidia/llama-3.1-nemotron-70b-instruct', result.modelUsed);
    }
}
