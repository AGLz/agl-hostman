# Portfolio Restructuring Implementation Guide
## Actionable Checklists & Visual Tools

**Companion to:** Portfolio Restructuring Strategy for CMN 5.272 Compliance
**Task ID:** fe3bc28b-9ba0-4f65-b1f9-a5c9e1e8e41a
**Last Updated:** February 6, 2026

---

## Quick Reference Charts

### 1. Investment Limits Matrix (Visual Quick Reference)

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                    CMN 5.272 INVESTMENT LIMITS BY GOVERNANCE LEVEL            ║
╚══════════════════════════════════════════════════════════════════════════════╝

┌─────────────────────────────────────────────────────────────────────────────┐
│ RENDA FIXA (Fixed Income)                                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│ Asset                           │ Limit │ Nível │ Article   │ Priority      │
├─────────────────────────────────┼───────┼───────┼──────────┼───────────────┤
│ Tesouro Direto/ETFs             │ 100%  │ All   │ Art. 7,I  │ Core          │
│ Títulos Tesouro (secundário)    │ 100%  │ I+    │ Art. 7,III│ High          │
│ Ativos Financeiros IF           │ 20%   │ II+   │ Art. 7,VI │ Medium        │
│ Fundos ETF RF (sem crédito priv)│ 80%   │ II+   │ Art. 7,V  │ Medium        │
│ Fundos Crédito Privado          │ 20%   │ III+  │ Art. 7,VII│ Medium-High   │
│ Fundos Debêntures Incentivadas  │ 20%   │ III+  │ Art. 7,VIII│ Medium      │
│ FIDC Senior                     │ 20%   │ IV    │ Art. 7,IX │ High          │
│ Operações Compromissadas TPF    │ 5%    │ I+    │ Art. 7,IV │ Low-Medium    │
├─────────────────────────────────┴───────┴───────┴──────────┴───────────────┤
│ GLOBAL LIMITE CRÉDITO PRIVADO: 35% of portfolio                            │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ RENDA VARIÁVEL (Variable Income)                                           │
├─────────────────────────────────────────────────────────────────────────────┤
│ Asset                           │ Limit │ Nível │ Article   │ Priority      │
├─────────────────────────────────┼───────┼───────┼──────────┼───────────────┤
│ Fundos de Ações                 │ 40%   │ II+   │ Art. 8,I  │ Core (Nível II+)│
│ ETFs Ações                      │ 40%   │ II+   │ Art. 8,II │ Core (Nível II+)│
│ Fundos BDR/Ações/BDR/ETF        │ 10%   │ III+  │ Art. 8,III│ Medium        │
│ ETF Internacional               │ 10%   │ III+  │ Art. 8,IV │ High          │
├─────────────────────────────────┴───────┴───────┴──────────┴───────────────┤
│ GLOBAL LIMITS:                                                              │
│ • Nível II: 40% of portfolio in (Variable + Structured + Real Estate)      │
│ • Nível III: 50% of portfolio in (Variable + Structured + Real Estate)     │
│ • Nível IV: 60% of portfolio in (Variable + Structured + Real Estate)     │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ INVESTIMENTOS ESTRUTURADOS (Structured Investments)                         │
├─────────────────────────────────────────────────────────────────────────────┤
│ Asset                           │ Limit │ Nível │ Article   │ Priority      │
├─────────────────────────────────┼───────┼───────┼──────────┼───────────────┤
│ Fundos Multimercado             │ 15%   │ II+   │ Art. 10,I │ High          │
│ FIAGRO                          │ 5%    │ III+  │ Art. 10,II│ Medium        │
│ FIP                             │ 10%   │ IV    │ Art. 10,III│ High (Nível IV)│
│ Ações Mercado Acesso            │ 10%   │ IV    │ Art. 10,IV│ Medium        │
├─────────────────────────────────┴───────┴───────┴──────────┴───────────────┤
│ GLOBAL LIMITE ESTRUTURADOS: 20% of portfolio                               │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ FUNDOS IMOBILIÁRIOS (Real Estate Funds)                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│ Asset                           │ Limit │ Nível │ Article   │ Priority      │
├─────────────────────────────────┼───────┼───────┼──────────┼───────────────┤
│ FIIs (negociados em bolsa)      │ 20%   │ III+  │ Art. 11   │ High (Nível III+)│
├─────────────────────────────────┴───────┴───────┴──────────┴───────────────┤
│ GLOBAL LIMITE FUNDOS IMOBILIÁRIOS: 20% of portfolio                         │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ INVESTIMENTOS NO EXTERIOR (Foreign Investments)                             │
├─────────────────────────────────────────────────────────────────────────────┤
│ Asset                           │ Limit │ Nível │ Article   │ Priority      │
├─────────────────────────────────┼───────┼───────┼──────────┼───────────────┤
│ FIC Aberto (40% PL)             │ 40%   │ II    │ Art. 9    │ Low           │
│ FIC Aberto (20% PL)             │ 20%   │ III   │ Art. 9    │ Medium        │
│ Renda Fixa Dívida Externa       │ 100%  │ I     │ Art. 9    │ Medium        │
├─────────────────────────────────┴───────┴───────┴──────────┴───────────────┤
│ GLOBAL LIMITE INVESTIMENTOS EXTERIOR: 10% of portfolio (Nível III+)        │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ EMPRÉSTIMOS CONSIGNADOS (Payroll Loans)                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│ Asset                           │ Limit │ Nível │ Article   │ Priority      │
├─────────────────────────────────┼───────┼───────┼──────────┼───────────────┤
│ Empréstimos Consignados         │ 5%    │ IV    │ Art. 12   │ Nível IV only │
├─────────────────────────────────┴───────┴───────┴──────────┴───────────────┤
│ REQUIREMENTS: Sem adência 5%; Nível I+ máximo 10%; Suspensão automática     │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2. Concentration Limits Reference

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                         CONCENTRATION LIMITS                                 ║
╚══════════════════════════════════════════════════════════════════════════════╝

