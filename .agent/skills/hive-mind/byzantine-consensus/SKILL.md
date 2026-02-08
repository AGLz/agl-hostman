# Byzantine Consensus

**Category**: Coordination | **Priority**: Critical | **Agent Type**: Queen Coordinator

## Overview

Byzantine Consensus provides fault tolerance and malicious agent detection in distributed swarm systems. It implements voting mechanisms, quarantine procedures, and consensus validation to ensure system integrity even when some agents fail or behave maliciously.

## Core Capabilities

### 1. Byzantine Fault Tolerance
```yaml
Fault Types Tolerated:
  - Crash Failures: Agent stops responding
  - Omission Failures: Agent fails to send/receive messages
  - Timing Failures: Agent responds outside time window
  - Arbitrary Failures: Agent sends arbitrary/malicious responses
```

### 2. Voting Mechanisms
```yaml
Voting Strategies:
  - Majority: >50% agreement required
  - Supermajority: ≥67% agreement required
  - Unanimity: 100% agreement required
  - Weighted: Votes weighted by trust score
```

### 3. Quarantine System
```yaml
Quarantine Triggers:
  - Consistent failure patterns
  - Malicious behavior detected
  - Validation failures > threshold
  - Consensus violations
```

### 4. Consensus Validation
```yaml
Validation Methods:
  - Result comparison: Compare outputs from multiple agents
  - Cross-validation: Validate results against known standards
  - Consistency checks: Verify internal consistency
  - Reputation scoring: Track agent reliability over time
```

## MCP Tool Integration

### Initialize Byzantine Protection
```bash
# Enable Byzantine fault tolerance
mcp__claude-flow__consensus_builder \
  --algorithm="pbft" \
  --fault-tolerance=3 \
  --validation="strict" \
  --quarantine="enabled"

# Configure consensus parameters
mcp__claude-flow__quorum_manager \
  --quorum-type="supermajority" \
  --min-validators=5 \
  --timeout=300
```

### Run Consensus Round
```bash
# Execute consensus vote
mcp__claude-flow__byzantine-coordinator \
  --proposal="Use OAuth 2.0 for authentication" \
  --validators="worker-1,worker-2,worker-3,worker-4,worker-5" \
  --threshold="67%"

# Validate agent outputs
mcp__claude-flow__consensus_builder \
  --action="validate" \
  --task-id="task-001" \
  --agents="worker-1,worker-2,worker-3"
```

### Quarantine Malicious Agent
```bash
# Isolate problematic agent
mcp__claude-flow__security_manager \
  --action="quarantine" \
  --agent-id="worker-4" \
  --reason="consistent_validation_failures" \
  --duration="3600"

# Release from quarantine
mcp__claude-flow__security_manager \
  --action="release" \
  --agent-id="worker-4" \
  --condition="performance_improves"
```

## Memory Coordination Protocol

### 1. Initialize Consensus State
```javascript
// Set up Byzantine consensus system
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/consensus/state",
  namespace: "coordination",
  value: JSON.stringify({
    algorithm: "pbft", // Practical Byzantine Fault Tolerance
    fault_tolerance: 3, // Can tolerate up to 3 faulty agents
    total_validators: 7,
    minimum_quorum: 5,
    consensus_threshold: 0.67, // 67% supermajority
    validation_strictness: "high",
    quarantine_enabled: true,
    initialized_at: Date.now()
  })
}
```

### 2. Initiate Consensus Vote
```javascript
// Start voting on proposal
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/consensus/vote-001",
  namespace: "coordination",
  value: JSON.stringify({
    vote_id: "vote-001",
    proposal: "Use PostgreSQL as primary database",
    proposal_type: "technical_decision",
    proposed_by: "worker-1",
    validators: ["worker-1", "worker-2", "worker-3", "worker-4", "worker-5"],
    votes: {
      "worker-1": "approve",
      "worker-2": "pending",
      "worker-3": "pending",
      "worker-4": "pending",
      "worker-5": "pending"
    },
    votes_received: 1,
    votes_required: 4, // 80% supermajority
    status: "pending",
    created_at: Date.now(),
    deadline: Date.now() + 1800000 // 30 minutes
  })
}
```

