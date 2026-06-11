public class PreClassificationResult {
  @AuraEnabled
  public Boolean isSuccess = false;
  @AuraEnabled
  public String errorMessage;

  @AuraEnabled
  public String predictedCategory;
  @AuraEnabled
  public String predictedPriority;
  @AuraEnabled
  public String predictedSentiment;
  @AuraEnabled
  public String summary;
  @AuraEnabled
  public Decimal confidence;

  @AuraEnabled
  public List<KnowledgeArticleSuggestion> articles;

  @AuraEnabled
  public Integer inputTokens;
  @AuraEnabled
  public Integer outputTokens;
  @AuraEnabled
  public Long processingTimeMs;
  @AuraEnabled
  public String modelUsed;
}