┌─────────────────────────────────────────────────────────────────────────────┐
│ PER-EMISSOR CONCENTRATION                                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│ Issuer Type                    │ Limit  │ Notes                              │
├────────────────────────────────┼────────┼─────────────────────────────────────┤
│ Tesouro Nacional               │ 100%   │ No limit (sovereign)                │
│ Instituições Financeiras S1/S2 │ 5%     │ Major banks                         │
│ Demais emissores               │ 5%     │ Corporate issuers                   │
│ Demais segmentos               │ 2.5%   │ Other segments                     │
│ Fundos/ETF mesma classe        │ 20%    │ Same asset class funds             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ PER-FUND CONCENTRATION                                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│ Fund Type                      │ Limit  │ Notes                              │
├────────────────────────────────┼────────┼─────────────────────────────────────┤
│ IF S1/S2                       │ 10% PL │ Single major bank fund              │
│ Demais fundos                  │ 15% PL │ Other funds                         │
│ Fundos crédito privado         │ 5% PL  │ Private credit funds                │
│ Limite agregado RPPS           │ 50% PL │ Total across all funds              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3. Governance Level Requirements Checklist

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                   GOVERNANCE LEVEL REQUIREMENTS CHECKLIST                    ║
╚══════════════════════════════════════════════════════════════════════════════╝

┌─────────────────────────────────────────────────────────────────────────────┐
│ NÍVEL I (Entry Level)                                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│ Requirement                     │ Status │ Due Date    │ Notes              │
├─────────────────────────────────┼────────┼─────────────┼─────────────────────┤
│ Board-approved Investment Policy│ ☐      │ Feb 28, 2026│ Basic policy       │
│ Basic Risk Management Framework │ ☐      │ Feb 28, 2026│ Fundamental risks  │
│ Portfolio Monitoring System     │ ☐      │ Mar 31, 2026│ Basic tracking     │
│ Compliance Procedures          │ ☐      │ Mar 31, 2026│ Core controls      │
│ Annual Reporting               │ ☐      │ Apr 30, 2026│ Stakeholder comms  │
│ Self-Certification             │ ☐      │ Jul 31, 2026│ Submit to BCB      │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ NÍVEL II (Intermediate)                                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│ Requirement                     │ Status │ Due Date    │ Notes              │
├─────────────────────────────────┼────────┼─────────────┼─────────────────────┤
│ Investment Committee            │ ☐      │ Aug 31, 2026│ Formal structure   │
│ Enhanced Risk Management        │ ☐      │ Aug 31, 2026│ VaR, stress tests  │
│ Equity Investment Capability    │ ☐      │ Sep 30, 2026│ 40% limit          │
│ Semi-Annual Reporting          │ ☐      │ Oct 31, 2026│ Enhanced frequency  │
│ Performance Attribution         │ ☐      │ Nov 30, 2026│ Basic analysis     │
│ BCB Validation                 │ ☐      │ Dec 31, 2026│ Submit for approval │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ NÍVEL III (Advanced)                                                         │
├─────────────────────────────────────────────────────────────────────────────┤
│ Requirement                     │ Status │ Due Date    │ Notes              │
├─────────────────────────────────┼────────┼─────────────┼─────────────────────┤
│ Independent Board Members       │ ☐      │ Jan 31, 2027│ Minimum 2          │
│ Advanced Risk Analytics        │ ☐      │ Feb 28, 2027│ Multi-factor models │
│ Alternative Investment Capab.   │ ☐      │ Mar 31, 2027│ RE, Structured     │
│ Quarterly Reporting            │ ☐      │ Apr 30, 2027│ Enhanced detail     │
│ Multi-Factor Attribution       │ ☐      │ May 31, 2027│ Detailed analysis  │
│ External Audit Coordination    │ ☐      │ Jun 15, 2027│ Preparation         │
│ BCB Validation                 │ ☐      │ Jun 30, 2027│ Submit for approval │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ NÍVEL IV (Sophisticated)                                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│ Requirement                     │ Status │ Due Date    │ Notes              │
├─────────────────────────────────┼────────┼─────────────┼─────────────────────┤
│ Sophisticated Governance       │ ☐      │ Jul 31, 2027│ Full framework     │
│ External Audit Relationship     │ ☐      │ Aug 31, 2027│ Ongoing engagement  │
│ Private Equity Capability      │ ☐      │ Sep 30, 2027│ FIP allocation      │
│ International Investment       │ ☐      │ Oct 31, 2027│ Global exposure     │
│ Payroll Loan Operations        │ ☐      │ Nov 30, 2027│ New asset class     │
│ Monthly Reporting              │ ☐      │ Dec 31, 2027│ High frequency      │
│ Advanced Stress Testing        │ ☐      │ Jan 15, 2028│ Scenario analysis   │
│ Comprehensive Documentation    │ ☐      │ Jan 31, 2028│ Audit-ready         │
│ BCB Validation                 │ ☐      │ Feb 28, 2028│ Final certification  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 4. 24-Week Sprint Plan (First 6 Months - Nível I Implementation)

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                      NÍVEL I IMPLEMENTATION SPRINTS                          ║
╚══════════════════════════════════════════════════════════════════════════════╝

