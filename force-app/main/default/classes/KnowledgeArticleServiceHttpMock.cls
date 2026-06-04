@isTest
public class KnowledgeArticleServiceHttpMock implements HttpCalloutMock {
  public Integer statusCode = 200;
  public String responseBody;

  public static KnowledgeArticleServiceHttpMock success(
    List<Integer> rankedIndices
  ) {
    KnowledgeArticleServiceHttpMock m = new KnowledgeArticleServiceHttpMock();
    m.statusCode = 200;
    List<Object> ranked = new List<Object>();
    Decimal score = 0.95;
    for (Integer idx : rankedIndices) {
      ranked.add(
        new Map<String, Object>{
          'index' => idx,
          'score' => score,
          'reasoning' => 'Mock reasoning for article index ' + idx
        }
      );
      score = score - 0.1;
    }
    String innerJson = JSON.serialize(
      new Map<String, Object>{ 'ranked' => ranked }
    );
    m.responseBody = JSON.serialize(
      new Map<String, Object>{
        'choices' => new List<Object>{
          new Map<String, Object>{
            'message' => new Map<String, Object>{
              'content' => '```json\n' +
              innerJson +
              '\n```'
            }
          }
        }
      }
    );
    return m;
  }

  public static KnowledgeArticleServiceHttpMock failure(Integer code) {
    KnowledgeArticleServiceHttpMock m = new KnowledgeArticleServiceHttpMock();
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
