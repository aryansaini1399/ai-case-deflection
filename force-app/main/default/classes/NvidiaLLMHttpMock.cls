@isTest
public class NvidiaLLMHttpMock implements HttpCalloutMock {

    public Integer statusCode = 200;
    public String responseBody;

    public static NvidiaLLMHttpMock success() {
        NvidiaLLMHttpMock m = new NvidiaLLMHttpMock();
        m.statusCode = 200;
        String innerJson = JSON.serialize(new Map<String, Object>{
            'category' => 'Billing',
            'priority' => 'High',
            'sentiment' => 'Frustrated',
            'summary' => 'Customer disputes duplicate charge on May invoice',
            'suggested_response' => 'I am sorry to hear about the duplicate charge. I have escalated this to our billing team and a refund will be processed within 3-5 business days.',
            'confidence' => 0.92
        });
        m.responseBody = JSON.serialize(new Map<String, Object>{
            'choices' => new List<Object>{
                new Map<String, Object>{
                    'message' => new Map<String, Object>{
                        'content' => '```json\n' + innerJson + '\n```'
                    }
                }
            },
            'usage' => new Map<String, Object>{
                'prompt_tokens' => 142,
                'completion_tokens' => 87
            }
        });
        return m;
    }

    public static NvidiaLLMHttpMock unauthorized() {
        NvidiaLLMHttpMock m = new NvidiaLLMHttpMock();
        m.statusCode = 401;
        m.responseBody = '{"error":"Invalid API key"}';
        return m;
    }

    public static NvidiaLLMHttpMock malformedContent() {
        NvidiaLLMHttpMock m = new NvidiaLLMHttpMock();
        m.statusCode = 200;
        m.responseBody = JSON.serialize(new Map<String, Object>{
            'choices' => new List<Object>{
                new Map<String, Object>{
                    'message' => new Map<String, Object>{
                        'content' => 'this is not json at all, just some text'
                    }
                }
            }
        });
        return m;
    }

    public static NvidiaLLMHttpMock emptyChoices() {
        NvidiaLLMHttpMock m = new NvidiaLLMHttpMock();
        m.statusCode = 200;
        m.responseBody = '{"choices":[]}';
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
