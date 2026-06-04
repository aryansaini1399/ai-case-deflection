public with sharing class NvidiaLLMService implements ILLMService {
  private static final String ENDPOINT = 'callout:NVIDIA_NIM/v1/chat/completions';
  private static final String DEFAULT_MODEL = 'meta/llama-3.3-70b-instruct';
  private static final Integer DEFAULT_TIMEOUT_MS = 30000;
  private static final Integer DEFAULT_MAX_TOKENS = 500;
  private static final Decimal DEFAULT_TEMPERATURE = 0.2;

  private static final String SYSTEM_PROMPT =
    'You are an expert customer support classifier for a SaaS company. ' +
    'Analyze the case and return ONLY a valid JSON object with these exact keys: ' +
    '"category" (one of: Billing, Technical Issue, Account Access, Feature Request, Bug Report, General Inquiry), ' +
    '"priority" (one of: Low, Medium, High, Critical), ' +
    '"sentiment" (one of: Positive, Neutral, Negative, Frustrated), ' +
    '"summary" (one sentence, max 200 chars), ' +
    '"suggested_response" (a polite, professional draft, 2-4 sentences), ' +
    '"confidence" (decimal between 0.0 and 1.0). ' +
    'Do NOT wrap your response in markdown code fences. Return raw JSON only.';

  private final String model;

  public NvidiaLLMService() {
    this(DEFAULT_MODEL);
  }

  public NvidiaLLMService(String model) {
    this.model = model;
  }

  public CaseClassificationResult classify(String caseText) {
    CaseClassificationResult result = new CaseClassificationResult();
    result.modelUsed = this.model;
    result.isSuccess = false;

    if (String.isBlank(caseText)) {
      result.errorMessage = 'Case text is required';
      return result;
    }

    String requestBody = buildRequestBody(caseText);
    result.rawRequest = requestBody;

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
      result.rawResponse = res.getBody();

      if (res.getStatusCode() != 200) {
        result.errorMessage =
          'HTTP ' +
          res.getStatusCode() +
          ': ' +
          res.getBody();
        return result;
      }

      return populateFromResponse(res.getBody(), result);
    } catch (Exception e) {
      result.processingTimeMs = System.currentTimeMillis() - start;
      result.errorMessage = 'Callout failed: ' + e.getMessage();
      return result;
    }
  }

  private String buildRequestBody(String caseText) {
    return JSON.serialize(
      new Map<String, Object>{
        'model' => this.model,
        'messages' => new List<Map<String, String>>{
          new Map<String, String>{
            'role' => 'system',
            'content' => SYSTEM_PROMPT
          },
          new Map<String, String>{ 'role' => 'user', 'content' => caseText }
        },
        'max_tokens' => DEFAULT_MAX_TOKENS,
        'temperature' => DEFAULT_TEMPERATURE,
        'response_format' => new Map<String, String>{ 'type' => 'json_object' }
      }
    );
  }

  private CaseClassificationResult populateFromResponse(
    String body,
    CaseClassificationResult result
  ) {
    try {
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
        result.errorMessage = 'No choices in LLM response';
        return result;
      }

      Map<String, Object> firstChoice = (Map<String, Object>) choices[0];
      Map<String, Object> message = (Map<String, Object>) firstChoice.get(
        'message'
      );
      String content = (String) message.get('content');

      Map<String, Object> classification = JsonResponseParser.parseLLMContent(
        content
      );

      result.category = (String) classification.get('category');
      result.priority = (String) classification.get('priority');
      result.sentiment = (String) classification.get('sentiment');
      result.summary = (String) classification.get('summary');
      result.suggestedResponse = (String) classification.get(
        'suggested_response'
      );
      result.confidence = toDecimal(classification.get('confidence'));

      result.isSuccess = true;
      return result;
    } catch (Exception e) {
      result.errorMessage = 'Parse error: ' + e.getMessage();
      return result;
    }
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
