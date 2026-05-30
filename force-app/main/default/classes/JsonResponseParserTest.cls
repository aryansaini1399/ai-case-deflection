@isTest
private class JsonResponseParserTest {

    @isTest
    static void stripsMarkdownFencesWithJsonLanguageHint() {
        String input = '```json\n{"a":1}\n```';
        System.assertEquals('{"a":1}', JsonResponseParser.stripMarkdownFences(input));
    }

    @isTest
    static void stripsMarkdownFencesWithoutLanguageHint() {
        String input = '```\n{"b":2}\n```';
        System.assertEquals('{"b":2}', JsonResponseParser.stripMarkdownFences(input));
    }

    @isTest
    static void leavesPlainJsonUnchanged() {
        String input = '{"c":3}';
        System.assertEquals('{"c":3}', JsonResponseParser.stripMarkdownFences(input));
    }

    @isTest
    static void handlesNullAndBlankInput() {
        System.assertEquals(null, JsonResponseParser.stripMarkdownFences(null));
        System.assertEquals('', JsonResponseParser.stripMarkdownFences(''));
        System.assertEquals('   ', JsonResponseParser.stripMarkdownFences('   '));
    }

    @isTest
    static void parsesLLMContentWithMarkdownFences() {
        String content = '```json\n{"key":"value","count":42}\n```';
        Map<String, Object> parsed = JsonResponseParser.parseLLMContent(content);
        System.assertEquals('value', parsed.get('key'));
        System.assertEquals(42, parsed.get('count'));
    }

    @isTest
    static void parsesLLMContentWithoutFences() {
        String content = '{"plain":"json"}';
        Map<String, Object> parsed = JsonResponseParser.parseLLMContent(content);
        System.assertEquals('json', parsed.get('plain'));
    }

    @isTest
    static void throwsLLMExceptionOnBlankInput() {
        try {
            JsonResponseParser.parseLLMContent('');
            System.assert(false, 'Expected LLMException to be thrown');
        } catch (LLMException e) {
            System.assert(e.getMessage().contains('blank'));
        }
    }

    @isTest
    static void throwsLLMExceptionOnInvalidJson() {
        try {
            JsonResponseParser.parseLLMContent('this is not json');
            System.assert(false, 'Expected LLMException to be thrown');
        } catch (LLMException e) {
            System.assert(e.getMessage().startsWith('Failed to parse'));
        }
    }
}
