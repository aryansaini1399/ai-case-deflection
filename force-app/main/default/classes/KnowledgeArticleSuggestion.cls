public class KnowledgeArticleSuggestion {
  @AuraEnabled
  public String articleId;
  @AuraEnabled
  public String title;
  @AuraEnabled
  public String body;
  @AuraEnabled
  public String bodySnippet;
  @AuraEnabled
  public String category;
  @AuraEnabled
  public Decimal relevanceScore;
  @AuraEnabled
  public String reasoning;
  @AuraEnabled
  public Integer helpfulCount;
}