SPRINT 1: Foundation (Weeks 1-4 | Feb 1-28, 2026)
┌─────────────────────────────────────────────────────────────────────────────┐
│ Week 1: Board Approval & Kickoff                                            │
│ ├─ Monday: Board meeting - Approve strategy & budget                        │
│ ├─ Tuesday: Form Transition Task Force                                      │
│ ├─ Wednesday: Engage external consultants                                   │
│ ├─ Thursday: Issue technology RFP                                          │
│ └─ Friday: Kickoff meeting - All stakeholders                               │
│                                                                              │
│ Week 2: Governance Assessment                                               │
│ ├─ Conduct current state analysis                                           │
│ ├─ Map existing policies to new requirements                                │
│ ├─ Identify governance gaps                                                 │
│ └─ Preliminary resource requirements                                       │
│                                                                              │
│ Week 3: System Planning                                                      │
│ ├─ Vendor selection committee formed                                        │
│ ├─ Technology architecture designed                                         │
│ ├─ Data requirements defined                                                │
│ └─ Integration planning with custodian                                      │
│                                                                              │
│ Week 4: Resource Planning                                                    │
│ ├─ Staff training curriculum designed                                       │
│ ├─ Hiring plan for additional FTEs                                          │
│ ├─ Consultant contracts negotiated                                          │
│ └─ Detailed project plan finalized                                          │
└─────────────────────────────────────────────────────────────────────────────┘

SPRINT 2: System Implementation (Weeks 5-8 | Mar 1-31, 2026)
┌─────────────────────────────────────────────────────────────────────────────┐
│ Week 5: Vendor Selection                                                     │
│ ├─ Complete vendor evaluations                                              │
│ ├─ Final technology selections                                              │
│ ├─ Contract negotiations                                                    │
│ └─ Board approval of vendors                                                │
│                                                                              │
│ Week 6: System Setup                                                         │
│ ├─ Portfolio management system configuration                                 │
│ ├─ Risk module setup                                                        │
│ ├─ Compliance monitoring configuration                                      │
│ └─ User access provisioning                                                 │
│                                                                              │
│ Week 7: Integration                                                          │
│ ├─ Custodian system connections                                             │
│ ├─ Data feed testing                                                        │
│ ├─ Report template setup                                                    │
│ └─ Initial data migration                                                   │
│                                                                              │
│ Week 8: Testing                                                              │
│ ├─ User acceptance testing                                                  │
│ ├─ Integration testing                                                      │
│ ├─ Security validation                                                      │
│ └─ Performance testing                                                      │
└─────────────────────────────────────────────────────────────────────────────┘

SPRINT 3: Portfolio Analysis (Weeks 9-12 | Apr 1-30, 2026)
┌─────────────────────────────────────────────────────────────────────────────┐
│ Week 9: Current Portfolio Mapping                                            │
│ ├─ Classify all positions by CMN 5.272 categories                           │
│ ├─ Identify non-compliant holdings                                          │
│ ├─ Calculate transition costs                                               │
│ └─ Tax impact analysis                                                      │
│                                                                              │
│ Week 10: Liquidity Analysis                                                  │
│ ├─ Assess liquidity of all positions                                        │
│ ├─ Market impact simulation                                                 │
│ ├─ Phased exit strategy design                                              │
│ └─ Contingency funding sources                                              │
│                                                                              │
│ Week 11: Gap Analysis                                                        │
│ ├─ Compare current allocation to Nível I targets                            │
│ ├─ Identify required purchases                                              │
│ ├─ Optimize execution strategy                                              │
│ └─ Rebalancing timeline finalization                                        │
│                                                                              │
│ Week 12: Documentation                                                       │
│ ├─ Update Investment Policy                                                 │
│ ├─ Create Risk Management Manual                                            │
│ ├─ Document compliance procedures                                           │
│ └─ Board review session                                                     │
└─────────────────────────────────────────────────────────────────────────────┘

SPRINT 4: Initial Restructuring (Weeks 13-16 | May 1-31, 2026)
┌─────────────────────────────────────────────────────────────────────────────┐
│ Week 13: Non-Compliant Liquidation - Phase 1 (25%)                           │
│ ├─ Execute planned sales (25% of non-compliant)                              │
│ ├─ Monitor market impact                                                    │
│ ├─ Adjust strategy if needed                                                │
│ └─ Document lessons learned                                                 │
│                                                                              │
│ Week 14: Non-Compliant Liquidation - Phase 2 (50%)                           │
│ ├─ Execute planned sales (additional 25%)                                    │
│ ├─ Continue monitoring                                                      │
│ ├─ Rebalance remaining positions                                            │
│ └─ Compliance checks                                                        │
│                                                                              │
│ Week 15: Non-Compliant Liquidation - Phase 3 (100%)                          │
│ ├─ Complete liquidation of remaining non-compliant                          │
│ ├─ Final compliance validation                                              │
│ ├─ Transition to permitted investments                                       │
│ └─ Operational adjustments                                                  │
│                                                                              │
│ Week 16: Permitted Investment Onboarding                                     │
│ ├─ Begin allocation to Tesouro Direto/ETFs                                  │
│ ├─ Establish laddered maturity strategy                                     │
│ ├─ Set up liquidity buffer (10%)                                             │
│ └─ Initial portfolio rebalancing                                            │
└─────────────────────────────────────────────────────────────────────────────┘

