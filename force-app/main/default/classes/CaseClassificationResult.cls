public class CaseClassificationResult {

    @AuraEnabled public String category;
    @AuraEnabled public String priority;
    @AuraEnabled public String sentiment;
    @AuraEnabled public String summary;
    @AuraEnabled public String suggestedResponse;
    @AuraEnabled public Decimal confidence;

    @AuraEnabled public String modelUsed;
    @AuraEnabled public Integer inputTokens;
    @AuraEnabled public Integer outputTokens;
    @AuraEnabled public Long processingTimeMs;
    @AuraEnabled public String rawRequest;
    @AuraEnabled public String rawResponse;

    @AuraEnabled public Boolean isSuccess = false;
    @AuraEnabled public String errorMessage;
}