### 3. Cast Vote
```javascript
// Agent submits vote
mcp__claude-flow__memory_usage {
  action: "update",
  key: "swarm/consensus/vote-001",
  namespace: "coordination",
  value: JSON.stringify({
    votes: {
      "worker-1": "approve",
      "worker-2": "approve",
      "worker-3": "approve",
      "worker-4": "reject",
      "worker-5": "approve"
    },
    votes_received: 5,
    status: "approved",
    consensus_reached: true,
    approval_percentage: 80,
    decided_at: Date.now()
  })
}
```

### 4. Validate Agent Outputs
```javascript
// Compare outputs from multiple agents
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/consensus/validation/task-001",
  namespace: "coordination",
  value: JSON.stringify({
    task_id: "task-001",
    task_type: "code_generation",
    validators: ["worker-1", "worker-2", "worker-3"],
    outputs: {
      "worker-1": {
        code: "function auth() { ... }",
        hash: "sha256:abc123",
        lines: 45
      },
      "worker-2": {
        code: "function auth() { ... }",
        hash: "sha256:abc123",
        lines: 45
      },
      "worker-3": {
        code: "function auth() { ...different... }",
        hash: "sha256:def456",
        lines: 78
      }
    },
    similarity: {
      "worker-1_vs_worker-2": 1.0, // Identical
      "worker-1_vs_worker-3": 0.3, // Different
      "worker-2_vs_worker-3": 0.3
    },
    consensus_reached: true,
    outlier: "worker-3",
    validation_status: "passed_with_outlier"
  })
}
```

### 5. Quarantine Malicious Agent
```javascript
// Isolate problematic agent
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/quarantine/worker-4",
  namespace: "coordination",
  value: JSON.stringify({
    agent_id: "worker-4",
    status: "quarantined",
    quarantined_at: Date.now(),
    quarantine_reason: "consistent_validation_failures",
    incident_count: 5,
    incidents: [
      { type: "validation_failure", task_id: "task-003", timestamp: Date.now() - 7200000 },
      { type: "validation_failure", task_id: "task-005", timestamp: Date.now() - 3600000 },
      { type: "malicious_output", task_id: "task-007", timestamp: Date.now() - 1800000 }
    ],
    release_conditions: [
      "pass_5_consecutive_validations",
      "manual_review_approval"
    ],
    estimated_release: Date.now() + 3600000, // 1 hour
    quarantined_by: "byzantine-coordinator"
  })
}
```

### 6. Track Agent Reputation
```javascript
// Maintain trust scores for agents
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/consensus/reputation",
  namespace: "coordination",
  value: JSON.stringify({
    agents: {
      "worker-1": {
        trust_score: 98,
        total_votes: 50,
        consensus_agreement: 49, // 98%
        validations_passed: 95,
        validations_failed: 2,
        quarantine_count: 0,
        reputation: "excellent"
      },
      "worker-2": {
        trust_score: 95,
        total_votes: 48,
        consensus_agreement: 46,
        validations_passed: 90,
        validations_failed: 3,
        quarantine_count: 0,
        reputation: "good"
      },
      "worker-3": {
        trust_score: 72,
        total_votes: 45,
        consensus_agreement: 32,
        validations_passed: 70,
        validations_failed: 12,
        quarantine_count: 1,
        reputation: "fair"
      },
      "worker-4": {
        trust_score: 35,
        total_votes: 40,
        consensus_agreement: 14,
        validations_passed: 50,
        validations_failed: 25,
        quarantine_count: 2,
        reputation: "poor"
      }
    },
    last_updated: Date.now()
  })
}
```

## Consensus Algorithms

