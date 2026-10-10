# WanderRoster — AI-Powered Travel and Expense Intelligence Platform

> **Tagline:** *Every Trip Has a Purpose. Every Rupee Has a Reason.*

---

## 🌟 Executive Overview

**WanderRoster** is an enterprise-grade corporate travel spend control and financial intelligence platform built natively on Salesforce Lightning Experience. Rather than functioning simply as a passive post-trip expense recordkeeping ledger, WanderRoster delivers **proactive decision intelligence** across the entire corporate travel lifecycle:

```
[Employee Travel Request] ──► [Policy & Budget Validation] ──► [AI Spend Intelligence]
          │
          ▼
[Manager Approval Queue] ──► [Consent-Based Trip Tracking] ──► [Receipt Verification]
          │
          ▼
[Finance Audit & Anomaly Detection] ──► [Reimbursement] ──► [Outcome ROI Analysis]
```

### Key Differentiators
1. **Predictive Spend vs. Passive Audit:** Travel costs are evaluated and optimized *before* budget commitment occurs, not weeks after money has already been spent.
2. **Algorithmic AI Spend Intelligence:** Evaluates advance booking windows, rail alternatives, dynamic per diem allowances, and multi-employee trip coordination to unlock measurable **Potential Savings**.
3. **Rigorous Financial Integrity:** Uncompromising separation of **Potential Savings** (pre-trip optimization opportunities) and **Realized Savings** (audited, approved discounts verified by Finance).
4. **Anti-Double-Counting Budget Accounting:** Pending commitments, approved commitments, and recorded actual expenses are tracked independently with strict state-transition synchronization to preserve forecast variance accuracy.
5. **Receipt Fraud & Anomaly Shield:** Line-level receipt verification computing a composite **0–100% Anomaly Risk Score**, detecting cross-record duplicate receipts, claimed vs. receipt amount discrepancies, and strict 24-hour compliance deadlines.
6. **Privacy-Preserving Employee Experience:** Consent-based trip check-ins restricted to authorized travel windows—zero silent tracking.
7. **Spend-to-Outcome ROI Modeling:** Links every rupee spent to tangible commercial outcomes (deals closed, enterprise contracts secured, client kickoff milestones achieved).

---

## 🏗️ Architecture & Data Model

WanderRoster uses a 100% native Salesforce architecture without external database dependencies.

### Custom Objects Schema

| Object API Name | Label | Description & Key Fields |
| :--- | :--- | :--- |
| `Travel_Budget__c` | Travel Budget | Departmental budget pools (`Allocated_Budget__c`, `Approved_Commitments__c`, `Pending_Commitments__c`, `Recorded_Expenses__c`, `Forecast_Spending__c`, `Forecast_Variance__c`, `Budget_Health_Status__c`). |
| `Travel_Request__c` | Travel Request | Core pre-trip authorization record (`Origin__c`, `Destination__c`, departure/return dates, estimated spend breakdowns, `Policy_Validation_Status__c`, `AI_Recommendation__c`, `Potential_Savings__c`, `Approval_Status__c`, `Trip_Status__c`, `Actual_Cost__c`). |
| `Expense_Report__c` | Expense Report | Post-trip expense submission envelope (`Total_Claimed_Amount__c`, `Total_Approved_Amount__c`, `Total_Rejected_Amount__c`, `Finance_Review_Status__c`, `Reimbursement_Status__c`, `Reimbursement_Date__c`). |
| `Expense_Item__c` | Expense Item | Granular expense line item with receipt attachment (`Expense_Category__c`, `Claimed_Amount__c`, `Receipt_Amount__c`, `Receipt_Number__c`, `Receipt_Deadline__c`, `Receipt_Compliance_Status__c`, `Receipt_Verification_Status__c`, `Anomaly_Risk_Score__c`, `Duplicate_Suspected__c`, `AI_Explanation__c`). |
| `Travel_Location_Update__c` | Travel Location Update | Consent-driven progress update (`Latitude__c`, `Longitude__c`, `Location_City__c`, `Location_Timestamp__c`, `Location_Sharing_Consent__c`, `Trip_Progress_Status__c`, `Update_Source__c`). |
| `Travel_Outcome__c` | Travel Outcome | Post-trip business impact record (`Business_Objective__c`, `Outcome_Description__c`, `Outcome_Status__c`, `Business_Value_Estimate__c`, `Follow_up_Required__c`, `Manager_Feedback__c`). |

