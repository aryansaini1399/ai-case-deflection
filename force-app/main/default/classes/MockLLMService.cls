@isTest
public class MockLLMService implements ILLMService {

    public CaseClassificationResult resultToReturn;
    public List<String> capturedInputs = new List<String>();

    public MockLLMService() {
        this.resultToReturn = defaultSuccessResult();
    }

    public CaseClassificationResult classify(String caseText) {
        capturedInputs.add(caseText);
        return resultToReturn;
    }

    public static CaseClassificationResult defaultSuccessResult() {
        CaseClassificationResult r = new CaseClassificationResult();
        r.isSuccess = true;
        r.category = 'Billing';
        r.priority = 'High';
        r.sentiment = 'Frustrated';
        r.summary = 'Customer reports duplicate charge';
        r.suggestedResponse = 'We apologize for the inconvenience. Refund initiated.';
        r.confidence = 0.92;
        r.modelUsed = 'mock-model';
        r.inputTokens = 100;
        r.outputTokens = 50;
        r.processingTimeMs = 250;
        r.rawRequest = '{"mock":"request"}';
        r.rawResponse = '{"mock":"response"}';
        return r;
    }

    public static CaseClassificationResult failureResult(String errorMsg) {
        CaseClassificationResult r = new CaseClassificationResult();
        r.isSuccess = false;
        r.errorMessage = errorMsg;
        r.modelUsed = 'mock-model';
        r.processingTimeMs = 100;
        return r;
    }
}