### 1. Practical Byzantine Fault Tolerance (PBFT)
```python
def pbft_consensus(proposal, validators, faulty_tolerance=1):
    """
    PBFT: 3-phase consensus (pre-prepare, prepare, commit)
    Can tolerate up to f faulty nodes with 3f+1 total nodes
    """
    f = faulty_tolerance
    n = len(validators)
    required = 2 * f + 1  # Need 2f+1 matching votes

    # Phase 1: Pre-Prepare (primary proposes)
    pre_prepare = send_to_validators(proposal, primary=validators[0])

    # Phase 2: Prepare (validators broadcast prepare messages)
    prepare_messages = []
    for validator in validators:
        if validator_accepts(validator, pre_prepare):
            prepare_msg = create_prepare_message(validator, proposal)
            prepare_messages.append(prepare_msg)

    # Check if we have enough prepare messages
    if len(prepare_messages) < required:
        return {"status": "failed", "reason": "insufficient_prepares"}

    # Phase 3: Commit (validators broadcast commit messages)
    commit_messages = []
    for validator in validators:
        if validator_received_prepares(validator, prepare_messages, required):
            commit_msg = create_commit_message(validator, proposal)
            commit_messages.append(commit_msg)

    # Check if we have enough commit messages
    if len(commit_messages) >= required:
        return {"status": "committed", "proposal": proposal}
    else:
        return {"status": "failed", "reason": "insufficient_commits"}
```

### 2. Weighted Voting
```python
def weighted_consensus(proposal, votes, weights):
    """
    Consensus with weighted votes based on trust scores
    """
    total_weight = sum(weights.values())
    approve_weight = sum(weights[voter] for voter, vote in votes.items() if vote == "approve")

    approval_percentage = (approve_weight / total_weight) * 100

    if approval_percentage >= 67:  # Supermajority threshold
        return {
            "status": "approved",
            "approval_percentage": approval_percentage,
            "total_weight": total_weight
        }
    else:
        return {
            "status": "rejected",
            "approval_percentage": approval_percentage,
            "required": 67
        }
```

### 3. Result Validation
```python
def validate_consensus(results, threshold=0.8):
    """
    Validate if multiple agents produced consistent results
    """
    from difflib import SequenceMatcher

    # Compare all pairs of results
    similarities = []
    for i, result_a in enumerate(results):
        for j, result_b in enumerate(results):
            if i < j:
                similarity = SequenceMatcher(None, result_a, result_b).ratio()
                similarities.append(similarity)

    # Calculate average similarity
    avg_similarity = sum(similarities) / len(similarities)

    # Identify outliers
    outliers = []
    for i, result in enumerate(results):
        avg_sim_for_result = sum([
            SequenceMatcher(None, result, other).ratio()
            for j, other in enumerate(results) if i != j
        ]) / (len(results) - 1)

        if avg_sim_for_result < threshold:
            outliers.append(i)

    return {
        "consensus_reached": avg_similarity >= threshold,
        "average_similarity": avg_similarity,
        "outliers": outliers,
        "outlier_count": len(outliers)
    }
```

## Malicious Behavior Detection

### Detection Patterns
```yaml
Anomaly Detection:
  - Output deviates significantly from consensus
  - Consistently produces errors
  - Response time outside normal range
  - Violates established protocols

Behavioral Analysis:
  - Pattern of disagreeing with majority
  - Fails validation tests repeatedly
  - Produces nonsensical or harmful outputs
  - Attempts to manipulate consensus process
```

### Detection Algorithm
```python
def detect_malicious_behavior(agent, history, threshold=3):
    """
    Detect if an agent is behaving maliciously
    """
    incidents = []

    # Check for validation failures
    validation_failures = [
        h for h in history
        if h['agent'] == agent and h['type'] == 'validation_failure'
    ]
    if len(validation_failures) > threshold:
        incidents.append("excessive_validation_failures")

    # Check for consensus deviation
    deviations = [
        h for h in history
        if h['agent'] == agent and h.get('outlier', False)
    ]
    if len(deviations) > threshold:
        incidents.append("frequent_consensus_deviation")

    # Check for malicious content
    malicious = [
        h for h in history
        if h['agent'] == agent and h.get('malicious', False)
    ]
    if len(malicious) > 0:
        incidents.append("malicious_content_detected")

    # Determine quarantine action
    if len(incidents) >= 2:
        return {
            "agent": agent,
            "status": "quarantine_recommended",
            "incidents": incidents,
            "incident_count": len(incidents),
            "severity": "high"
        }
    elif len(incidents) == 1:
        return {
            "agent": agent,
            "status": "monitor",
            "incidents": incidents,
            "incident_count": len(incidents),
            "severity": "medium"
        }
    else:
        return {
            "agent": agent,
            "status": "healthy",
            "incidents": [],
            "incident_count": 0,
            "severity": "low"
        }
```

