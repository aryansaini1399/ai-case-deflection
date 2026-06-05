public with sharing class KnowledgeArticleService {
  private static final String ENDPOINT = 'callout:NVIDIA_NIM/v1/chat/completions';
  private static final String DEFAULT_MODEL = 'meta/llama-3.3-70b-instruct';
  private static final Integer MAX_CANDIDATES = 30;
  private static final Integer ARTICLE_SNIPPET_LENGTH = 500;
  private static final Integer UI_SNIPPET_LENGTH = 200;
  private static final Integer DEFAULT_TIMEOUT_MS = 90000;
  private static final Integer DEFAULT_MAX_TOKENS = 800;
  private static final Decimal DEFAULT_TEMPERATURE = 0.2;

  private static final String SYSTEM_PROMPT =
    'You are a knowledge base relevance ranker for a SaaS customer support team. ' +
    'Given a case and a list of articles, identify which articles are most likely to ' +
    'resolve the customer issue.\n\n' +
    'CRITICAL: Return ONLY a valid JSON object. Every string value MUST be wrapped in ' +
    'double quotes. Escape any embedded double quotes with backslash. Do NOT wrap the ' +
    'response in markdown code fences.\n\n' +
    'Schema:\n' +
    '{\n' +
    '  "ranked": [\n' +
    '    { "index": <integer>, "score": <decimal 0.0-1.0>, "reasoning": "<string in double quotes>" }\n' +
    '  ]\n' +
    '}\n\n' +
    'Example valid response:\n' +
    '{"ranked":[{"index":0,"score":0.95,"reasoning":"This article directly addresses the password reset issue."},{"index":2,"score":0.7,"reasoning":"This article covers SSO setup, which is related."}]}\n\n' +
    'Order by score descending. Return ONLY the JSON object, no other text.';

  @AuraEnabled(cacheable=false)
  public static List<KnowledgeArticleSuggestion> findRelevantArticles(
    Id caseId,
    Integer topN
  ) {
    if (caseId == null) {
      return new List<KnowledgeArticleSuggestion>();
    }
    Integer limitN = (topN == null || topN < 1) ? 3 : topN;

    List<Case> cases = [
      SELECT Id, Subject, Description, AI_Category__c
      FROM Case
      WHERE Id = :caseId
      LIMIT 1
    ];
    if (cases.isEmpty()) {
      return new List<KnowledgeArticleSuggestion>();
    }
    Case caseRecord = cases[0];

    List<Knowledge_Article__c> articles = queryArticles(
      caseRecord.AI_Category__c
    );
    if (articles.isEmpty()) {
      return new List<KnowledgeArticleSuggestion>();
    }

    String userPrompt = buildUserPrompt(caseRecord, articles, limitN);
    String requestBody = buildRequestBody(userPrompt);

    HttpRequest req = new HttpRequest();
    req.setEndpoint(ENDPOINT);
    req.setMethod('POST');
    req.setHeader('Content-Type', 'application/json');
    req.setTimeout(DEFAULT_TIMEOUT_MS);
    req.setBody(requestBody);

    HttpResponse res = new Http().send(req);
    if (res.getStatusCode() != 200) {
      throw new LLMException(
        'LLM HTTP ' + res.getStatusCode() + ': ' + res.getBody()
      );
    }

    return parseResponse(res.getBody(), articles, limitN);
  }

  @AuraEnabled
  public static Knowledge_Article__c markHelpful(Id articleId) {
    if (articleId == null) {
      throw new LLMException('articleId is required');
    }
    Knowledge_Article__c a = [
      SELECT Id, Helpful_Count__c
      FROM Knowledge_Article__c
      WHERE Id = :articleId
      LIMIT 1
    ];
    Decimal current = a.Helpful_Count__c == null ? 0 : a.Helpful_Count__c;
    a.Helpful_Count__c = current + 1;
    update a;
    return a;
  }

  @TestVisible
  private static List<Knowledge_Article__c> queryArticles(String category) {
    if (String.isNotBlank(category)) {
      return [
        SELECT Id, Name, Body__c, Category__c, Helpful_Count__c
        FROM Knowledge_Article__c
        WHERE Is_Published__c = TRUE AND Category__c = :category
        ORDER BY Helpful_Count__c DESC NULLS LAST
        LIMIT :MAX_CANDIDATES
      ];
    }
    return [
      SELECT Id, Name, Body__c, Category__c, Helpful_Count__c
      FROM Knowledge_Article__c
      WHERE Is_Published__c = TRUE
      ORDER BY Helpful_Count__c DESC NULLS LAST
      LIMIT :MAX_CANDIDATES
    ];
  }

  private static String buildUserPrompt(
    Case c,
    List<Knowledge_Article__c> articles,
    Integer topN
  ) {
    String subject = c.Subject == null ? '' : c.Subject;
    String description = c.Description == null ? '' : c.Description;

    String prompt =
      'CASE:\nSubject: ' +
      subject +
      '\nDescription: ' +
      description +
      '\n\nARTICLES:\n';
    for (Integer i = 0; i < articles.size(); i++) {
      Knowledge_Article__c a = articles[i];
      String snippet = truncate(a.Body__c, ARTICLE_SNIPPET_LENGTH);
      prompt +=
        '[' +
        i +
        '] Title: ' +
        a.Name +
        ' | Category: ' +
        a.Category__c +
        '\n    ' +
        snippet +
        '\n\n';
    }
    prompt += 'Return the top ' + topN + ' articles by relevance to the case.';
    return prompt;
  }

  private static String buildRequestBody(String userPrompt) {
    return JSON.serialize(
      new Map<String, Object>{
        'model' => DEFAULT_MODEL,
        'messages' => new List<Map<String, String>>{
          new Map<String, String>{
            'role' => 'system',
            'content' => SYSTEM_PROMPT
          },
          new Map<String, String>{ 'role' => 'user', 'content' => userPrompt }
        },
        'max_tokens' => DEFAULT_MAX_TOKENS,
        'temperature' => DEFAULT_TEMPERATURE,
        'response_format' => new Map<String, String>{ 'type' => 'json_object' }
      }
    );
  }

  private static List<KnowledgeArticleSuggestion> parseResponse(
    String body,
    List<Knowledge_Article__c> articles,
    Integer topN
  ) {
    Map<String, Object> envelope = (Map<String, Object>) JSON.deserializeUntyped(
      body
    );
    List<Object> choices = (List<Object>) envelope.get('choices');
    if (choices == null || choices.isEmpty()) {
      throw new LLMException('No choices in LLM response');
    }
    Map<String, Object> firstChoice = (Map<String, Object>) choices[0];
    Map<String, Object> message = (Map<String, Object>) firstChoice.get(
      'message'
    );
    String content = (String) message.get('content');

    Map<String, Object> parsed = JsonResponseParser.parseLLMContent(content);
    List<Object> ranked = (List<Object>) parsed.get('ranked');
    if (ranked == null) {
      throw new LLMException('LLM response missing "ranked" array');
    }

    List<KnowledgeArticleSuggestion> result = new List<KnowledgeArticleSuggestion>();
    for (Object o : ranked) {
      if (result.size() >= topN)
        break;
      Map<String, Object> entry = (Map<String, Object>) o;
      Integer idx;
      try {
        idx = Integer.valueOf(String.valueOf(entry.get('index')));
      } catch (Exception parseEx) {
        continue;
      }
      if (idx < 0 || idx >= articles.size())
        continue;

      Knowledge_Article__c a = articles[idx];
      KnowledgeArticleSuggestion s = new KnowledgeArticleSuggestion();
      s.articleId = a.Id;
      s.title = a.Name;
      s.body = a.Body__c;
      s.bodySnippet = truncate(a.Body__c, UI_SNIPPET_LENGTH);
      s.category = a.Category__c;
      s.helpfulCount = a.Helpful_Count__c == null
        ? 0
        : Integer.valueOf(a.Helpful_Count__c);
      Object scoreObj = entry.get('score');
      s.relevanceScore = scoreObj == null
        ? null
        : Decimal.valueOf(String.valueOf(scoreObj));
      s.reasoning = (String) entry.get('reasoning');
      result.add(s);
    }
    return result;
  }

  private static String truncate(String s, Integer n) {
    if (String.isBlank(s))
      return '';
    return s.length() <= n ? s : s.substring(0, n) + '...';
  }
}
