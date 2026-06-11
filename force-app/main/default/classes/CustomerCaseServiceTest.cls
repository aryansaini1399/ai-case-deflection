@isTest
private class CustomerCaseServiceTest {
  @TestSetup
  static void setupData() {
    List<Knowledge_Article__c> articles = new List<Knowledge_Article__c>();
    articles.add(
      new Knowledge_Article__c(
        Name = 'How to reset password',
        Body__c = 'Click the forgot password link...',
        Category__c = 'Account Access',
        Is_Published__c = true,
        Helpful_Count__c = 10
      )
    );
    articles.add(
      new Knowledge_Article__c(
        Name = 'Two-factor authentication',
        Body__c = 'Enable 2FA in Settings...',
        Category__c = 'Account Access',
        Is_Published__c = true,
        Helpful_Count__c = 5
      )
    );
    articles.add(
      new Knowledge_Article__c(
        Name = 'Unpublished draft',
        Body__c = 'Not ready yet...',
        Category__c = 'Account Access',
        Is_Published__c = false
      )
    );
    insert articles;
  }

  @isTest
  static void getSuggestionsReturnsPredictionAndRankedArticles() {
    Test.setMock(
      HttpCalloutMock.class,
      CustomerCaseServiceHttpMock.success(new List<Integer>{ 0, 1 })
    );

    Test.startTest();
    PreClassificationResult result = CustomerCaseService.getSuggestions(
      'I cannot reset my password',
      3
    );
    Test.stopTest();

    System.assertEquals(
      true,
      result.isSuccess,
      'Expected success but got: ' + result.errorMessage
    );
    System.assertEquals('Account Access', result.predictedCategory);
    System.assertEquals('High', result.predictedPriority);
    System.assertEquals('Frustrated', result.predictedSentiment);
    System.assertEquals(0.9, result.confidence);
    System.assertNotEquals(null, result.summary);
    System.assertEquals(2, result.articles.size());
    System.assert(
      result.articles[0].relevanceScore > result.articles[1].relevanceScore
    );
    System.assertEquals(150, result.inputTokens);
    System.assertEquals(100, result.outputTokens);
  }

  @isTest
  static void getSuggestionsRejectsBlankInput() {
    Test.startTest();
    PreClassificationResult result = CustomerCaseService.getSuggestions('', 3);
    Test.stopTest();

    System.assertEquals(false, result.isSuccess);
    System.assertNotEquals(null, result.errorMessage);
  }

  @isTest
  static void getSuggestionsReturnsErrorOnHttpFailure() {
    Test.setMock(
      HttpCalloutMock.class,
      CustomerCaseServiceHttpMock.failure(500)
    );

    Test.startTest();
    PreClassificationResult result = CustomerCaseService.getSuggestions(
      'test input',
      3
    );
    Test.stopTest();

    System.assertEquals(false, result.isSuccess);
    System.assert(
      result.errorMessage.contains('500'),
      'Expected 500 in error message, got: ' + result.errorMessage
    );
  }

  @isTest
  static void submitCaseWithPreClassificationPopulatesAIFields() {
    Map<String, Object> preCls = new Map<String, Object>{
      'isSuccess' => true,
      'predictedCategory' => 'Billing',
      'predictedPriority' => 'High',
      'predictedSentiment' => 'Frustrated',
      'summary' => 'Charged twice',
      'confidence' => 0.92,
      'modelUsed' => 'meta/llama-3.3-70b-instruct',
      'inputTokens' => 100,
      'outputTokens' => 80,
      'processingTimeMs' => 1500
    };

    Test.startTest();
    String caseNumber = CustomerCaseService.submitCase(
      'I was charged twice for May',
      'customer@example.com',
      preCls
    );
    Test.stopTest();

    System.assertNotEquals(null, caseNumber);

    Case created = [
      SELECT
        Subject,
        Description,
        SuppliedEmail,
        AI_Category__c,
        AI_Priority__c,
        AI_Sentiment__c,
        AI_Classification_Status__c,
        AI_Confidence_Score__c
      FROM Case
      WHERE CaseNumber = :caseNumber
    ];
    System.assertEquals('Billing', created.AI_Category__c);
    System.assertEquals('High', created.AI_Priority__c);
    System.assertEquals('Frustrated', created.AI_Sentiment__c);
    System.assertEquals('Completed', created.AI_Classification_Status__c);
    System.assertEquals(0.92, created.AI_Confidence_Score__c);
    System.assertEquals('customer@example.com', created.SuppliedEmail);

    List<Case_AI_Analysis__c> audits = [
      SELECT Status__c, Model_Used__c
      FROM Case_AI_Analysis__c
      WHERE Case__c = :created.Id
    ];
    System.assertEquals(1, audits.size());
    System.assertEquals('Success', audits[0].Status__c);
  }

  @isTest
  static void submitCaseWithoutPreClassificationLeavesAIFieldsBlank() {
    // Bypass the trigger so we test only what submitCase sets directly,
    // not the downstream async classification pipeline.
    CaseTriggerHandler.bypass();

    Test.startTest();
    String caseNumber = CustomerCaseService.submitCase(
      'Generic question',
      'cust@example.com',
      null
    );
    Test.stopTest();

    CaseTriggerHandler.unbypass();

    System.assertNotEquals(null, caseNumber);
    Case created = [
      SELECT AI_Category__c, AI_Classification_Status__c
      FROM Case
      WHERE CaseNumber = :caseNumber
    ];
    System.assertEquals(null, created.AI_Category__c);
    // Status defaults to Pending - the trigger would normally pick it up async
    System.assertEquals('Pending', created.AI_Classification_Status__c);
  }

  @isTest
  static void submitCaseRejectsBlankInput() {
    Boolean threw = false;
    try {
      CustomerCaseService.submitCase('', 'a@b.com', null);
    } catch (LLMException e) {
      threw = true;
    }
    System.assert(threw, 'Expected LLMException on blank input');
  }

  @isTest
  static void markArticleHelpfulIncrementsCount() {
    Knowledge_Article__c a = [
      SELECT Id, Helpful_Count__c
      FROM Knowledge_Article__c
      WHERE Is_Published__c = TRUE
      LIMIT 1
    ];
    Decimal initial = a.Helpful_Count__c == null ? 0 : a.Helpful_Count__c;

    Test.startTest();
    CustomerCaseService.markArticleHelpful(a.Id);
    Test.stopTest();

    Knowledge_Article__c updated = [
      SELECT Helpful_Count__c
      FROM Knowledge_Article__c
      WHERE Id = :a.Id
    ];
    System.assertEquals(initial + 1, updated.Helpful_Count__c);
  }

  @isTest
  static void markArticleHelpfulHandlesNullId() {
    Test.startTest();
    CustomerCaseService.markArticleHelpful(null);
    Test.stopTest();
    // Just verifying no exception is thrown
    System.assert(true);
  }
}
