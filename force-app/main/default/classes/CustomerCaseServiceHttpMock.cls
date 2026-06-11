@isTest
public class CustomerCaseServiceHttpMock implements HttpCalloutMock {
  public Integer statusCode = 200;
  public String responseBody;

  public static CustomerCaseServiceHttpMock success(
    List<Integer> rankedIndices
  ) {
    CustomerCaseServiceHttpMock m = new CustomerCaseServiceHttpMock();
    m.statusCode = 200;

    List<Object> articles = new List<Object>();
    Decimal score = 0.95;
    for (Integer idx : rankedIndices) {
      articles.add(
        new Map<String, Object>{
          'index' => idx,
          'score' => score,
          'reasoning' => 'Mock reasoning for article index ' + idx
        }
      );
      score = score - 0.1;
    }

    String innerJson = JSON.serialize(
      new Map<String, Object>{
        'predictedCategory' => 'Account Access',
        'predictedPriority' => 'High',
        'predictedSentiment' => 'Frustrated',
        'summary' => 'Customer cannot reset password',
        'confidence' => 0.9,
        'articles' => articles
      }
    );

    m.responseBody = JSON.serialize(
      new Map<String, Object>{
        'choices' => new List<Object>{
          new Map<String, Object>{
            'message' => new Map<String, Object>{ 'content' => innerJson }
          }
        },
        'usage' => new Map<String, Object>{
          'prompt_tokens' => 150,
          'completion_tokens' => 100
        }
      }
    );
    return m;
  }

  public static CustomerCaseServiceHttpMock failure(Integer code) {
    CustomerCaseServiceHttpMock m = new CustomerCaseServiceHttpMock();
    m.statusCode = code;
    m.responseBody = '{"error":"Mock failure"}';
    return m;
  }

  public HttpResponse respond(HttpRequest req) {
    HttpResponse res = new HttpResponse();
    res.setStatusCode(this.statusCode);
    res.setBody(this.responseBody);
    res.setHeader('Content-Type', 'application/json');
    return res;
  }
}
