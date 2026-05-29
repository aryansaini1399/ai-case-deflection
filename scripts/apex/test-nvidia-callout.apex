// Smoke test: verifies Named Credential + External Credential + API key are all wired correctly.
// Run via VS Code: right-click → "SFDX: Execute Anonymous Apex with Currently Selected Text"
// Or paste into Developer Console → Debug → Open Execute Anonymous Window

HttpRequest req = new HttpRequest();
req.setEndpoint('callout:NVIDIA_NIM/v1/chat/completions');
req.setMethod('POST');
req.setHeader('Content-Type', 'application/json');
req.setTimeout(30000);

Map<String, Object> body = new Map<String, Object>{
    'model' => 'meta/llama-3.3-70b-instruct',
    'messages' => new List<Map<String, String>>{
        new Map<String, String>{
            'role' => 'user',
            'content' => 'Classify this case in JSON only (no markdown): "My login button is broken on the iPhone app". Use keys: category, priority.'
        }
    },
    'max_tokens' => 100,
    'temperature' => 0.2
};
req.setBody(JSON.serialize(body));

System.debug('=== REQUEST ===');
System.debug('Endpoint resolved by Salesforce: callout:NVIDIA_NIM/v1/chat/completions');
System.debug('Body: ' + req.getBody());

Long start = System.currentTimeMillis();
HttpResponse res = new Http().send(req);
Long latency = System.currentTimeMillis() - start;

System.debug('=== RESPONSE ===');
System.debug('Status Code: ' + res.getStatusCode());
System.debug('Latency (ms): ' + latency);
System.debug('Body: ' + res.getBody());

if (res.getStatusCode() == 200) {
    System.debug('SUCCESS: Named Credential + External Credential + API key all working.');
} else if (res.getStatusCode() == 401) {
    System.debug('AUTH FAILED: API key is invalid or expired. Re-generate at build.nvidia.com and update the Principal.');
} else if (res.getStatusCode() == 429) {
    System.debug('RATE LIMITED / OUT OF CREDITS: Free tier exhausted. Generate new key or wait for monthly reset.');
} else {
    System.debug('UNEXPECTED ERROR: Check response body above for details.');
}