SPRINT 5: Nível I Optimization (Weeks 17-20 | Jun 1-30, 2026)
┌─────────────────────────────────────────────────────────────────────────────┐
│ Week 17: Portfolio Optimization                                              │
│ ├─ Fine-tune asset allocation                                               │
│ ├─ Duration management                                                       │
│ ├─ Yield curve positioning                                                  │
│ └─ Liquidity management                                                     │
│                                                                              │
│ Week 18: Risk Management                                                     │
│ ├─ VaR model validation                                                     │
│ ├─ Stress testing scenarios                                                 │
│ ├─ Concentration limit monitoring                                           │
│ └─ Daily compliance checks                                                  │
│                                                                              │
│ Week 19: Documentation Finalization                                          │
│ ├─ Complete Investment Policy updates                                       │
│ ├─ Finalize Risk Manual                                                     │
│ ├─ Board information package                                                │
│ └─ Certification preparation                                                 │
│                                                                              │
│ Week 20: Internal Audit                                                      │
│ ├─ Mock regulatory examination                                              │
│ ├─ Gap identification                                                       │
│ ├─ Remediation of any issues                                                │
│ └─ Readiness assessment                                                     │
└─────────────────────────────────────────────────────────────────────────────┘

SPRINT 6: Certification (Weeks 21-24 | Jul 1-31, 2026)
┌─────────────────────────────────────────────────────────────────────────────┐
│ Week 21: Pre-Certification                                                   │
│ ├─ Final compliance validation                                              │
│ ├─ Documentation package assembly                                           │
│ ├─ Legal review of submission                                               │
│ └─ Board final approval                                                     │
│                                                                              │
│ Week 22: BCB Submission                                                      │
│ ├─ Submit Nível I certification application                                  │
│ ├─ Support documentation uploaded                                           │
│ ├─ Confirmation received                                                   │
│ └─ Review period initiated (30-60 days)                                     │
│                                                                              │
│ Week 23: Response Management                                                 │
│ ├─ Monitor for BCB information requests                                      │
│ ├─ Prepare response materials                                               │
│ ├─ Clarification documentation                                               │
│ └─ On-site exam preparation (if required)                                   │
│                                                                              │
│ Week 24: Nível I Achievement                                                 │
│ ├─ BCB certification received                                               │
│ ├─ Communication to stakeholders                                            │
│ ├─ Lessons learned documentation                                            │
│ └─ Begin Nível II preparation                                                │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5. Daily Compliance Checklist (For Operations Team)

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                    DAILY COMPLIANCE OPERATIONS CHECKLIST                     ║
╚══════════════════════════════════════════════════════════════════════════════╝

Date: _______________  Reviewed By: _______________  Shift: _______________

┌─────────────────────────────────────────────────────────────────────────────┐
│ PRE-TRADE COMPLIANCE (Before markets open)                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│ ☐ Check overnight market movements                                          │
│ ☐ Review limit utilization (all segments)                                   │
│ ☐ Verify concentration limits (emitters, funds)                             │
│ ☐ Check for any regulatory updates                                          │
│ ☐ Review redemption notices from funds                                      │
│ ☐ Validate cash position vs. obligations                                    │
│ ☐ Confirm system availability                                               │
│ ☐ Check for any limit breach alerts                                         │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ TRADE COMPLIANCE (During trading day)                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│ ☐ Pre-trade clearance for all orders                                        │
│ ☐ Real-time limit monitoring                                                │
│ ☐ Concentration limit checks before execution                               │
│ ☐ Issuer limit validation                                                   │
│ ☐ Fund limit validation                                                     │
│ ☐ Segment limit validation                                                  │
│ ☐ Global limit validation                                                   │
│ ☐ Document any exceptions with resolution path                              │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ POST-TRADE COMPLIANCE (After markets close)                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│ ☐ Reconcile all trades with custodian                                       │
│ ☐ Verify settlement instructions                                           │
│ ☐ Update portfolio positions                                                │
│ ☐ Calculate end-of-day limits                                               │
│ ☐ Generate compliance reports                                               │
│ ☐ Review any exceptions or breaches                                         │
│ ☐ Document breach resolution (if applicable)                                │
│ ☐ Prepare daily dashboard for management                                    │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ END-OF-DAY VALIDATION                                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│ ☐ All segment limits within thresholds                                      │
│ ☐ All concentration limits compliant                                        │
│ ☐ No unauthorized investments                                              │
│ ☐ Cash position accurate                                                   │
│ ☐ Valuations accurate                                                      │
│ ☐ Reports generated and distributed                                         │
│ ☐ Exceptions logged and resolved                                           │
│ ☐ System backup completed                                                  │
└─────────────────────────────────────────────────────────────────────────────┘

