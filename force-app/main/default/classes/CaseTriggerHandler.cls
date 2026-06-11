public with sharing class CaseTriggerHandler {
  @TestVisible
  private static Boolean bypassed = false;

  public static void bypass() {
    bypassed = true;
  }

  public static void unbypass() {
    bypassed = false;
  }

  public void run() {
    if (bypassed || !Trigger.isExecuting) {
      return;
    }

    if (Trigger.isAfter) {
      if (Trigger.isInsert) {
        handleAfterInsert((List<Case>) Trigger.new);
      } else if (Trigger.isUpdate) {
        handleAfterUpdate(
          (List<Case>) Trigger.new,
          (Map<Id, Case>) Trigger.oldMap
        );
      }
    }
  }

  private void handleAfterInsert(List<Case> newCases) {
    Set<Id> caseIds = new Set<Id>();
    for (Case c : newCases) {
      // Skip cases that were pre-classified by the customer portal (Phase 6) -
      // they already have category/priority/sentiment populated.
      if (c.AI_Classification_Status__c == 'Completed')
        continue;
      if (String.isNotBlank(c.Subject) || String.isNotBlank(c.Description)) {
        caseIds.add(c.Id);
      }
    }
    if (!caseIds.isEmpty()) {
      System.enqueueJob(new ClassifyCaseQueueable(caseIds));
    }
  }

  private void handleAfterUpdate(List<Case> newCases, Map<Id, Case> oldMap) {
    Set<Id> caseIds = new Set<Id>();
    for (Case c : newCases) {
      Case oldCase = oldMap.get(c.Id);
      Boolean subjectChanged = c.Subject != oldCase.Subject;
      Boolean descChanged = c.Description != oldCase.Description;
      if (subjectChanged || descChanged) {
        caseIds.add(c.Id);
      }
    }
    if (!caseIds.isEmpty()) {
      System.enqueueJob(new ClassifyCaseQueueable(caseIds));
    }
  }
}
