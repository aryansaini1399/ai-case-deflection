import { LightningElement, api, wire } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import { refreshApex } from "@salesforce/apex";
import { subscribe, unsubscribe, onError } from "lightning/empApi";
import { publish, MessageContext } from "lightning/messageService";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import AI_INSIGHTS_CHANNEL from "@salesforce/messageChannel/AIInsightsChannel__c";

import CASE_AI_CATEGORY from "@salesforce/schema/Case.AI_Category__c";
import CASE_AI_PRIORITY from "@salesforce/schema/Case.AI_Priority__c";
import CASE_AI_SENTIMENT from "@salesforce/schema/Case.AI_Sentiment__c";
import CASE_AI_SUMMARY from "@salesforce/schema/Case.AI_Summary__c";
import CASE_AI_SUGGESTED_RESPONSE from "@salesforce/schema/Case.AI_Suggested_Response__c";
import CASE_AI_CONFIDENCE from "@salesforce/schema/Case.AI_Confidence_Score__c";
import CASE_AI_STATUS from "@salesforce/schema/Case.AI_Classification_Status__c";
import CASE_AI_LAST_CLASSIFIED from "@salesforce/schema/Case.AI_Last_Classified__c";

const FIELDS = [
  CASE_AI_CATEGORY,
  CASE_AI_PRIORITY,
  CASE_AI_SENTIMENT,
  CASE_AI_SUMMARY,
  CASE_AI_SUGGESTED_RESPONSE,
  CASE_AI_CONFIDENCE,
  CASE_AI_STATUS,
  CASE_AI_LAST_CLASSIFIED
];

const EVENT_CHANNEL = "/event/Case_AI_Classified__e";

export default class AgentAiInsights extends LightningElement {
  @api recordId;

  @wire(MessageContext) messageContext;

  wiredCase;
  eventSubscription;

  @wire(getRecord, { recordId: "$recordId", fields: FIELDS })
  wiredCaseHandler(result) {
    this.wiredCase = result;
  }

  connectedCallback() {
    this.subscribeToPlatformEvent();
  }

  disconnectedCallback() {
    this.unsubscribeFromPlatformEvent();
  }

  subscribeToPlatformEvent() {
    const callback = (event) => {
      const payload = event?.data?.payload;
      if (payload?.Case_Id__c === this.recordId) {
        refreshApex(this.wiredCase);
        this.publishToChannel(payload);
      }
    };

    subscribe(EVENT_CHANNEL, -1, callback)
      .then((sub) => {
        this.eventSubscription = sub;
      })
      .catch((err) => {
        console.error("empApi subscribe failed", err);
      });

    onError((error) => {
      console.error("empApi error", JSON.stringify(error));
    });
  }

  unsubscribeFromPlatformEvent() {
    if (this.eventSubscription) {
      unsubscribe(this.eventSubscription, () => {
        this.eventSubscription = null;
      });
    }
  }

  publishToChannel(payload) {
    if (!this.messageContext) return;
    publish(this.messageContext, AI_INSIGHTS_CHANNEL, {
      caseId: payload.Case_Id__c,
      category: payload.Category__c,
      priority: payload.Priority__c,
      sentiment: payload.Sentiment__c
    });
  }

  handleRefresh() {
    if (this.wiredCase) {
      refreshApex(this.wiredCase);
    }
  }

  handleCopy() {
    const text = this.suggestedResponse;
    if (!text) return;
    if (navigator.clipboard) {
      navigator.clipboard.writeText(text).then(() => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Copied",
            message: "Suggested response copied to clipboard.",
            variant: "success"
          })
        );
      });
    }
  }

  // ── getters ────────────────────────────────────────────────

  get isLoading() {
    return !this.wiredCase || (!this.wiredCase.data && !this.wiredCase.error);
  }

  get isError() {
    return !!(this.wiredCase && this.wiredCase.error);
  }

  get errorMessage() {
    const err = this.wiredCase?.error;
    return err?.body?.message || "Failed to load AI insights";
  }

  get status() {
    return getFieldValue(this.wiredCase?.data, CASE_AI_STATUS);
  }

  get isPending() {
    return this.status === "Pending" || this.status === "Processing";
  }

  get isFailed() {
    return this.status === "Failed";
  }

  get hasResults() {
    return this.status === "Completed";
  }

  get category() {
    return getFieldValue(this.wiredCase?.data, CASE_AI_CATEGORY);
  }

  get priority() {
    return getFieldValue(this.wiredCase?.data, CASE_AI_PRIORITY);
  }

  get sentiment() {
    return getFieldValue(this.wiredCase?.data, CASE_AI_SENTIMENT);
  }

  get summary() {
    return getFieldValue(this.wiredCase?.data, CASE_AI_SUMMARY);
  }

  get suggestedResponse() {
    return getFieldValue(this.wiredCase?.data, CASE_AI_SUGGESTED_RESPONSE);
  }

  get confidenceDisplay() {
    const c = getFieldValue(this.wiredCase?.data, CASE_AI_CONFIDENCE);
    return c != null ? Number(c).toFixed(2) : "N/A";
  }

  get lastClassifiedFormatted() {
    const t = getFieldValue(this.wiredCase?.data, CASE_AI_LAST_CLASSIFIED);
    if (!t) return "Never";
    try {
      return new Intl.DateTimeFormat(undefined, {
        dateStyle: "medium",
        timeStyle: "short"
      }).format(new Date(t));
    } catch {
      return t;
    }
  }
}