EXCEPTION LOG (If any issues identified):
┌─────────────────────────────────────────────────────────────────────────────┐
│ Time   │ Issue Type           │ Description           │ Resolution          │
├────────┼──────────────────────┼──────────────────────┼─────────────────────┤
│        │                      │                      │                     │
├────────┼──────────────────────┼──────────────────────┼─────────────────────┤
│        │                      │                      │                     │
├────────┼──────────────────────┼──────────────────────┼─────────────────────┤
│        │                      │                      │                     │
└────────┴──────────────────────┴──────────────────────┴─────────────────────┘

APPROVAL: _____/_____/_____  ______________________  ______________________
                              (Compliance Officer)   (Operations Manager)
```

### 6. Weekly Progress Report Template

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                 WEEKLY PROGRESS REPORT - CMN 5.272 TRANSITION                ║
╚══════════════════════════════════════════════════════════════════════════════╝

Week Ending: _______________  Reporting Period: Week ___ of 24
Reported By: _______________  Review Status: _______________

┌─────────────────────────────────────────────────────────────────────────────┐
│ EXECUTIVE SUMMARY                                                            │
├─────────────────────────────────────────────────────────────────────────────┤
│ Overall Status: □ On Track  □ At Risk  □ Critical                           │
│ Current Phase: ___________________________________________________           │
│ Completion: ___% of current phase                                          │
│ Key Achievement This Week:                                                 │
│ _________________________________________________________________________   │
│ _________________________________________________________________________   │
│                                                                              │
│ Top Risk: _______________________________________________________________    │
│ _________________________________________________________________________   │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ MILESTONE PROGRESS                                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│ Milestone                    │ Plan Date │ Actual Date │ Status │ Notes     │
├──────────────────────────────┼───────────┼─────────────┼────────┼───────────┤
│                              │           │             │        │           │
├──────────────────────────────┼───────────┼─────────────┼────────┼───────────┤
│                              │           │             │        │           │
├──────────────────────────────┼───────────┼─────────────┼────────┼───────────┤
│                              │           │             │        │           │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ COMPLIANCE STATUS                                                            │
├─────────────────────────────────────────────────────────────────────────────┤
│ Category                │ Current Utilization │ Limit      │ Status        │
├─────────────────────────┼─────────────────────┼────────────┼───────────────┤
│ Renda Fixa             │ ________%          │ 100%       │ □ OK □ Watch  │
│ Renda Variável         │ ________%          │ ___%*      │ □ OK □ Watch  │
│ Invest. Estruturados   │ ________%          │ ___%*      │ □ OK □ Watch  │
│ Fundos Imobiliários    │ ________%          │ ___%*      │ □ OK □ Watch  │
│ Invest. Exterior       │ ________%          │ ___%*      │ □ OK □ Watch  │
│ Crédito Privado Global │ ________%          │ 35%        │ □ OK □ Watch  │
├─────────────────────────┴─────────────────────┴────────────┴───────────────┤
│ * Limit depends on governance level                                         │
│                                                                              │
│ Breaches This Week: _____  Resolved: _____  Open: _____                      │
│ Active Exceptions: _____  Critical: _____                                    │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ PORTFOLIO METRICS                                                            │
├─────────────────────────────────────────────────────────────────────────────┤
│ Metric                       │ Target      │ Actual      │ Variance        │
├──────────────────────────────┼─────────────┼─────────────┼─────────────────┤
│ Total Return (MTD)           │ IPCA + __%  │ _________   │ _________       │
│ Volatility                   │ ≤ ___%      │ _________   │ _________       │
│ Sharpe Ratio                 │ ≥ __.__     │ _________   │ _________       │
│ Max Drawdown                 │ ≤ ___%      │ _________   │ _________       │
│ Liquidity Ratio              │ ≥ __%       │ _________   │ _________       │
│ VaR 95%                      │ ≤ ___%      │ _________   │ _________       │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ ISSUES & RISKS                                                               │
├─────────────────────────────────────────────────────────────────────────────┤
│ Issue ID │ Priority │ Description              │ Owner    │ Due Date       │
├──────────┼──────────┼──────────────────────────┼──────────┼────────────────┤
│          │          │                          │          │                │
├──────────┼──────────┼──────────────────────────┼──────────┼────────────────┤
│          │          │                          │          │                │
├──────────┼──────────┼──────────────────────────┼──────────┼────────────────┤
│          │          │                          │          │                │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ NEXT WEEK'S PRIORITIES                                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│ 1. ______________________________________________________________________   │
│ 2. ______________________________________________________________________   │
│ 3. ______________________________________________________________________   │
│ 4. ______________________________________________________________________   │
│ 5. ______________________________________________________________________   │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ STAKEHOLDER COMMUNICATIONS                                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│ Communication          │ Date      │ Audience   │ Status                 │
├────────────────────────┼───────────┼────────────┼────────────────────────┤
│ Board Report           │ ___/___/__ │ Board      │ □ Scheduled □ Sent    │
│ Investment Committee   │ ___/___/__ │ Committee  │ □ Scheduled □ Sent    │
│ Staff Update           │ ___/___/__ │ All Staff  │ □ Scheduled □ Sent    │
│ Regulator Filing       │ ___/___/__ │ BCB        │ □ Scheduled □ Sent    │
└─────────────────────────────────────────────────────────────────────────────┘

APPROVALS:
__________________________              __________________________
(Transition Project Manager)          (Chief Investment Officer)

__________________________              __________________________
(Chief Risk Officer)                  (Chief Executive Officer)
```

