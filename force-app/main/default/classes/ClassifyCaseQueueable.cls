public with sharing class ClassifyCaseQueueable implements Queueable, Database.AllowsCallouts {

    private static final Integer RAW_FIELD_MAX_LENGTH = 32768;

    private final Set<Id> caseIds;

    public ClassifyCaseQueueable(Set<Id> caseIds) {
        this.caseIds = caseIds;
    }

    public void execute(QueueableContext context) {
        if (caseIds == null || caseIds.isEmpty()) {
            return;
        }

        List<Case> cases = [
            SELECT Id, Subject, Description
            FROM Case
            WHERE Id IN :caseIds
        ];

        if (cases.isEmpty()) {
            return;
        }

        ILLMService llm = LLMServiceFactory.getService();

        List<Case> caseUpdates = new List<Case>();
        List<Case_AI_Analysis__c> auditRecords = new List<Case_AI_Analysis__c>();
        List<Case_AI_Classified__e> events = new List<Case_AI_Classified__e>();

        for (Case c : cases) {
            String text = buildCaseText(c);
            CaseClassificationResult result = llm.classify(text);

            caseUpdates.add(buildCaseUpdate(c.Id, result));
            auditRecords.add(buildAuditRecord(c.Id, result));
            events.add(buildEvent(c.Id, result));
        }

        CaseTriggerHandler.bypass();
        try {
            update caseUpdates;
            insert auditRecords;
            EventBus.publish(events);
        } finally {
            CaseTriggerHandler.unbypass();
        }
    }

    private String buildCaseText(Case c) {
        String subject = c.Subject == null ? '' : c.Subject;
        String description = c.Description == null ? '' : c.Description;
        return (subject + '\n\n' + description).trim();
    }

    private Case buildCaseUpdate(Id caseId, CaseClassificationResult result) {
        Case toUpdate = new Case(Id = caseId);
        if (result.isSuccess) {
            toUpdate.AI_Category__c = result.category;
            toUpdate.AI_Priority__c = result.priority;
            toUpdate.AI_Sentiment__c = result.sentiment;
            toUpdate.AI_Summary__c = result.summary;
            toUpdate.AI_Suggested_Response__c = result.suggestedResponse;
            toUpdate.AI_Confidence_Score__c = result.confidence;
            toUpdate.AI_Last_Classified__c = System.now();
            toUpdate.AI_Classification_Status__c = 'Completed';
        } else {
            toUpdate.AI_Classification_Status__c = 'Failed';
        }
        return toUpdate;
    }

    private Case_AI_Analysis__c buildAuditRecord(Id caseId, CaseClassificationResult result) {
        return new Case_AI_Analysis__c(
            Case__c = caseId,
            Status__c = result.isSuccess ? 'Success' : 'Failed',
            Model_Used__c = result.modelUsed,
            Raw_Request__c = truncateLong(result.rawRequest),
            Raw_Response__c = truncateLong(result.rawResponse),
            Input_Tokens__c = result.inputTokens,
            Output_Tokens__c = result.outputTokens,
            Processing_Time_Ms__c = result.processingTimeMs,
            Error_Message__c = truncateLong(result.errorMessage)
        );
    }

    private Case_AI_Classified__e buildEvent(Id caseId, CaseClassificationResult result) {
        Case_AI_Classified__e evt = new Case_AI_Classified__e(
            Case_Id__c = String.valueOf(caseId),
            Status__c = result.isSuccess ? 'Success' : 'Failed',
            Category__c = result.category,
            Priority__c = result.priority,
            Sentiment__c = result.sentiment
        );
        if (result.errorMessage != null) {
            evt.Error_Message__c = result.errorMessage.length() > 255
                ? result.errorMessage.substring(0, 255)
                : result.errorMessage;
        }
        return evt;
    }

    private String truncateLong(String s) {
        if (s == null) return null;
        return s.length() > RAW_FIELD_MAX_LENGTH ? s.substring(0, RAW_FIELD_MAX_LENGTH) : s;
    }
}
