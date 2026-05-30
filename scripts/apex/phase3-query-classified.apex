// Query the most recently classified case to verify the async pipeline worked.
// Run via VS Code: select all → "SFDX: Execute Anonymous Apex with Currently Selected Text"

List<Case> cases = [
    SELECT Id, Subject, AI_Category__c, AI_Priority__c, AI_Sentiment__c,
           AI_Summary__c, AI_Suggested_Response__c, AI_Confidence_Score__c,
           AI_Classification_Status__c, AI_Last_Classified__c,
           (SELECT Status__c, Model_Used__c, Input_Tokens__c, Output_Tokens__c,
                   Processing_Time_Ms__c
            FROM AI_Analyses__r
            ORDER BY CreatedDate DESC
            LIMIT 1)
    FROM Case
    WHERE AI_Last_Classified__c != NULL
    ORDER BY AI_Last_Classified__c DESC
    LIMIT 1
];

if (cases.isEmpty()) {
    System.debug('No classified cases found yet. ');
    System.debug('Either no case has been created with Subject/Description, OR the async job is still running.');
    System.debug('Wait 5-10 seconds and try again.');
    return;
}

Case c = cases[0];
System.debug('=== MOST RECENT CLASSIFIED CASE ===');
System.debug('ID:                 ' + c.Id);
System.debug('Subject:            ' + c.Subject);
System.debug('-----');
System.debug('AI Category:        ' + c.AI_Category__c);
System.debug('AI Priority:        ' + c.AI_Priority__c);
System.debug('AI Sentiment:       ' + c.AI_Sentiment__c);
System.debug('AI Confidence:      ' + c.AI_Confidence_Score__c);
System.debug('AI Status:          ' + c.AI_Classification_Status__c);
System.debug('Classified At:      ' + c.AI_Last_Classified__c);
System.debug('-----');
System.debug('AI Summary:         ' + c.AI_Summary__c);
System.debug('AI Suggested Resp:  ' + c.AI_Suggested_Response__c);

if (!c.AI_Analyses__r.isEmpty()) {
    Case_AI_Analysis__c audit = c.AI_Analyses__r[0];
    System.debug('=== AUDIT LOG ===');
    System.debug('Model:              ' + audit.Model_Used__c);
    System.debug('Status:             ' + audit.Status__c);
    System.debug('Input Tokens:       ' + audit.Input_Tokens__c);
    System.debug('Output Tokens:      ' + audit.Output_Tokens__c);
    System.debug('Processing Time:    ' + audit.Processing_Time_Ms__c + 'ms');
}