### 7. Risk Monitoring Dashboard (Monthly)

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                    MONTHLY RISK MONITORING DASHBOARD                         ║
╚══════════════════════════════════════════════════════════════════════════════╝

Month: _______________  Governance Level: _______________  Prepared: ___________

┌─────────────────────────────────────────────────────────────────────────────┐
│ MARKET RISK SUMMARY                                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│ Risk Metric                    │ Value    │ Target   │ Limit    │ Status    │
├────────────────────────────────┼──────────┼──────────┼──────────┼───────────┤
│ Portfolio VaR (95%, 1-day)     │ __.__%   │ ≤ __.__% │ ≤ __.__% │ □ ● □ ○  │
│ Portfolio VaR (99%, 1-day)     │ __.__%   │ ≤ __.__% │ ≤ __.__% │ □ ● □ ○  │
│ Conditional VaR (95%)          │ __.__%   │ ≤ __.__% │ ≤ __.__% │ □ ● □ ○  │
│ Portfolio Beta                 │ __.__    │ __.__    │ __.__    │ □ ● □ ○  │
│ Tracking Error                 │ __.__%   │ ≤ __.__% │ ≤ __.__% │ □ ● □ ○  │
│ Volatility (Annualized)        │ __.__%   │ ≤ __.__% │ ≤ __.__% │ □ ● □ ○  │
│ Max Drawdown (YTD)             │ __.__%   │ ≤ __.__% │ ≤ __.__% │ □ ● □ ○  │
├────────────────────────────────┴──────────┴──────────┴──────────┴───────────┤
│ Legend: ● On Target  ○ Warning  ⚠ Critical                                         │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ CONCENTRATION RISK                                                           │
├─────────────────────────────────────────────────────────────────────────────┤
│ Concentration Type         │ Highest  │ Limit    │ Position  │ Status      │
├────────────────────────────┼──────────┼──────────┼───────────┼─────────────┤
│ Per Emitter (IF S1/S2)     │ __.__%   │ 5%       │ __________ │ □ ● □ ○ ⚠  │
│ Per Emitter (Others)       │ __.__%   │ 5%       │ __________ │ □ ● □ ○ ⚠  │
│ Per Fund (Standard)        │ __.__%   │ 15% PL   │ __________ │ □ ● □ ○ ⚠  │
│ Per Fund (Credit Private)  │ __.__%   │ 5% PL    │ __________ │ □ ● □ ○ ⚠  │
│ Per Issuer (Other Segments)│ __.__%   │ 2.5%     │ __________ │ □ ● □ ○ ⚠  │
│ Top 10 Positions           │ __.__%   │ ≤ __%    │ N/A       │ □ ● □ ○ ⚠  │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ SEGMENT ALLOCATION VS. LIMITS                                                │
├─────────────────────────────────────────────────────────────────────────────┤
│ Segment                   │ Actual  │ Target  │ Limit   │ Utilization│ Status│
├───────────────────────────┼─────────┼─────────┼─────────┼────────────┼───────┤
│ Renda Fixa                │ __.__%  │ __.__%  │ 100%    │ ___%       │ □ ● □ ○│
│ Renda Variável            │ __.__%  │ __.__%  │ ___%*   │ ___%       │ □ ● □ ○│
│ Fundos Imobiliários       │ __.__%  │ __.__%  │ 20%     │ ___%       │ □ ● □ ○│
│ Investimentos Estruturados│ __.__%  │ __.__%  │ 20%     │ ___%       │ □ ● □ ○│
│ Investimentos Exterior    │ __.__%  │ __.__%  │ 10%     │ ___%       │ □ ● □ ○│
│ Empréstimos Consignados   │ __.__%  │ __.__%  │ 5%      │ ___%       │ □ ● □ ○│
│ Crédito Privado Global    │ __.__%  │ N/A     │ 35%     │ ___%       │ □ ● □ ○│
├───────────────────────────┴─────────┴─────────┴─────────┴────────────┴───────┤
│ * Limit depends on governance level                                         │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ LIQUIDITY ANALYSIS                                                           │
├─────────────────────────────────────────────────────────────────────────────┤
│ Liquidity Tier            │ Value    │ % of AUM │ Exit Time   │ Status      │
├───────────────────────────┼──────────┼──────────┼─────────────┼─────────────┤
│ Tier 1 (High)             │ R$ __M   │ __.__%   │ T+1         │ □ ● □ ○     │
│ Tier 2 (Medium)           │ R$ __M   │ __.__%   │ T+7 to T+30 │ □ ● □ ○     │
│ Tier 3 (Low)              │ R$ __M   │ __.__%   │ T+30 to T+90│ □ ● □ ○     │
│ Tier 4 (Very Low)         │ R$ __M   │ __.__%   │ >T+90       │ □ ● □ ○     │
├───────────────────────────┼──────────┼──────────┼─────────────┼─────────────┤
│ Liquidity Ratio           │ ________ │          │             │             │
│ (Cash / 1-mo redemptions) │ __.__%   │ ≥100%    │             │ □ ● □ ○     │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ STRESS TEST RESULTS                                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│ Scenario                  │ Impact   │ Portfolio Value │ Drawdown  │ Action  │
├───────────────────────────┼──────────┼─────────────────┼───────────┼─────────┤
│ Market -20%              │ -__.__%  │ R$ __________   │ __.__%    │         │
│ Market -30%              │ -__.__%  │ R$ __________   │ __.__%    │         │
│ Market -40%              │ -__.__%  │ R$ __________   │ __.__%    │         │
│ Liquidity Crisis         │ -__.__%  │ R$ __________   │ __.__%    │         │
│ Interest Rate Shock      │ -__.__%  │ R$ __________   │ __.__%    │         │
│ Currency Devaluation     │ -__.__%  │ R$ __________   │ __.__%    │         │
├───────────────────────────┴──────────┴─────────────────┴───────────┴─────────┤
│ Required Actions:                                                           │
│ ☐ Review portfolio if drawdown > ___% in any scenario                       │
│ ☐ Activate contingency plan if drawdown > ___%                              │
│ ☐ Rebalance if actual results deviate > __% from expected                  │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ OPERATIONAL RISK                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│ Risk Type                 │ Incidents│ Severity  │ Open Issues│ Action     │
├───────────────────────────┼──────────┼──────────┼────────────┼─────────────┤
│ System Downtime           │ _____    │ ___       │ _____      │             │
│ Trade Errors              │ _____    │ ___       │ _____      │             │
│ Settlement Failures       │ _____    │ ___       │ _____      │             │
│ Data Quality              │ _____    │ ___       │ _____      │             │
│ Staff Turnover            │ _____    │ ___       │ _____      │             │
│ Vendor Issues             │ _____    │ ___       │ _____      │             │
├───────────────────────────┴──────────┴──────────┴────────────┴─────────────┤
│ Critical Issues Requiring Immediate Attention:                             │
│ _________________________________________________________________________   │
│ _________________________________________________________________________   │
└─────────────────────────────────────────────────────────────────────────────┘

