@isTest
private class KnowledgeArticleServiceTest {
  @TestSetup
  static void setupData() {
    CaseTriggerHandler.bypass();
    Case c = new Case(
      Subject = 'Cannot log in',
      Description = 'Password reset link does not work',
      AI_Category__c = 'Account Access'
    );
    insert c;
    CaseTriggerHandler.unbypass();

    List<Knowledge_Article__c> articles = new List<Knowledge_Article__c>();
    articles.add(
      new Knowledge_Article__c(
        Name = 'How to reset password',
        Body__c = 'Click the forgot password link on the login page...',
        Category__c = 'Account Access',
        Is_Published__c = true,
        Helpful_Count__c = 10
      )
    );
    articles.add(
      new Knowledge_Article__c(
        Name = 'Setting up SSO',
        Body__c = 'Configure your IdP with SAML 2.0...',
        Category__c = 'Account Access',
        Is_Published__c = true,
        Helpful_Count__c = 5
      )
    );
    articles.add(
      new Knowledge_Article__c(
        Name = 'Two-factor authentication',
        Body__c = 'Enable 2FA via Settings > Security...',
        Category__c = 'Account Access',
        Is_Published__c = true,
        Helpful_Count__c = 8
      )
    );
    articles.add(
      new Knowledge_Article__c(
        Name = 'Unpublished draft',
        Body__c = 'This article is not yet ready for publication.',
        Category__c = 'Account Access',
        Is_Published__c = false,
        Helpful_Count__c = 0
      )
    );
    insert articles;
  }

  @isTest
  static void findRelevantArticlesReturnsRankedSuggestions() {
    Case c = [SELECT Id FROM Case LIMIT 1];

    Test.setMock(
      HttpCalloutMock.class,
      KnowledgeArticleServiceHttpMock.success(new List<Integer>{ 0, 2 })
    );

    Test.startTest();
    List<KnowledgeArticleSuggestion> results = KnowledgeArticleService.findRelevantArticles(
      c.Id,
      2
    );
    Test.stopTest();

    System.assertEquals(2, results.size(), 'Expected 2 suggestions');
    System.assert(
      results[0].relevanceScore > results[1].relevanceScore,
      'First result should have higher score than second'
    );
    System.assertNotEquals(null, results[0].articleId);
    System.assertNotEquals(null, results[0].title);
    System.assertNotEquals(null, results[0].reasoning);
    System.assertNotEquals(null, results[0].bodySnippet);
    System.assertEquals('Account Access', results[0].category);
  }

  @isTest
  static void findRelevantArticlesReturnsEmptyWhenNoMatch() {
    Case c = [SELECT Id FROM Case LIMIT 1];
    CaseTriggerHandler.bypass();
    c.AI_Category__c = 'Feature Request';
    update c;
    CaseTriggerHandler.unbypass();

    Test.startTest();
    List<KnowledgeArticleSuggestion> results = KnowledgeArticleService.findRelevantArticles(
      c.Id,
      3
    );
    Test.stopTest();

    System.assertEquals(
      0,
      results.size(),
      'No published articles in Feature Request -> empty result'
    );
  }

  @isTest
  static void findRelevantArticlesHandlesNullCaseId() {
    Test.startTest();
    List<KnowledgeArticleSuggestion> results = KnowledgeArticleService.findRelevantArticles(
      null,
      3
    );
    Test.stopTest();

    System.assertEquals(0, results.size());
  }

  @isTest
  static void findRelevantArticlesThrowsOnHttpFailure() {
    Case c = [SELECT Id FROM Case LIMIT 1];
    Test.setMock(
      HttpCalloutMock.class,
      KnowledgeArticleServiceHttpMock.failure(401)
    );

    Boolean threw = false;
    Test.startTest();
    try {
      KnowledgeArticleService.findRelevantArticles(c.Id, 3);
    } catch (LLMException e) {
      threw = true;
      System.assert(
        e.getMessage().contains('401'),
        'Expected 401 in exception, got: ' + e.getMessage()
      );
    }
    Test.stopTest();

    System.assert(threw, 'Expected LLMException on HTTP failure');
  }

  @isTest
  static void findRelevantArticlesIgnoresOutOfRangeIndices() {
    Case c = [SELECT Id FROM Case LIMIT 1];
    Test.setMock(
      HttpCalloutMock.class,
      KnowledgeArticleServiceHttpMock.success(new List<Integer>{ 99, 0 })
    );

    Test.startTest();
    List<KnowledgeArticleSuggestion> results = KnowledgeArticleService.findRelevantArticles(
      c.Id,
      3
    );
    Test.stopTest();

    System.assertEquals(
      1,
      results.size(),
      'Out-of-range index 99 should be skipped; only index 0 is valid'
    );
  }

  @isTest
  static void markHelpfulIncrementsCount() {
    Knowledge_Article__c a = [
      SELECT Id, Helpful_Count__c
      FROM Knowledge_Article__c
      LIMIT 1
    ];
    Decimal initial = a.Helpful_Count__c == null ? 0 : a.Helpful_Count__c;

    Test.startTest();
    KnowledgeArticleService.markHelpful(a.Id);
    Test.stopTest();

    Knowledge_Article__c updated = [
      SELECT Helpful_Count__c
      FROM Knowledge_Article__c
      WHERE Id = :a.Id
    ];
    System.assertEquals(initial + 1, updated.Helpful_Count__c);
  }

  @isTest
  static void markHelpfulThrowsOnNullId() {
    Boolean threw = false;
    try {
      KnowledgeArticleService.markHelpful(null);
    } catch (LLMException e) {
      threw = true;
    }
    System.assert(threw, 'Expected exception on null articleId');
  }
}
