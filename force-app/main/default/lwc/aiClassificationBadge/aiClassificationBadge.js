import { LightningElement, api } from "lwc";

const PRIORITY_STYLES = {
  Low: "slds-theme_success",
  Medium: "slds-theme_warning",
  High: "slds-theme_warning",
  Critical: "slds-theme_error"
};

const SENTIMENT_STYLES = {
  Positive: "slds-theme_success",
  Neutral: "slds-theme_alt-inverse",
  Negative: "slds-theme_warning",
  Frustrated: "slds-theme_error"
};

const SENTIMENT_ICONS = {
  Positive: "utility:smiley_and_people",
  Neutral: "utility:emoji",
  Negative: "utility:frown",
  Frustrated: "utility:warning"
};

const CATEGORY_CLASS = "slds-theme_inverse";

export default class AiClassificationBadge extends LightningElement {
  @api type;
  @api value;

  get badgeClass() {
    const base = "slds-badge slds-m-right_x-small";
    if (this.type === "priority") {
      return `${base} ${PRIORITY_STYLES[this.value] || ""}`;
    }
    if (this.type === "sentiment") {
      return `${base} ${SENTIMENT_STYLES[this.value] || ""}`;
    }
    return `${base} ${CATEGORY_CLASS}`;
  }

  get iconName() {
    if (this.type === "sentiment") {
      return SENTIMENT_ICONS[this.value] || null;
    }
    return null;
  }

  get tooltipText() {
    return `${this.type}: ${this.value}`;
  }
}
