import { LightningElement, track } from "lwc";
import getSuggestions from "@salesforce/apex/CustomerCaseService.getSuggestions";
import submitCase from "@salesforce/apex/CustomerCaseService.submitCase";
import markArticleHelpful from "@salesforce/apex/CustomerCaseService.markArticleHelpful";

const STATE = {
  DESCRIBE: "DESCRIBE",
  SUGGESTIONS: "SUGGESTIONS",
  COLLECT_EMAIL: "COLLECT_EMAIL",
  SUBMITTED: "SUBMITTED",
  DEFLECTED: "DEFLECTED"
};

export default class CustomerCaseSubmission extends LightningElement {
  @track state = STATE.DESCRIBE;
  @track customerText = "";
  @track customerEmail = "";
  @track prediction = null;
  @track submittedCaseNumber = "";
  @track errorMessage = "";
  @track isLoading = false;
  @track isSubmitting = false;
  @track expandedArticleId = null;

  lastReadArticleId = null;

  // ── getters: states ────────────────────────────────────────

  get isDescribeState() {
    return this.state === STATE.DESCRIBE;
  }

  get isSuggestionsState() {
    return this.state === STATE.SUGGESTIONS;
  }

  get isCollectEmailState() {
    return this.state === STATE.COLLECT_EMAIL;
  }

  get isSubmittedState() {
    return this.state === STATE.SUBMITTED;
  }

  get isDeflectedState() {
    return this.state === STATE.DEFLECTED;
  }

  // ── getters: derived ───────────────────────────────────────

  get isFindHelpDisabled() {
    return this.isLoading || (this.customerText || "").trim().length < 10;
  }

  get isSubmitDisabled() {
    return this.isSubmitting || !this.isValidEmail(this.customerEmail);
  }

  get hasPrediction() {
    return !!(this.prediction && this.prediction.predictedCategory);
  }

  get hasArticles() {
    return !!(
      this.prediction &&
      this.prediction.articles &&
      this.prediction.articles.length > 0
    );
  }

  get decoratedArticles() {
    if (!this.prediction || !this.prediction.articles) return [];
    return this.prediction.articles.map((a) => {
      const isExpanded = a.articleId === this.expandedArticleId;
      return {
        ...a,
        isExpanded,
        displayBody: isExpanded ? a.body : a.bodySnippet,
        toggleLabel: isExpanded ? "Show less" : "Read more"
      };
    });
  }

  get hasError() {
    return !!this.errorMessage;
  }

  // ── handlers ───────────────────────────────────────────────

  handleTextChange(event) {
    this.customerText = event.target.value || "";
    this.errorMessage = "";
  }

  handleEmailChange(event) {
    this.customerEmail = event.target.value || "";
  }

  async handleFindHelp() {
    this.isLoading = true;
    this.errorMessage = "";
    try {
      const result = await getSuggestions({
        customerText: this.customerText,
        topN: 3
      });
      if (!result.isSuccess) {
        // No deflection possible - skip directly to email collection
        this.errorMessage = result.errorMessage || "";
        this.prediction = result;
        this.state = STATE.SUGGESTIONS;
        return;
      }
      this.prediction = this.decorateResult(result);
      this.state = STATE.SUGGESTIONS;
    } catch (e) {
      this.errorMessage =
        e?.body?.message || e?.message || "Something went wrong.";
    } finally {
      this.isLoading = false;
    }
  }

  handleToggleArticle(event) {
    const articleId = event.currentTarget.dataset.id;
    if (this.expandedArticleId === articleId) {
      this.expandedArticleId = null;
    } else {
      this.expandedArticleId = articleId;
      this.lastReadArticleId = articleId;
    }
  }

  async handleDeflected() {
    if (this.lastReadArticleId) {
      try {
        await markArticleHelpful({ articleId: this.lastReadArticleId });
      } catch {
        // Non-blocking - deflection success doesn't depend on this
      }
    }
    this.state = STATE.DEFLECTED;
  }

  handleStillNeedHelp() {
    this.state = STATE.COLLECT_EMAIL;
  }

  handleBack() {
    this.state = STATE.SUGGESTIONS;
  }

  async handleSubmit() {
    this.isSubmitting = true;
    this.errorMessage = "";
    try {
      const caseNumber = await submitCase({
        customerText: this.customerText,
        email: this.customerEmail,
        preClassification: this.stripDecorations(this.prediction)
      });
      this.submittedCaseNumber = caseNumber;
      this.state = STATE.SUBMITTED;
    } catch (e) {
      this.errorMessage =
        e?.body?.message || e?.message || "Failed to submit case.";
    } finally {
      this.isSubmitting = false;
    }
  }

  handleStartOver() {
    this.state = STATE.DESCRIBE;
    this.customerText = "";
    this.customerEmail = "";
    this.prediction = null;
    this.submittedCaseNumber = "";
    this.errorMessage = "";
    this.lastReadArticleId = null;
  }

  // ── helpers ────────────────────────────────────────────────

  decorateResult(result) {
    const decorated = { ...result };
    decorated.articles = (result.articles || []).map((a) => ({
      ...a,
      scoreDisplay:
        a.relevanceScore != null
          ? `${Math.round(a.relevanceScore * 100)}%`
          : "N/A"
    }));
    return decorated;
  }

  stripDecorations(decorated) {
    if (!decorated) return null;
    const cleaned = { ...decorated };
    if (cleaned.articles) {
      cleaned.articles = cleaned.articles.map((a) => {
        const copy = { ...a };
        delete copy.scoreDisplay;
        return copy;
      });
    }
    return cleaned;
  }

  isValidEmail(email) {
    return !!email && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  }
}