### Custom Metadata Type: `Expense_Policy__mdt`

Centralized, declarative business policy engine decoupled from code:
- `Expense_Category__c` (Picklist: Flights, Hotel, Food, Local Transport)
- `Max_Allowed_Amount__c` (Currency ₹)
- `Approval_Threshold__c` (Currency ₹ triggering executive escalation)
- `Receipt_Deadline_Hours__c` (Number: hours post-expense to submit proof)
- `Travel_Class_Restriction__c` (Text: Economy, Standard, etc.)
- `Requires_Receipt__c` (Checkbox)

*Sample Policy Records:*
1. **Flight Domestic:** Max ₹18,000, Approval Threshold ₹20,000, 24h deadline, Economy Class.
2. **Hotel Accommodation:** Max ₹6,000/night, Approval Threshold ₹8,000, 24h deadline.
3. **Food and Meals:** Max ₹1,800/day, Approval Threshold ₹2,500, 24h deadline.
4. **Local Transport:** Max ₹1,500/day, Approval Threshold ₹2,000, 24h deadline.

---

## ⚡ Apex Intelligence Services & Triggers

All services are designed to be bulk-safe, strictly enforcing CRUD/FLS, and structured using clean separation of concerns:

- **`TravelPolicyService.cls`**: Evaluates travel requests against `Expense_Policy__mdt`. Computes total trip estimates, checks per-category maximums and approval thresholds, and populates clear policy violation summaries.
- **`TravelBudgetForecastService.cls`**: Real-time departmental budget recalculation. Enforces anti-double-counting logic: transitions funds cleanly from `Pending_Commitments__c` to `Approved_Commitments__c`, and clears commitments upon recording approved expenses. Automatically marks budget status as `Healthy`, `Warning`, or `Overrun`.
- **`TravelRecommendationService.cls`**: Proactive AI spend optimizer. Recommends high-speed rail for routes under 400 km, flags short booking windows (<7 days), suggests booking partner hotels, and calculates verifiable **Potential Savings**.
- **`ReceiptComplianceService.cls`**: Automatically computes `Receipt_Deadline__c` based on policy metadata (e.g. 24 hours post-expense) and flags line items as `On-Time` or `Overdue`.
- **`ReceiptVerificationService.cls`**: Algorithmic receipt auditor. Detects claimed vs receipt amount discrepancies, identifies cross-record and in-batch duplicate receipt numbers, and scores anomaly risk from 0% to 100%.
- **`TravelRequestTrigger.trigger`** & **`ExpenseItemTrigger.trigger`**: Bulk-safe triggers orchestrating automated policy checks, anomaly audits, and budget synchronizations.

---

## 💻 Lightning Web Components Suite

WanderRoster provides 8 dedicated, responsive Lightning Web Components matching each enterprise persona:

| Component Name | Persona | Key Features |
| :--- | :--- | :--- |
| `travelRequestPortal` | Employee | Intuitive travel request creation, dynamic budget availability lookup, live policy compliance preview, and AI recommendations. |
| `travelRecommendationPanel` | Employee / Mgr | Interactive card displaying AI cost-saving opportunities, advance booking warnings, and transport mode alternatives. |
| `managerApprovalWorkspace` | Manager | Executive queue for reviewing pending requests, budget health impact, policy exception indicators, and one-click approvals. Blocks self-approval. |
| `receiptVerificationPanel` | Employee / Auditor | Document upload panel via Salesforce Files (`ContentDocumentLink`), automated receipt amount verification, and discrepancy alerts. |
| `financeReviewWorkspace` | Finance Team | Line-item auditing workspace, partial/full approvals, rejection reason capture, and automated reimbursement lifecycle management (`Draft` → `Ready for Payment` → `Paid`). |
| `financialIntelligenceDashboard` | CFO / Leadership | High-level executive dashboard showing total allocated budgets, approved commitments, recorded expenses, potential vs realized savings, and budget health alerts. |
| `travelOutcomeTracker` | Leadership / PM | Post-trip business value logger calculating net ROI (`Business_Value_Estimate__c - Actual_Cost__c`) and ROI multiplier. |
| `tripLocationTracker` | Traveler / Admin | Consent-driven, privacy-first trip check-in component recording progress updates during active trips. |

