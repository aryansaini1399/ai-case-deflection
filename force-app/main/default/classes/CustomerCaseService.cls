/**
 * Guest-accessible service for the customer self-service portal.
 *
 * Security note: declared `without sharing` so that anonymous guest users
 * can read published Knowledge_Article__c records and create Case records.
 * All inputs are server-validated and SOQL is scoped to Is_Published__c = true,
 * so this class never exposes records guests should not see.
 */
public without sharing class CustomerCaseService {
  private static final String ENDPOINT = 'callout:NVIDIA_NIM/v1/chat/completions';
  private static final String DEFAULT_MODEL = 'meta/llama-3.3-70b-instruct';
  private static final Integer MAX_CANDIDATES = 30;
  private static final Integer ARTICLE_SNIPPET_LENGTH = 500;
  private static final Integer UI_SNIPPET_LENGTH = 200;
  private static final Integer DEFAULT_TIMEOUT_MS = 90000;
  private static final Integer DEFAULT_MAX_TOKENS = 800;
  private static final Decimal DEFAULT_TEMPERATURE = 0.2;

  private static final String SYSTEM_PROMPT =
    'You are a customer support AI assisting a SaaS company. Given a customer\'s ' +
    'description and a list of knowledge articles, do TWO things at once:\n' +
    '1) Classify the case (category, priority, sentiment, confidence, 1-sentence summary)\n' +
    '2) Rank the most relevant articles\n\n' +
    'CRITICAL: Return ONLY a valid JSON object. Every string value MUST be in double quotes.\n\n' +
    'Schema:\n' +
    '{\n' +
    '  "predictedCategory": "<Billing|Technical Issue|Account Access|Feature Request|Bug Report|General Inquiry>",\n' +
    '  "predictedPriority": "<Low|Medium|High|Critical>",\n' +
    '  "predictedSentiment": "<Positive|Neutral|Negative|Frustrated>",\n' +
    '  "summary": "<one sentence, max 200 chars>",\n' +
    '  "confidence": <decimal 0.0-1.0>,\n' +
    '  "articles": [\n' +
    '    { "index": <integer>, "score": <decimal 0.0-1.0>, "reasoning": "<string in double quotes>" }\n' +
    '  ]\n' +
    '}\n\n' +
    'Order articles by score descending. Return ONLY the JSON object.';

  /**
   * Called by the LWC as the customer types (debounced).
   * Returns: predicted classification + top N ranked articles.
   */
  @AuraEnabled(cacheable=false)
  public static PreClassificationResult getSuggestions(
    String customerText,
    Integer topN
  ) {
    PreClassificationResult result = new PreClassificationResult();
    result.modelUsed = DEFAULT_MODEL;
    result.articles = new List<KnowledgeArticleSuggestion>();

    if (String.isBlank(customerText)) {
      result.errorMessage = 'Please describe your issue';
      return result;
    }
    Integer limitN = (topN == null || topN < 1) ? 3 : topN;

    List<Knowledge_Article__c> articles = [
      SELECT Id, Name, Body__c, Category__c, Helpful_Count__c
      FROM Knowledge_Article__c
      WHERE Is_Published__c = TRUE
      ORDER BY Helpful_Count__c DESC NULLS LAST
      LIMIT :MAX_CANDIDATES
    ];

    String userPrompt = buildUserPrompt(customerText, articles, limitN);
    String requestBody = buildRequestBody(userPrompt);

    Long start = System.currentTimeMillis();
    try {
      HttpRequest req = new HttpRequest();
      req.setEndpoint(ENDPOINT);
      req.setMethod('POST');
      req.setHeader('Content-Type', 'application/json');
      req.setTimeout(DEFAULT_TIMEOUT_MS);
      req.setBody(requestBody);

      HttpResponse res = new Http().send(req);
      result.processingTimeMs = System.currentTimeMillis() - start;

      if (res.getStatusCode() != 200) {
        result.errorMessage =
          'AI service error (HTTP ' +
          res.getStatusCode() +
          ')';
        return result;
      }

      populateFromResponse(res.getBody(), articles, limitN, result);
      return result;
    } catch (Exception e) {
      result.processingTimeMs = System.currentTimeMillis() - start;
      result.errorMessage = 'AI service unavailable. Please submit your case directly.';
      return result;
    }
  }

  /**
   * Called when the customer chooses to submit the case after deflection failed.
   * Persists the pre-classification we already computed so the agent has context.
   *
   * preClassification is passed as Map<String, Object> instead of the typed DTO
   * because LWC -> Apex JSON deserialization into a typed Apex class is strict and
   * can silently fail (e.g., when an Id-typed field receives a non-Id-shaped string,
   * making the whole DTO null). Map<String, Object> is forgiving and lets us cast
   * each field explicitly.
   */
  @AuraEnabled
  public static String submitCase(
    String customerText,
    String email,
    Map<String, Object> preClassification
  ) {
    if (String.isBlank(customerText)) {
      throw new LLMException('Description is required');
    }

    Case c = new Case();
    c.Subject = customerText.length() > 80
      ? customerText.substring(0, 77) + '...'
      : customerText;
    c.Description = customerText;
    c.SuppliedEmail = email;
    c.Origin = 'Web';
    c.Status = 'New';
    c.Priority = 'Medium';

    Boolean hasPrediction =
      preClassification != null &&
      Boolean.valueOf(preClassification.get('isSuccess'));

    if (hasPrediction) {
      c.AI_Category__c = (String) preClassification.get('predictedCategory');
      c.AI_Priority__c = (String) preClassification.get('predictedPriority');
      c.AI_Sentiment__c = (String) preClassification.get('predictedSentiment');
      c.AI_Summary__c = (String) preClassification.get('summary');
      c.AI_Confidence_Score__c = toDecimal(preClassification.get('confidence'));
      c.AI_Classification_Status__c = 'Completed';
      c.AI_Last_Classified__c = System.now();
    }

    insert c;

    if (hasPrediction) {
      insert new Case_AI_Analysis__c(
        Case__c = c.Id,
        Status__c = 'Success',
        Model_Used__c = (String) preClassification.get('modelUsed'),
        Input_Tokens__c = toInteger(preClassification.get('inputTokens')),
        Output_Tokens__c = toInteger(preClassification.get('outputTokens')),
        Processing_Time_Ms__c = toInteger(
          preClassification.get('processingTimeMs')
        )
      );
    }

    Case inserted = [SELECT CaseNumber FROM Case WHERE Id = :c.Id LIMIT 1];
    return inserted.CaseNumber;
  }

  /**
   * Called when the customer says "this article helped" - increments helpful count.
   */
  @AuraEnabled
  public static void markArticleHelpful(Id articleId) {
    if (articleId == null)
      return;
    Knowledge_Article__c a = [
      SELECT Id, Helpful_Count__c
      FROM Knowledge_Article__c
      WHERE Id = :articleId AND Is_Published__c = TRUE
      LIMIT 1
    ];
    Decimal current = a.Helpful_Count__c == null ? 0 : a.Helpful_Count__c;
    a.Helpful_Count__c = current + 1;
    update a;
  }

  // ── helpers ──────────────────────────────────────────────────

  private static String buildUserPrompt(
    String customerText,
    List<Knowledge_Article__c> articles,
    Integer topN
  ) {
    String prompt = 'CUSTOMER ISSUE:\n' + customerText + '\n\nARTICLES:\n';
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
    prompt += 'Return top ' + topN + ' articles by relevance.';
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

  private static void populateFromResponse(
    String body,
    List<Knowledge_Article__c> articles,
    Integer topN,
    PreClassificationResult result
  ) {
    Map<String, Object> envelope = (Map<String, Object>) JSON.deserializeUntyped(
      body
    );

    Map<String, Object> usage = (Map<String, Object>) envelope.get('usage');
    if (usage != null) {
      result.inputTokens = toInteger(usage.get('prompt_tokens'));
      result.outputTokens = toInteger(usage.get('completion_tokens'));
    }

    List<Object> choices = (List<Object>) envelope.get('choices');
    if (choices == null || choices.isEmpty()) {
      result.errorMessage = 'No response from AI';
      return;
    }
    Map<String, Object> firstChoice = (Map<String, Object>) choices[0];
    Map<String, Object> message = (Map<String, Object>) firstChoice.get(
      'message'
    );
    String content = (String) message.get('content');

    Map<String, Object> parsed = JsonResponseParser.parseLLMContent(content);

    result.predictedCategory = (String) parsed.get('predictedCategory');
    result.predictedPriority = (String) parsed.get('predictedPriority');
    result.predictedSentiment = (String) parsed.get('predictedSentiment');
    result.summary = (String) parsed.get('summary');
    result.confidence = toDecimal(parsed.get('confidence'));

    List<Object> ranked = (List<Object>) parsed.get('articles');
    if (ranked != null) {
      for (Object o : ranked) {
        if (result.articles.size() >= topN)
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
        s.relevanceScore = toDecimal(entry.get('score'));
        s.reasoning = (String) entry.get('reasoning');
        result.articles.add(s);
      }
    }

    result.isSuccess = true;
  }

  private static String truncate(String s, Integer n) {
    if (String.isBlank(s))
      return '';
    return s.length() <= n ? s : s.substring(0, n) + '...';
  }

  private static Integer toInteger(Object v) {
    if (v == null)
      return null;
    return Integer.valueOf(String.valueOf(v));
  }

  private static Decimal toDecimal(Object v) {
    if (v == null)
      return null;
    return Decimal.valueOf(String.valueOf(v));
  }
}
