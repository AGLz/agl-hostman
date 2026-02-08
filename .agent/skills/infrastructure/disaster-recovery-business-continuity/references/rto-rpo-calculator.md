# RTO/RPO Calculator

**Version:** 1.0
**Purpose:** Calculate Recovery Time Objectives (RTO) and Recovery Point Objectives (RPO) for system components.

## Table of Contents

1. [Definitions](#definitions)
2. [Business Impact Analysis](#business-impact-analysis)
3. [RTO Calculation](#rto-calculation)
4. [RPO Calculation](#rpo-calculation)
5. [Interactive Calculator](#interactive-calculator)
6. [Examples](#examples)

## Definitions

### Recovery Time Objective (RTO)

The maximum acceptable length of time that a service can be unavailable after a disaster.

**Formula:**
```
RTO = Detection Time + Decision Time + Execution Time + Validation Time
```

**Components:**
- **Detection Time:** Time to identify the incident
- **Decision Time:** Time to decide on recovery strategy
- **Execution Time:** Time to perform recovery procedures
- **Validation Time:** Time to verify systems are operational

### Recovery Point Objective (RPO)

The maximum acceptable amount of data loss measured in time.

**Formula:**
```
RPO = Backup Frequency + Replication Lag
```

**Components:**
- **Backup Frequency:** How often backups are created
- **Replication Lag:** Delay in data synchronization

## Business Impact Analysis

### Impact Assessment Matrix

| Impact Level | Revenue/Hour | User Impact | Reputation | RTO Target |
|--------------|--------------|-------------|------------|------------|
| **Critical** | >$10,000 | All users | Severe damage | < 15 minutes |
| **High** | $1,000-$10,000 | Most users | Significant | < 1 hour |
| **Medium** | $100-$1,000 | Some users | Moderate | < 4 hours |
| **Low** | <$100 | Few users | Minimal | < 24 hours |

### System Criticality Scoring

**Score Components:**

1. **Revenue Impact** (0-10 points)
   - 10: Direct revenue generation
   - 7: Indirect revenue impact
   - 5: Customer retention impact
   - 3: Operational efficiency
   - 0: No revenue impact

2. **User Impact** (0-10 points)
   - 10: All users blocked
   - 7: Most users affected
   - 5: Some users affected
   - 3: Power users affected
   - 0: Internal tool

3. **Dependency Score** (0-10 points)
   - 10: Other systems depend on this
   - 7: Several dependencies
   - 5: Some dependencies
   - 3: Few dependencies
   - 0: No dependencies

4. **Compliance Impact** (0-10 points)
   - 10: Regulatory requirement
   - 7: Contractual SLA
   - 5: Customer commitment
   - 3: Internal policy
   - 0: No compliance requirement

**Criticality Score = Revenue + User + Dependency + Compliance**

| Score Range | Criticality | Default RTO |
|-------------|-------------|-------------|
| 35-40 | Mission Critical | 15 min |
| 28-34 | Critical | 1 hour |
| 20-27 | Important | 4 hours |
| 12-19 | Moderate | 24 hours |
| 0-11 | Low | 48 hours |

## RTO Calculation

### Component Breakdown

```bash
#!/bin/bash
# RTO Calculation Script

# Input parameters
DETECTION_TIME="${1:-5}"        # Time to detect incident (minutes)
DECISION_TIME="${2:-10}"        # Time to decide on action (minutes)
EXECUTION_TIME="${3:-30}"       # Time to execute recovery (minutes)
VALIDATION_TIME="${4:-10}"      # Time to validate systems (minutes)

# Calculate RTO
RTO=$((DETECTION_TIME + DECISION_TIME + EXECUTION_TIME + VALIDATION_TIME))

echo "RTO Calculation:"
echo "  Detection Time:    ${DETECTION_TIME} min"
echo "  Decision Time:     ${DECISION_TIME} min"
echo "  Execution Time:    ${EXECUTION_TIME} min"
echo "  Validation Time:   ${VALIDATION_TIME} min"
echo "  ──────────────────────────────"
echo "  Total RTO:         ${RTO} min"
echo "  Total RTO:         $((RTO / 60)) hours $((RTO % 60)) minutes"
```

### System-Specific RTO Examples

#### Database RTO Calculation

| Component | Time | Notes |
|-----------|------|-------|
| Detection | 2 min | Automated health check |
| Decision | 5 min | Automatic failover trigger |
| Execution | 15 min | Database promotion time |
| Validation | 5 min | Data integrity checks |
| **Total** | **27 min** | **Target: < 30 min** |

#### Application RTO Calculation

| Component | Time | Notes |
|-----------|------|-------|
| Detection | 3 min | Monitoring alert |
| Decision | 10 min | Manual evaluation |
| Execution | 20 min | Service startup |
| Validation | 5 min | Health check endpoints |
| **Total** | **38 min** | **Target: < 45 min** |

### RTO Optimization Strategies

1. **Reduce Detection Time**
   - Implement automated health checks
   - Use synthetic monitoring
   - Set up alert aggregation

2. **Reduce Decision Time**
   - Pre-defined failover triggers
   - Automated decision trees
   - Clear escalation paths

3. **Reduce Execution Time**
   - Automated failover scripts
   - Pre-provisioned standby capacity
   - Infrastructure as Code

4. **Reduce Validation Time**
   - Automated test suites
   - Health check endpoints
   - Parallel validation

## RPO Calculation

### Component Breakdown

```bash
#!/bin/bash
# RPO Calculation Script

# Input parameters
BACKUP_FREQUENCY="${1:-15}"     # Backup frequency (minutes)
REPLICATION_LAG="${2:-2}"       # Replication lag (minutes)

# Calculate RPO
RPO=$((BACKUP_FREQUENCY + REPLICATION_LAG))

echo "RPO Calculation:"
echo "  Backup Frequency:   ${BACKUP_FREQUENCY} min"
echo "  Replication Lag:    ${REPLICATION_LAG} min"
echo "  ──────────────────────────────"
echo "  Total RPO:          ${RPO} min"
```

### Backup Frequency Options

| Type | Frequency | Storage | RPO | Cost |
|------|-----------|---------|-----|------|
| Continuous | Real-time | Highest | < 1 min | Highest |
| Streaming | < 5 min | High | < 5 min | High |
| Frequent | 15 min | Medium | 15 min | Medium |
| Hourly | 60 min | Low | 60 min | Low |
| Daily | 1440 min | Lowest | 1440 min | Lowest |

### Replication Lag by Type

| Replication Type | Typical Lag | Cost | Complexity |
|------------------|-------------|------|------------|
| Synchronous | < 1 sec | High | Low |
| Semi-synchronous | 1-5 sec | Medium | Medium |
| Asynchronous | 5-60 sec | Low | Low |
| Batch | 1-5 min | Lowest | Low |

### System-Specific RPO Examples

#### Transactional Database RPO

| Component | Time | Notes |
|-----------|------|-------|
| Backup Frequency | 5 min | Continuous backup |
| Replication Lag | 2 sec | Async replication |
| **Total** | **5.03 min** | **Target: < 15 min** |

#### Analytics Database RPO

| Component | Time | Notes |
|-----------|------|-------|
| Backup Frequency | 60 min | Hourly backups |
| Replication Lag | 5 min | Batch replication |
| **Total** | **65 min** | **Target: < 2 hours** |

## Interactive Calculator

### Web-Based Calculator

```html
<!DOCTYPE html>
<html>
<head>
    <title>RTO/RPO Calculator</title>
    <style>
        .calculator { max-width: 600px; margin: 40px auto; padding: 20px; }
        .section { margin: 20px 0; padding: 15px; background: #f5f5f5; }
        input[type="number"] { width: 80px; padding: 5px; }
        label { display: inline-block; width: 180px; }
        .result { font-size: 24px; font-weight: bold; margin: 20px 0; }
        .critical { color: #dc3545; }
        .warning { color: #ffc107; }
        .good { color: #28a745; }
    </style>
</head>
<body>
    <div class="calculator">
        <h1>RTO/RPO Calculator</h1>

        <div class="section">
            <h2>RTO Calculation</h2>
            <label>Detection Time (min):</label>
            <input type="number" id="detection" value="5"><br>
            <label>Decision Time (min):</label>
            <input type="number" id="decision" value="10"><br>
            <label>Execution Time (min):</label>
            <input type="number" id="execution" value="30"><br>
            <label>Validation Time (min):</label>
            <input type="number" id="validation" value="10"><br>
            <button onclick="calculateRTO()">Calculate RTO</button>
            <div id="rtoResult" class="result"></div>
        </div>

        <div class="section">
            <h2>RPO Calculation</h2>
            <label>Backup Frequency (min):</label>
            <input type="number" id="backup" value="15"><br>
            <label>Replication Lag (min):</label>
            <input type="number" id="replication" value="2"><br>
            <button onclick="calculateRPO()">Calculate RPO</button>
            <div id="rpoResult" class="result"></div>
        </div>
    </div>

    <script>
        function calculateRTO() {
            const detection = parseInt(document.getElementById('detection').value);
            const decision = parseInt(document.getElementById('decision').value);
            const execution = parseInt(document.getElementById('execution').value);
            const validation = parseInt(document.getElementById('validation').value);

            const rto = detection + decision + execution + validation;
            const hours = Math.floor(rto / 60);
            const minutes = rto % 60;

            let className = 'good';
            if (rto > 240) className = 'critical';
            else if (rto > 60) className = 'warning';

            document.getElementById('rtoResult').className = 'result ' + className;
            document.getElementById('rtoResult').innerHTML =
                `RTO: ${rto} minutes (${hours}h ${minutes}m)`;
        }

        function calculateRPO() {
            const backup = parseInt(document.getElementById('backup').value);
            const replication = parseInt(document.getElementById('replication').value);

            const rpo = backup + replication;
            const hours = Math.floor(rpo / 60);
            const minutes = rpo % 60;

            let className = 'good';
            if (rpo > 60) className = 'critical';
            else if (rpo > 15) className = 'warning';

            document.getElementById('rpoResult').className = 'result ' + className;
            document.getElementById('rpoResult').innerHTML =
                `RPO: ${rpo} minutes (${hours}h ${minutes}m)`;
        }
    </script>
</body>
</html>
```

## Examples

### Example 1: E-Commerce Platform

**System Components:**

| Component | Revenue Impact | User Impact | Dependency | Compliance | Score |
|-----------|----------------|-------------|------------|------------|-------|
| Product Database | 10 | 10 | 10 | 7 | 37 |
| Shopping Cart | 10 | 10 | 7 | 5 | 32 |
| Payment Service | 10 | 10 | 10 | 10 | 40 |
| User Auth | 7 | 10 | 10 | 7 | 34 |
| Search Service | 7 | 7 | 5 | 0 | 19 |

**Calculated Targets:**

| Component | Criticality | RTO | RPO | Strategy |
|-----------|-------------|-----|-----|----------|
| Payment Service | Mission Critical | 15 min | 5 min | Active-active with synchronous replication |
| Product Database | Mission Critical | 15 min | 5 min | Multi-AZ with streaming replication |
| Shopping Cart | Mission Critical | 30 min | 5 min | Active-passive with async replication |
| User Auth | Critical | 1 hour | 5 min | Active-passive with async replication |
| Search Service | Moderate | 4 hours | 1 hour | Pilot light with hourly backups |

### Example 2: SaaS Application

**Business Impact:**

- Revenue: $5,000/hour downtime
- Users: 10,000 active users
- SLA: 99.9% uptime (43 min/month downtime allowed)
- Compliance: SOC2 required

**System Targets:**

| System | RTO | RPO | Justification |
|--------|-----|-----|---------------|
| API Gateway | 15 min | 1 min | Entry point, affects all users |
| Application Server | 30 min | 0 min | Stateless, can be redeployed |
| Primary Database | 15 min | 5 min | Core data, high value |
| Cache Layer | 1 hour | 0 min | Can be rebuilt from primary |
| File Storage | 2 hours | 15 min | Important but not critical |
| Analytics | 24 hours | 1 day | Non-critical, batch processing |

### Example 3: Internal Tool

**Business Impact:**

- Revenue: $0 (internal tool)
- Users: 50 employees
- SLA: None
- Compliance: None

**System Targets:**

| System | RTO | RPO | Justification |
|--------|-----|-----|---------------|
| Application | 4 hours | 1 hour | Low priority, internal use only |
| Database | 4 hours | 1 hour | Can tolerate longer downtime |
| File Storage | 24 hours | 1 day | Non-critical data |

## Cost vs. Recovery Trade-offs

### Cost Analysis by RTO/RPO

| RTO | RPO | Architecture | Monthly Cost | Cost/Hour of Downtime* |
|-----|-----|--------------|--------------|----------------------|
| 15 min | 5 min | Active-active, multi-region | $10,000 | $13.70 |
| 1 hour | 15 min | Active-passive, single region | $3,000 | $4.11 |
| 4 hours | 1 hour | Pilot light | $500 | $0.69 |
| 24 hours | 24 hours | Backups only | $100 | $0.14 |

\*Based on 730 hours/month

### Break-Even Analysis

**Question:** How much downtime justifies the investment?

```
Additional monthly cost / Cost per hour of downtime =
Break-even downtime hours

Example:
($10,000 - $3,000) / $5,000 per hour =
$7,000 / $5,000 =
1.4 hours
```

**Conclusion:** If more than 1.4 hours of downtime is prevented per month, the investment is justified.

## Best Practices

1. **Align RTO/RPO with business impact**
   - Not all systems need the same recovery targets
   - Use criticality scoring to prioritize

2. **Consider total cost of ownership**
   - Include infrastructure, licensing, and operational costs
   - Factor in staff time for maintenance and testing

3. **Validate targets regularly**
   - Conduct DR drills to test actual RTO/RPO
   - Update targets based on business changes

4. **Document exceptions**
   - When targets cannot be met, document why
   - Get executive sign-off on exceptions

5. **Review quarterly**
   - Business requirements change
   - Technology costs decrease over time
   - New solutions may become available