---

## 🧪 Demonstration Scenarios (Scenarios A through G)

The platform includes a dedicated, repeatable seed script located at [`scripts/apex/seed_demo_data.apex`](file:///d:/Salesforce/WanderRoster/scripts/apex/seed_demo_data.apex):

```bash
sf apex run --file scripts/apex/seed_demo_data.apex --target-org WanderRosterOrg
```

### Validated Scenarios Summary

- **Scenario A — Compliant Travel Request (`TR-0000`):**
  - Origin: Hyderabad, Destination: Bengaluru, Total Spend: ₹30,000.
  - Policy Status: **Compliant**. Budget: ₹2,50,000 Allocated, ₹30,000 Approved. Status: **Approved / Scheduled**.
- **Scenario B — Budget Overrun & Policy Violation (`TR-0001`):**
  - Origin: Mumbai, Destination: Delhi, Total Spend: ₹50,000 against ₹40,000 Sales Budget.
  - Policy Status: **Policy Violation** (Transport estimate ₹25,000 exceeds threshold).
  - Budget Status: **Overrun** (Pending commitments ₹50,000 exceed allocated ₹40,000). Status: **Pending Approval**.
- **Scenario C — Claimed vs. Receipt Amount Discrepancy (`EXP-0000`):**
  - Claimed: ₹8,000, Receipt Amount: ₹8,800 at The Chancery Pavilion.
  - Anomaly Score: **60%**, Verification Status: **Discrepancy Flagged**.
  - Policy Exception: Claimed ₹8,000 exceeds ₹6,000 hotel policy limit.
- **Scenario D — Missing / Overdue Receipt (`EXP-0001`):**
  - Food expense ₹1,500 incurred 4 days ago with no receipt attached.
  - Compliance Status: **Overdue** (exceeded 24h window), Anomaly Score: **25%**, Status: Missing Receipt.
- **Scenario E — Cross-Record Duplicate Receipt Detection (`EXP-0002` & `EXP-0003`):**
  - First flight invoice `DUP-AIR-7788` submitted under `EXP-0002` (Verified).
  - Second flight invoice `DUP-AIR-7788` submitted under `EXP-0003`.
  - Duplicate Status: **Duplicate Suspected = true**, Anomaly Score: **50%**, AI Alert: `Duplicate Suspected: Receipt #DUP-AIR-7788 was previously submitted under EXP-0002`.
- **Scenario F — Reimbursement Lifecycle Transition:**
  - Expense items audited by Finance, parent report totals calculated dynamically (`Total_Approved_Amount__c`), status advanced to `Ready for Payment` → `Paid`, updating `Travel_Request__c.Actual_Cost__c` and synchronizing budget recorded expenses.
- **Scenario G — Business Value & ROI Tracking (`TR-0002` & `OUT-0000`):**
  - Enterprise Pilot Sign-Off trip to Chennai: Actual Spend: ₹29,500.
  - Documented Business Value: ₹25,00,000 ARR contract secured.
  - Net ROI: ₹24,70,500 (**84.7x Value Multiplier**).

---

## 🔒 Security & Quality Controls

- **Field-Level Security & CRUD Enforcement:** Complete permissions assigned via `WanderRoster_Admin` permission set across 6 custom objects, 72 custom fields, 10 Apex classes, and 10 custom tabs.
- **Apex Code Coverage:** **86% Org-Wide Coverage** across all classes (minimum threshold: 75%).
- **Pass Rate:** **100% Pass Rate** (14/14 unit tests passed).
- **Self-Approval Guardrails:** Built-in checks prevent users from approving their own travel requests.
- **Employee Privacy Protection:** Location check-ins require explicit, boolean consent (`Location_Sharing_Consent__c == true`) and are valid only during active trip schedules.