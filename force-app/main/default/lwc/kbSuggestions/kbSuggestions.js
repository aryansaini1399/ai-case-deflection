import { LightningElement, api, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { subscribe, MessageContext } from "lightning/messageService";
import AI_INSIGHTS_CHANNEL from "@salesforce/messageChannel/AIInsightsChannel__c";
import findRelevantArticles from "@salesforce/apex/KnowledgeArticleService.findRelevantArticles";
import markHelpful from "@salesforce/apex/KnowledgeArticleService.markHelpful";

export default class KbSuggestions extends NavigationMixin(LightningElement) {
  @api recordId;
  @api topN = 3;

  @wire(MessageContext) messageContext;

  suggestions = [];
  isLoading = true;
  isError = false;
  errorMessage;
  insightsSubscription;

  connectedCallback() {
    this.loadSuggestions();
    this.subscribeToInsightsChannel();
  }

  disconnectedCallback() {
    this.insightsSubscription = null;
  }

  subscribeToInsightsChannel() {
    if (this.insightsSubscription || !this.messageContext) return;
    this.insightsSubscription = subscribe(
      this.messageContext,
      AI_INSIGHTS_CHANNEL,
      (msg) => {
        if (msg && msg.caseId === this.recordId) {
          this.loadSuggestions();
        }
      }
    );
  }

  async loadSuggestions() {
    this.isLoading = true;
    this.isError = false;
    try {
      const results = await findRelevantArticles({
        caseId: this.recordId,
        topN: Number(this.topN)
      });
      this.suggestions = (results || []).map((s) => ({
        ...s,
        scoreDisplay:
          s.relevanceScore != null
            ? `${Math.round(s.relevanceScore * 100)}%`
            : "N/A"
      }));
    } catch (e) {
      this.isError = true;
      this.errorMessage =
        e?.body?.message || e?.message || "Failed to load suggestions";
      this.suggestions = [];
    } finally {
      this.isLoading = false;
    }
  }

  handleRefresh() {
    this.loadSuggestions();
  }

  handleOpenArticle(event) {
    const articleId = event.currentTarget.dataset.id;
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: articleId,
        objectApiName: "Knowledge_Article__c",
        actionName: "view"
      }
    });
  }

  async handleMarkHelpful(event) {
    const articleId = event.currentTarget.dataset.id;
    try {
      await markHelpful({ articleId });
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Marked helpful",
          message: "Thanks for the feedback!",
          variant: "success"
        })
      );
      this.suggestions = this.suggestions.map((s) => {
        if (s.articleId !== articleId) return s;
        return { ...s, helpfulCount: (s.helpfulCount || 0) + 1 };
      });
    } catch (e) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: e?.body?.message || "Failed to record feedback",
          variant: "error"
        })
      );
    }
  }

  handleCopyLink(event) {
    const articleId = event.currentTarget.dataset.id;
    const url = `${window.location.origin}/lightning/r/Knowledge_Article__c/${articleId}/view`;
    if (navigator.clipboard) {
      navigator.clipboard.writeText(url).then(() => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Copied",
            message: "Article link copied to clipboard.",
            variant: "success"
          })
        );
      });
    }
  }

  get hasSuggestions() {
    return !this.isLoading && !this.isError && this.suggestions.length > 0;
  }
}