## Quarantine Management

### Quarantine Lifecycle
```yaml
States:
  - healthy: Normal operation
  - monitoring: Under observation
  - quarantined: Isolated from swarm
  - probation: Limited access after quarantine
  - banned: Permanently removed

Transitions:
  healthy -> monitoring: Suspicious behavior
  monitoring -> quarantined: Confirmed malicious
  quarantined -> probation: Meets release conditions
  probation -> healthy: Proven reliable
  probation -> quarantined: Re-offends
  any -> banned: Severe or repeated violations
```

### Release Conditions
```javascript
// Define conditions for quarantine release
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/quarantine/release-policy",
  namespace: "coordination",
  value: JSON.stringify({
    automatic_release: {
      enabled: true,
      min_quarantine_duration: 3600000, // 1 hour
      consecutive_validations_required: 5,
      validation_success_rate: 95
    },
    manual_release: {
      enabled: true,
      requires_reviewer_approval: true,
      min_reviewers: 2
    },
    probation_period: {
      enabled: true,
      duration: 86400000, // 24 hours
      limited_task_access: true,
      monitoring_level: "high"
    }
  })
}
```

## Best Practices

### 1. Consensus Configuration
- Use supermajority (67%) for critical decisions
- Use majority (51%) for non-critical decisions
- Require minimum of 3f+1 validators for f faulty tolerance
- Adjust threshold based on fault tolerance requirements

### 2. Validation Strategy
- Validate outputs from multiple agents
- Use cross-validation for important tasks
- Implement similarity thresholds for result comparison
- Track and learn from validation patterns

### 3. Quarantine Management
- Quarantine early to prevent damage
- Define clear release conditions
- Implement probation period after quarantine
- Allow manual override for edge cases

### 4. Reputation Tracking
- Maintain trust scores for all agents
- Update scores based on contributions
- Use reputation for weighted voting
- Allow reputation recovery over time

## Monitoring and Metrics

### Consensus Metrics
```bash
# Track consensus operations
mcp__claude-flow__metrics_collect \
  --component="byzantine-consensus" \
  --metrics="consensus_rounds,voting_latency,agreement_rate"

# Analyze fault tolerance
mcp__claude-flow__performance_report \
  --format="fault-tolerance" \
  --timeframe="24h"
```

### Security Monitoring
```bash
# Monitor for malicious activity
mcp__claude-flow__security_manager \
  --action="monitor" \
  --alerts=true \
  --threshold="medium"
```

## Usage Example

```bash
# Initialize Byzantine consensus
claude-flow skill byzantine-consensus

# Configure fault tolerance
mcp__claude-flow__consensus_builder \
  --algorithm="pbft" \
  --fault-tolerance=3

# Run consensus vote
mcp__claude-flow__byzantine-coordinator \
  --proposal="Use PostgreSQL as database" \
  --validators="worker-1,worker-2,worker-3,worker-4,worker-5"

# Validate agent outputs
mcp__claude-flow__consensus_builder \
  --action="validate" \
  --agents="worker-1,worker-2,worker-3"

# Quarantine if needed
mcp__claude-flow__security_manager \
  --action="quarantine" \
  --agent-id="worker-4" \
  --reason="validation_failures"
```

## Related Skills

- **hive-mind-coordinator**: Strategic coordination
- **swarm-communication**: Memory sharing for voting
- **agent-spawning**: Worker creation with trust scores
- **task-distribution**: Fault-tolerant task allocation

## Metrics Targets

- Consensus Agreement Rate: >95%
- False Positive Rate: <5%
- Quarantine Accuracy: >90%
- Average Consensus Latency: <30 seconds
- Malicious Agent Detection: >95%
