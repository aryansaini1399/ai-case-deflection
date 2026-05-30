public class LLMServiceFactory {

    public static ILLMService getService() {
        return new NvidiaLLMService();
    }

    public static ILLMService getService(String model) {
        return new NvidiaLLMService(model);
    }
}
