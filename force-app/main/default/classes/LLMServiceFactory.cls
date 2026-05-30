public class LLMServiceFactory {

    @TestVisible
    private static ILLMService mockService;

    public static ILLMService getService() {
        if (mockService != null) return mockService;
        return new NvidiaLLMService();
    }

    public static ILLMService getService(String model) {
        if (mockService != null) return mockService;
        return new NvidiaLLMService(model);
    }

    @TestVisible
    private static void setMock(ILLMService mock) {
        mockService = mock;
    }
}
