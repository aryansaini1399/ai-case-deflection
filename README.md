# AI Case Deflection Platform

> A production-grade Salesforce app that uses **Llama 3.3 70B (via NVIDIA NIM)** to deflect support cases at the customer portal and accelerate agents with real-time AI insights. Built entirely on the Salesforce Platform (Apex, LWC, Experience Cloud) with full DevOps hygiene.

[![Salesforce](https://img.shields.io/badge/Salesforce-Platform-00A1E0)](https://developer.salesforce.com)
[![LWC](https://img.shields.io/badge/UI-Lightning_Web_Components-1798c1)](https://developer.salesforce.com/docs/component-library)
[![Apex](https://img.shields.io/badge/Backend-Apex_API_66.0-22d3ee)](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref)
[![Tests](https://img.shields.io/badge/Apex_Coverage-96%25-brightgreen)](#metrics)
[![LLM](https://img.shields.io/badge/LLM-Llama_3.3_70B-7c3aed)](https://build.nvidia.com)

---

## 🎯 What It Does

**Two AI features, one goal: shorter support cycles.**

- **🛡️ Customer-side deflection** — Before submitting a case, the customer's issue is run through an LLM that classifies it and surfaces the most relevant knowledge articles. If an article solves it, no case is ever created (~40% deflection rate is the industry target).
- **⚡ Agent-side acceleration** — Cases that do come through are pre-classified within seconds. The agent's console shows category, priority, sentiment, summary, a draft response, and the top 3 KB articles — all updated **live** via Salesforce Platform Events.

---

## 🌍 Live Demo

**Public portal** (no Salesforce login required):

```
https://orgfarm-722de4f700-dev-ed.develop.my.site.com/aihelpvforcesite/
```

Try typing: _"I cannot reset my password. The reset email never arrives."_

The AI will classify your issue and suggest articles in ~2-3 seconds.

---

## ✨ Features

### Agent-Facing (inside Salesforce)

| Feature                                          | Implementation                                                   |
| ------------------------------------------------ | ---------------------------------------------------------------- |
| Real-time AI Insights panel on every Case        | LWC subscribes to `Case_AI_Classified__e` via `lightning/empApi` |
| Auto-categorization, priority, sentiment scoring | Llama 3.3 via NVIDIA NIM, called from Apex Queueable             |
| One-sentence AI summary of the case              | Same LLM call, structured JSON output                            |
| Draft response suggestion (copy-ready)           | Same LLM call, 2-4 sentence professional template                |
| Top-3 ranked KB articles (RAG-style)             | Separate semantic ranking call                                   |
| Real-time updates on any case re-classification  | Platform Event → `refreshApex()`                                 |
| Full audit log of every LLM call                 | `Case_AI_Analysis__c` records prompt, response, tokens, latency  |

### Customer-Facing (public Experience Cloud portal)

| Feature                                              | Implementation                                      |
| ---------------------------------------------------- | --------------------------------------------------- |
| Anonymous (no-login) case submission                 | Experience Cloud site with guest user profile       |
| Live AI deflection — articles before case            | Same LLM, called as guest via Named Credential      |
| "This solved my issue" deflection path               | Increments `Helpful_Count__c` via `SYSTEM_MODE` DML |
| "Still need help" submission with pre-classification | Case lands in agent queue already categorized       |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                  PUBLIC: Experience Cloud Portal                     │
│  ────────────────────────                                            │
│  customerCaseSubmission LWC  →  CustomerCaseService (Apex)           │
│  (state-machine wizard)         (without sharing; SYSTEM_MODE DML)   │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼  Named Credential
                       ┌──────────────────────────┐
                       │     NVIDIA NIM API        │
                       │  meta/llama-3.3-70b       │
                       └──────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│         SALESFORCE: Async Classification Pipeline                    │
│  ────────────────────────                                            │
│  CaseTrigger ──► CaseTriggerHandler ──► ClassifyCaseQueueable        │
│                                              │                       │
│                                              ▼ (HTTP callout)        │
│                                          NVIDIA NIM                  │
│                                              │                       │
│                                              ▼ DML                   │
│                       Case.AI_*  +  Case_AI_Analysis__c              │
│                                              │                       │
│                                              ▼ EventBus.publish      │
│                                  Case_AI_Classified__e               │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼  lightning/empApi (streaming)
┌─────────────────────────────────────────────────────────────────────┐
│             AGENT: Lightning Service Console                         │
│  ────────────────────────                                            │
│  agentAiInsights LWC (live updates)                                  │
│  kbSuggestions LWC    (RAG-ranked articles)                          │
│  aiClassificationBadge LWC (reusable visual)                         │
│  Lightning Message Service for cross-component reactivity            │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 🛠️ Tech Stack

### Salesforce Platform

- **Apex** (API 66.0) — Triggers, Queueables, Database.AccessLevel.SYSTEM_MODE, Custom Exceptions
- **Lightning Web Components** — `@wire`, `lightning/empApi`, `lightning/messageService`, `NavigationMixin`, `@salesforce/schema/*`
- **Platform Events** — `Case_AI_Classified__e` (HighVolume, PublishImmediately)
- **Lightning Message Service** — `AIInsightsChannel__c` for cross-LWC decoupling
- **External / Named Credentials** — Secure secret storage, runtime merge-field auth injection
- **Custom Metadata** — Permission sets driving guest vs. agent access models
- **Experience Cloud** — LWR-template public site (`AI Help Portal`)

### AI / Integration

- **LLM**: Llama 3.3 70B Instruct via NVIDIA NIM (OpenAI-compatible REST API)
- **Reliability**: provider-level `response_format: json_object` + explicit few-shot schema + defensive markdown-fence stripping (3-layer defense against LLM malformed output)
- **RAG pattern**: pre-fetch top 30 articles → LLM ranks → return top N with relevance scores + reasoning

### DevOps

- **SFDX source format** — Git-managed metadata, single-command deploy to any org
- **Husky pre-commit hooks** — Prettier + ESLint + Jest enforce code quality before commit
- **Jest** — LWC unit tests with `@lwc/jest-preset`

---

## 🧠 Engineering Patterns Demonstrated

This project intentionally exercises every pattern you'd see in a senior-level Salesforce job:

| Pattern                                    | Where in code                                                                                         | Why it matters                                                    |
| ------------------------------------------ | ----------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| **Interface Segregation + Factory**        | `ILLMService` ← `NvidiaLLMService` / `MockLLMService`, `LLMServiceFactory`                            | Open/closed — swap LLM providers without touching callers         |
| **Trigger Handler pattern**                | `CaseTrigger` → `CaseTriggerHandler`                                                                  | Thin trigger, testable handler, `@TestVisible` bypass for tests   |
| **Async with chaining + bulkification**    | `ClassifyCaseQueueable`                                                                               | Set-based, bulkified for Data Loader scenarios                    |
| **Event-driven decoupling**                | Platform Event + `lightning/empApi` + LMS                                                             | Producer and consumer never know about each other                 |
| **Dependency injection for Apex tests**    | `LLMServiceFactory.setMock()` (TestVisible)                                                           | Test async code without real callouts                             |
| **Test Data Builder pattern**              | `NvidiaLLMHttpMock.success()` / `.unauthorized()` / `.malformedContent()`                             | Named factory methods reveal test intent                          |
| **Custom DTOs over `Map<String, Object>`** | `CaseClassificationResult`, `KnowledgeArticleSuggestion`, `PreClassificationResult`                   | Compile-time safety + LWC `@AuraEnabled` consumption              |
| **Defensive LLM output parsing**           | `JsonResponseParser.stripMarkdownFences()` (regex `(?s)^\\s*\`\`\`(?:json)?\\s*(.*?)\\s*\`\`\`\\s*$`) | Real-world LLM output is malformed often                          |
| **Three-layer LLM reliability**            | `response_format` + system-prompt schema + JsonResponseParser                                         | Provider, prompt, code — fail-stop at each layer                  |
| **State-machine UI**                       | `customerCaseSubmission.html` with `lwc:if`/`lwc:elseif`/`lwc:else` over 5 states                     | Declarative, easier to reason about than imperative flag-juggling |
| **Composition over inheritance**           | `aiClassificationBadge` is one LWC, called 3x with different `type` props                             | DRY visual primitives                                             |
| **`@salesforce/schema/*` imports**         | Every LWC field reference                                                                             | Compile-time validation of metadata references                    |
| **Least-privilege security**               | `AI_Public_Portal_Guest` perm set: no Edit on custom objects; `SYSTEM_MODE` for trusted writes        | Production-grade Experience Cloud security model                  |
| **External Credentials (modern auth)**     | `NvidiaNimCredential` + `NVIDIA_NIM` Named Credential with permission set mapping                     | API key never in source; rotatable without deploy                 |

---

## 📊 Metrics

| Metric                        | Value                                                                                              |
| ----------------------------- | -------------------------------------------------------------------------------------------------- |
| Apex test coverage (org-wide) | **96%**                                                                                            |
| Apex tests written            | **44** (all passing)                                                                               |
| Jest unit tests               | **5**                                                                                              |
| LWC bundles                   | 4 (`agentAiInsights`, `aiClassificationBadge`, `kbSuggestions`, `customerCaseSubmission`)          |
| Apex classes                  | 14 (services, DTOs, mocks, tests)                                                                  |
| Custom objects                | 3 (`Case_AI_Analysis__c`, `Knowledge_Article__c`, plus the `Case_AI_Classified__e` platform event) |
| Custom fields on Case         | 8                                                                                                  |
| Avg LLM round-trip latency    | ~2–3 seconds (Llama 3.3 70B, NVIDIA NIM free tier)                                                 |
| LLM cost per case             | ≤ 1 credit on NVIDIA NIM free tier (~1000 free calls/month)                                        |

---

## 🚀 Setup

### Prerequisites

- Salesforce Developer Edition org (Agentforce Dev Edition recommended for full feature parity)
- Salesforce CLI (`sf`) installed
- Node.js 18+ (for LWC tooling)
- An NVIDIA NIM API key (free at https://build.nvidia.com)

### Deploy in 5 minutes

```bash
# 1. Clone
git clone https://github.com/aryansaini1399/ai-case-deflection.git
cd ai-case-deflection

# 2. Authenticate to your org
sf org login web --alias myDev --set-default

# 3. Install dependencies
npm install

# 4. Deploy everything
sf project deploy start --source-dir force-app --target-org myDev

# 5. Assign yourself the Admin permission set
sf org assign permset --name AI_Case_Deflection_Admin --target-org myDev

# 6. Seed knowledge articles
sf apex run --file scripts/apex/seed-knowledge-articles.apex --target-org myDev
```

### Final manual configuration (one-time, ~5 min in Setup UI)

1. **Setup → External Credentials → "NVIDIA NIM Credential"**: Add your NVIDIA API key as the `ApiKey` parameter on the `NvidiaNimPrincipal`.
2. **Setup → Lightning App Builder**: Add the `AI Insights` and `Knowledge Suggestions` LWCs to the Case record page.
3. **(Optional)** Set up Experience Cloud for the public portal (see [PHASE6.md](docs/PHASE6.md) — guest profile, perm set assignment, publish).

---

## 📂 Project Structure

```
force-app/main/default/
├── classes/                          # Apex
│   ├── CaseTriggerHandler.cls        # Trigger pattern
│   ├── ClassifyCaseQueueable.cls     # Async LLM pipeline
│   ├── NvidiaLLMService.cls          # LLM impl
│   ├── KnowledgeArticleService.cls   # RAG ranking
│   ├── CustomerCaseService.cls       # Guest-callable portal API
│   ├── JsonResponseParser.cls        # Markdown-fence stripper
│   ├── LLMServiceFactory.cls         # DI + factory
│   ├── PreClassificationResult.cls   # DTO
│   ├── *Test.cls                     # 44 tests, 96% coverage
│   └── *HttpMock.cls                 # Test Data Builders
├── lwc/
│   ├── agentAiInsights/              # Live agent panel
│   ├── kbSuggestions/                # RAG article cards
│   ├── customerCaseSubmission/       # Public wizard
│   └── aiClassificationBadge/        # Reusable visual
├── objects/
│   ├── Case/fields/                  # 8 AI custom fields
│   ├── Case_AI_Analysis__c/          # LLM audit log
│   ├── Case_AI_Classified__e/        # Platform Event
│   └── Knowledge_Article__c/         # KB store
├── triggers/CaseTrigger.trigger
├── permissionsets/
│   ├── AI_Case_Deflection_User       # Read-only agents
│   ├── AI_Case_Deflection_Admin      # Full + EC access
│   └── AI_Public_Portal_Guest        # Experience Cloud guests
├── externalCredentials/NvidiaNimCredential
├── namedCredentials/NVIDIA_NIM
├── messageChannels/AIInsightsChannel
└── tabs/, listViews/, ...

scripts/apex/                         # Anonymous-Apex utilities
├── test-nvidia-callout.apex          # Auth smoke test
├── test-classify-real.apex           # End-to-end live LLM test
└── seed-knowledge-articles.apex      # 10 sample articles
```

---

## 🎓 Real-World Lessons Learned

Honest gotchas hit during build — the kind you only learn by shipping:

1. **LWC → Apex deserialization is strict for typed DTOs**. A single bad field (e.g., a string in an `Id`-typed slot) silently nulls the whole DTO. Fix: accept `Map<String, Object>` for any LWC-supplied object and cast field-by-field.
2. **Trailhead Playground vs Developer Edition matter more than expected**. Playground orgs strip Service Cloud features (Email Composer, Knowledge, Experience Cloud activation). Migrated to Agentforce Dev Edition mid-project — SFDX source format made it a 15-minute redeploy.
3. **Guest User License does NOT honor permission-set FLS on inserts**. Field permissions can be granted but silently get stripped. Fix: `Database.insert(record, AccessLevel.SYSTEM_MODE)` for server-trusted writes.
4. **Apex resolving `{!$Credential.X.Y}` for guest users needs Read on `UserExternalCredential`**. Poorly documented, but real. Added to the guest permission set.
5. **Permission Set XSD ordering is unforgiving**. `fieldPermissions` and `objectPermissions` must each be in contiguous, alphabetically-sorted blocks.
6. **Master-Detail child object permissions require parent Read**. Salesforce enforces this even when you only intend to grant child access.
7. **LLM JSON output is unreliable**. Models wrap responses in markdown code fences, occasionally produce unquoted string values, and ignore "no markdown" instructions. Defense-in-depth (`response_format`, prompt schema with example, defensive parser) eliminated this in practice.
8. **Experience Cloud sites are authenticated by default**. "Public site" ≠ "public access" — these are separate settings. Took 10 minutes to find the toggle.
9. **Salesforce Trailhead Playground network latency to NVIDIA was ~30s; Dev Edition was sometimes slower**. Bumped Apex callout timeout from 30s to 90s; production should externalize this via Custom Metadata.
10. **Async Queueable on Experience Cloud guest user**: case ownership reassigns to the Default Case Owner (not the guest), so the guest-context Queueable cannot SOQL-read the case it just enqueued. Fixed by setting `AI_Classification_Status__c = 'Completed'` in `submitCase` so the trigger short-circuits the async path entirely.

---

## 🔮 Future Improvements

If this were a long-term initiative, the next iteration would add:

- **Embedding-based KB search** — replace per-query LLM ranking with vector embeddings (Salesforce Data Cloud or Pinecone). Cuts cost ~10x for high-volume sites.
- **Multi-LLM A/B routing** — Custom Metadata driving which LLM Provider serves which traffic, allowing controlled prompt iteration.
- **Streaming responses** — instead of waiting 2–3s for a full reply, stream tokens to the LWC for sub-second perceived latency.
- **PII scrubbing in audit logs** — strip emails, phone numbers, IDs from `Raw_Request__c` / `Raw_Response__c` before persisting.
- **Cost/budget guardrails** — token limits per user/per day, alert at 80% of budget.
- **Custom Metadata–driven timeouts and limits** — instead of hardcoded constants in Apex.
- **CI/CD pipeline** — GitHub Actions running Apex + Jest tests on every PR, auto-deploying main → staging org.

---

## 📄 License

This is a portfolio project. Use freely for learning and inspiration; no warranty.

---

## 🙋‍♂️ Author

**Aryan Saini** — Salesforce developer building toward SDE2 roles.

- GitHub: [@aryansaini1399](https://github.com/aryansaini1399)

Built with mentor-style pair programming over ~3 weeks. Every commit message tells the story of one engineering decision.
