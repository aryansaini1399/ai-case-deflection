public class JsonResponseParser {

    private static final Pattern MARKDOWN_FENCE_PATTERN =
        Pattern.compile('(?s)^\\s*```(?:json)?\\s*(.*?)\\s*```\\s*$');

    public static String stripMarkdownFences(String input) {
        if (String.isBlank(input)) {
            return input;
        }
        Matcher m = MARKDOWN_FENCE_PATTERN.matcher(input);
        return m.matches() ? m.group(1) : input;
    }

    public static Map<String, Object> parseLLMContent(String content) {
        if (String.isBlank(content)) {
            throw new LLMException('LLM content is blank — nothing to parse');
        }
        String cleaned = stripMarkdownFences(content);
        try {
            return (Map<String, Object>) JSON.deserializeUntyped(cleaned);
        } catch (Exception e) {
            throw new LLMException(
                'Failed to parse LLM JSON output: ' + e.getMessage() +
                '. Cleaned content (first 500 chars): ' +
                (cleaned.length() > 500 ? cleaned.substring(0, 500) : cleaned)
            );
        }
    }
}
