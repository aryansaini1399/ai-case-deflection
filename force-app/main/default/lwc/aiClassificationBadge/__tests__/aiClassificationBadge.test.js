import { createElement } from "lwc";
import AiClassificationBadge from "c/aiClassificationBadge";

describe("c-ai-classification-badge", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders nothing when value is null", () => {
    const element = createElement("c-ai-classification-badge", {
      is: AiClassificationBadge
    });
    element.type = "category";
    element.value = null;
    document.body.appendChild(element);

    const badge = element.shadowRoot.querySelector("span");
    expect(badge).toBeNull();
  });

  it("renders the value as a badge for a category", () => {
    const element = createElement("c-ai-classification-badge", {
      is: AiClassificationBadge
    });
    element.type = "category";
    element.value = "Billing";
    document.body.appendChild(element);

    const badge = element.shadowRoot.querySelector("span");
    expect(badge).not.toBeNull();
    expect(badge.textContent.trim()).toBe("Billing");
    expect(badge.className).toContain("slds-badge");
    expect(badge.className).toContain("slds-theme_inverse");
  });

  it("applies error styling for Critical priority", () => {
    const element = createElement("c-ai-classification-badge", {
      is: AiClassificationBadge
    });
    element.type = "priority";
    element.value = "Critical";
    document.body.appendChild(element);

    const badge = element.shadowRoot.querySelector("span");
    expect(badge.className).toContain("slds-theme_error");
  });

  it("shows a sentiment icon for Frustrated", () => {
    const element = createElement("c-ai-classification-badge", {
      is: AiClassificationBadge
    });
    element.type = "sentiment";
    element.value = "Frustrated";
    document.body.appendChild(element);

    const icon = element.shadowRoot.querySelector("lightning-icon");
    expect(icon).not.toBeNull();
    expect(icon.iconName).toBe("utility:warning");
  });

  it("produces a tooltip describing the badge type and value", () => {
    const element = createElement("c-ai-classification-badge", {
      is: AiClassificationBadge
    });
    element.type = "sentiment";
    element.value = "Positive";
    document.body.appendChild(element);

    const badge = element.shadowRoot.querySelector("span");
    expect(badge.title).toBe("sentiment: Positive");
  });
});