REVIEWED BY:
___________________________              ___________________________
(Risk Manager)                          (Chief Risk Officer)

___________________________              ___________________________
(Investment Committee)                  (Board of Directors)
```

### 8. Certification Readiness Checklist

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                    CERTIFICATION READINESS CHECKLIST                         ║
╚══════════════════════════════════════════════════════════════════════════════╝

Governance Level: _______________  Target Certification Date: _______________
Prepared: _______________  Review Status: _______________

┌─────────────────────────────────────────────────────────────────────────────┐
│ GOVERNANCE DOCUMENTATION                                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│ Document                           │ Status  │ Owner    │ Last Review│ Notes│
├────────────────────────────────────┼─────────┼──────────┼───────────┼──────┤
│ Board-approved Investment Policy   │ ☐       │          │           │      │
│ Risk Management Framework          │ ☐       │          │           │      │
│ Governance Structure Documentation │ ☐       │          │           │      │
│ Investment Committee Charter       │ ☐       │          │           │      │
│ Compliance Procedures              │ ☐       │          │           │      │
│ Performance Attribution Methodology│ ☐       │          │           │      │
│ Trading & Execution Guidelines     │ ☐       │          │           │      │
│ Valuation Policies                 │ ☐       │          │           │      │
│ Conflict of Interest Policy        │ ☐       │          │           │      │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ SYSTEMS & CONTROLS                                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│ Control                           │ Status  │ Test Date │ Test Result│ Notes│
├────────────────────────────────────┼─────────┼──────────┼───────────┼──────┤
│ Portfolio Management System        │ ☐       │          │           │      │
│ Real-time Limit Monitoring         │ ☐       │          │           │      │
│ Compliance Pre-trade Checks        │ ☐       │          │           │      │
│ Risk Management System (VaR)       │ ☐       │          │           │      │
│ Stress Testing Module              │ ☐       │          │           │      │
│ Reporting System                   │ ☐       │          │           │      │
│ Data Warehouse                     │ ☐       │          │           │      │
│ Backup & Recovery                  │ ☐       │          │           │      │
│ Business Continuity Plan           │ ☐       │          │           │      │
│ Disaster Recovery Plan             │ ☐       │          │           │      │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ COMPLIANCE VALIDATION                                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│ Validation Item                   │ Status  │ Last Check│ Exceptions│ Notes│
├────────────────────────────────────┼─────────┼──────────┼───────────┼──────┤
│ All segment limits compliant       │ ☐       │          │      ___  │      │
│ All concentration limits compliant │ ☐       │          │      ___  │      │
│ No unauthorized investments        │ ☐       │          │      ___  │      │
│ All fund limits compliant          │ ☐       │          │      ___  │      │
│ All issuer limits compliant        │ ☐       │          │      ___  │      │
│ Liquidity requirements met         │ ☐       │          │      ___  │      │
│ Reporting requirements complete    │ ☐       │          │      ___  │      │
│ Documentation complete & current   │ ☐       │          │      ___  │      │
│ Staff training completed           │ ☐       │          │      ___  │      │
│ Internal audit completed           │ ☐       │          │      ___  │      │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ PERFORMANCE TRACKING                                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│ Metric                            │ Target  │ Actual   │ Status    │ Notes│
├────────────────────────────────────┼─────────┼──────────┼───────────┼──────┤
│ Total Return (YTD)                 │ IPCA+__%│ ___.__%  │ □ ● □ ○  │      │
│ Volatility (Annualized)            │ ≤ __.__%│ ___.__%  │ □ ● □ ○  │      │
│ Sharpe Ratio                       │ ≥ __.__ │ ___.__   │ □ ● □ ○  │      │
│ Max Drawdown                       │ ≤ __.__%│ ___.__%  │ □ ● □ ○  │      │
│ Information Ratio                  │ ≥ __.__ │ ___.__   │ □ ● □ ○  │      │
│ Tracking Error                     │ ≤ __.__%│ ___.__%  │ □ ● □ ○  │      │
│ Alpha                              │ ≥ __.__%│ ___.__%  │ □ ● □ ○  │      │
│ Beta                               │ __.__   │ ___.__   │ □ ● □ ○  │      │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ CERTIFICATION PACKAGE                                                         │
├─────────────────────────────────────────────────────────────────────────────┤
│ Document                           │ Status  │ Location │ Size      │ Notes│
├────────────────────────────────────┼─────────┼──────────┼───────────┼──────┤
│ Certification Application Form     │ ☐       │          │           │      │
│ Investment Policy                  │ ☐       │          │           │      │
│ Risk Management Manual             │ ☐       │          │           │      │
│ Governance Structure               │ ☐       │          │           │      │
│ Investment Committee Minutes       │ ☐       │          │           │      │
│ Internal Audit Report              │ ☐       │          │           │      │
│ Performance Reports (12 months)    │ ☐       │          │           │      │
│ Compliance Reports (12 months)     │ ☐       │          │           │      │
│ Portfolio Holdings (current)       │ ☐       │          │           │      │
│ Manager Selection Criteria         │ ☐       │          │           │      │
│ Stress Test Results                │ ☐       │          │           │      │
│ Legal Opinion (if applicable)      │ ☐       │          │           │      │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ STAKEHOLDER APPROVALS                                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│ Approver                          │ Title     │ Date     │ Status    │ Notes│
├────────────────────────────────────┼──────────┼──────────┼───────────┼──────┤
│ Investment Committee Chair        │           │          │ ☐         │      │
│ Chief Investment Officer          │           │          │ ☐         │      │
│ Chief Risk Officer                │           │          │ ☐         │      │
│ Chief Compliance Officer          │           │          │ ☐         │      │
│ CEO                               │           │          │ ☐         │      │
│ CFO                               │           │          │ ☐         │      │
│ Board of Directors                │           │          │ ☐         │      │
│ Legal Counsel                     │           │          │ ☐         │      │
│ External Auditor (if applicable)  │           │          │ ☐         │      │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ PRE-SUBMISSION VALIDATION                                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│ Validation Item                   │ Status  │ Reviewer │ Date      │ Notes│
├────────────────────────────────────┼─────────┼──────────┼───────────┼──────┤
│ Internal compliance review        │ ☐       │          │           │      │
│ Legal review of submission        │ ☐       │          │           │      │
│ Accuracy verification             │ ☐       │          │           │      │
│ Completeness check                │ ☐       │          │           │      │
│ Formatting to BCB requirements    │ ☐       │          │           │      │
│ Translation (if applicable)       │ ☐       │          │           │      │
│ Document assembly & organization  │ ☐       │          │           │      │
│ Electronic submission preparation │ ☐       │          │           │      │
│ Final quality control             │ ☐       │          │           │      │
│ Board final approval              │ ☐       │          │           │      │
└─────────────────────────────────────────────────────────────────────────────┘

READINESS ASSESSMENT:
☐ 100% Complete - Ready for submission
☐ 90-99% Complete - Minor items remaining
☐ 80-89% Complete - Significant items remaining
☐ <80% Complete - Not ready for submission

CRITICAL PATH ITEMS (Must complete before submission):
1. _________________________________________________________________
2. _________________________________________________________________
3. _________________________________________________________________

SUBMISSION TARGET DATE: _______________

APPROVED BY: ____________________________  DATE: _______________
                                         (Chief Executive Officer)
```

