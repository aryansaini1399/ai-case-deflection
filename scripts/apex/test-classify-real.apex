// End-to-end smoke test: real callout to NVIDIA NIM via our service layer.
// Run via VS Code: select all, then "SFDX: Execute Anonymous Apex with Currently Selected Text"

String caseText = 'Hi, I was charged $99 twice on May 12 for the Pro plan. ' +
                  'I only signed up once. This is the second time this has happened. ' +
                  'Please refund the duplicate charge immediately.';

System.debug('=== INPUT ===');
System.debug(caseText);

ILLMService service = LLMServiceFactory.getService();
CaseClassificationResult result = service.classify(caseText);

System.debug('=== RESULT ===');
System.debug('isSuccess:           ' + result.isSuccess);
System.debug('category:            ' + result.category);
System.debug('priority:            ' + result.priority);
System.debug('sentiment:           ' + result.sentiment);
System.debug('confidence:          ' + result.confidence);
System.debug('summary:             ' + result.summary);
System.debug('suggestedResponse:   ' + result.suggestedResponse);
System.debug('inputTokens:         ' + result.inputTokens);
System.debug('outputTokens:        ' + result.outputTokens);
System.debug('processingTimeMs:    ' + result.processingTimeMs);
System.debug('modelUsed:           ' + result.modelUsed);

if (!result.isSuccess) {
    System.debug('ERROR: ' + result.errorMessage);
}