---

## Usage Instructions

### How to Use This Implementation Guide

1. **Daily Operations**: Use the Daily Compliance Checklist every trading day
2. **Weekly Reporting**: Complete the Weekly Progress Report every Friday
3. **Monthly Risk Review**: Use the Risk Monitoring Dashboard at month-end
4. **Sprint Planning**: Follow the 24-Week Sprint Plan for first 6 months
5. **Certification Preparation**: Use the Certification Readiness Checklist 60 days before each governance level application

### Template Customization

All templates are designed to be customized for your institution:
- Replace placeholder text (_____) with actual values
- Adjust target values based on your risk tolerance
- Modify categories to match your organizational structure
- Add additional metrics as needed for your specific requirements

### Distribution

- **Daily Checklist**: Operations team, Compliance officer
- **Weekly Report**: Project manager, CIO, CRO, CEO, Board
- **Monthly Dashboard**: Investment committee, Risk committee, Board
- **Certification Checklist**: Transition task force, External consultants, Board

---

**Document Version:** 1.0
**Last Updated:** February 6, 2026
**Next Review:** March 1, 2026
**Owner:** Transition Task Force

*This implementation guide provides practical tools and templates to support the portfolio restructuring strategy. Use these resources to ensure systematic, compliant, and efficient transition to CMN 5.272 requirements.*
