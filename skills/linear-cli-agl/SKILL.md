---
name: linear-cli-agl
description: >
  Manage Linear issues for AGL infrastructure projects via CLI. Use when the user asks to
  create Linear issues, search issues, manage projects, track bugs, link issues, update status,
  assign work, or query Linear teams/projects. Covers AGL teams: infra (agl-hostman, proxmox, tailscale),
  crowbar (backend, mobile), and OpenClaw. Supports linear CLI commands, GraphQL queries,
  git branch naming, and conventional commits integration.
---
# Linear CLI — AGL Infrastructure

## AGL Teams & Projects in Linear

| Team Key | Team Name | Projects |
|----------|-----------|----------|
| `INFRA` | Infrastructure | agl-hostman, LiteLLM, OpenClaw |
| `CROWBAR` | Crowbar | Backend API, Mobile App |
| `ENG` | Engineering | General development |

## Setup & Auth

```bash
# Install linear CLI
npm install -g @0xbigboss/linear-cli

# Auth — set API key
linear auth set
# Or via environment
export LINEAR_API_KEY="lin_api_..."

# Verify auth
linear auth test

# Set default team
linear config set default_team_id INFRA

# Set default output
linear config set default_output json

# Config location
~/.config/linear/config.json
```

### AGL Hosts — API Key Location

```bash
# On agldv03 (main dev host)
cat ~/.config/linear/config.json 2>/dev/null || echo "not configured"

# Or check env
echo $LINEAR_API_KEY
```

## Quick Recipes

### List my issues
```bash
linear issues list --team INFRA --assignee me --human-time
linear issues list --team CROWBAR --assignee me --state active
```

### Search issues
```bash
linear search "tailscale" --team INFRA --limit 10
linear search "bug" --team CROWBAR --limit 20
```

### Create an issue
```bash
# Infrastructure task
linear issue create --team INFRA --title "Deploy LiteLLM to agldv06" --yes

# Bug report
linear issue create --team CROWBAR --title "Backend API returns 500 on /auth" --priority urgent --yes

# With description
linear issue create --team INFRA --title "Add WireGuard monitoring" \
  --description "Set up wg show monitoring on fgsrv06 hub" \
  --yes
```

### View issue details
```bash
linear issue view INFRA-123
linear issue view INFRA-123 --json
linear issue view INFRA-123 --fields identifier,title,state,assignee,priority,url,description --json
```

### Update issue
```bash
# Change state
linear issue update INFRA-123 --state "In Progress" --yes

# Assign to self
linear issue update INFRA-123 --assignee me --yes

# Set priority
linear issue update INFRA-123 --priority high --yes

# Add labels
linear issue update INFRA-123 --labels "bug,urgent" --yes
```

### Link issues
```bash
# Block another issue
linear issue link INFRA-123 --blocks INFRA-456 --yes

# Mark as related
linear issue link INFRA-123 --related INFRA-789 --yes

# Mark as duplicate
linear issue link INFRA-123 --duplicate INFRA-999 --yes
```

### Add comment
```bash
linear issue comment INFRA-123 --body "Deployed to agldv03, testing on agldv04 next" --yes

# From file
cat /tmp/update.md | linear issue comment INFRA-123 --body-file - --yes
```

### List teams
```bash
linear teams list
linear teams list --json | jq '.teams.nodes[] | {key: .key, name}'
```

### List projects
```bash
linear projects list --limit 10
linear projects list --json | jq '.projects.nodes[] | {name, state}'
```

### Create project
```bash
linear project create --team $(linear teams list --json | jq -r '.teams.nodes[0].id') \
  --name "AGL Skills Deployment" --state active --yes
```

## AGL Workflow Examples

### Deploy task workflow
```bash
# 1. Create issue for deployment task
linear issue create --team INFRA --title "Deploy skills to agldv05" \
  --description "Run deploy-skills-all-hosts.sh --remote-only" \
  --yes
# → Returns INFRA-XXX

# 2. Create branch
git checkout -b INFRA-XXX/deploy-skills-agldv05

# 3. When done, update issue
linear issue update INFRA-XXX --state Completed --yes
```

### Bug tracking workflow
```bash
# 1. Report bug
linear issue create --team INFRA --title "agldv05 unreachable via Tailscale" \
  --priority urgent \
  --labels "networking,tailscale" \
  --yes
# → Returns INFRA-XXX

# 2. Investigate and update
linear issue update INFRA-XXX --state "In Progress" --assignee me --yes

# 3. Add findings
linear issue comment INFRA-XXX --body "Tailscale daemon not running, restarted" --yes

# 4. Close
linear issue update INFRA-XXX --state Completed --yes
```

### Epic with sub-issues
```bash
# 1. Create epic (parent)
linear issue create --team INFRA --title "Epic: Multi-host skills deployment" --yes
# → Returns INFRA-100

# 2. Get parent UUID
PARENT_UUID=$(linear issue view INFRA-100 --json | jq -r '.issue.id')

# 3. Create sub-issues
linear issue create --team INFRA --title "Create proxmox-agl skill" --yes
# → Returns INFRA-101
linear issue create --team INFRA --title "Create tailscale-agl skill" --yes
# → Returns INFRA-102

# 4. Link as sub-issues (need UUIDs)
CHILD_UUID=$(linear issue view INFRA-101 --json | jq -r '.issue.id')
linear issue update INFRA-101 --parent "$PARENT_UUID" --yes
```

## Command Reference

| Command | Purpose |
|---------|---------|
| `linear issues list` | List issues with filters |
| `linear search "keyword"` | Search issues by text |
| `linear issue view ID` | View single issue |
| `linear issue create` | Create new issue |
| `linear issue update ID` | Update issue (state, assignee, priority, labels) |
| `linear issue link ID` | Link issues (blocks, related, duplicate) |
| `linear issue comment ID` | Add comment |
| `linear issue delete ID` | Archive issue |
| `linear projects list` | List projects |
| `linear project create` | Create project |
| `linear teams list` | List teams |
| `linear me` | Show current user |
| `linear gql` | Run raw GraphQL |
| `linear config show` | Show CLI config |

## Common Flags

| Flag | Purpose |
|------|---------|
| `--team ID\|KEY` | Specify team (INFRA, CROWBAR, ENG) |
| `--json` | Output as JSON |
| `--yes` | Confirm without prompt |
| `--human-time` | Show relative timestamps |
| `--fields LIST` | Select specific fields |
| `--assignee me` | Assign to current user |
| `--priority urgent\|high\|medium\|low` | Set priority |
| `--state STATE` | Set state |
| `--labels "a,b"` | Set labels |

## Git Integration

### Branch naming
```bash
# Format: {TICKET}-{short-name}
git checkout -b INFRA-123/deploy-skills
git checkout -b CROWBAR-456/fix-auth-bug
```

### Commit messages
```bash
# Conventional commits with Linear ref in body
git commit -m "feat(skills): add proxmox-agl skill

Ref: INFRA-123"
```

## JSON Output & jq Patterns

```bash
# List issue IDs and titles
linear issues list --team INFRA --json | jq '.issues.nodes[] | {id: .identifier, title}'

# Get issue UUID
linear issue view INFRA-123 --json | jq -r '.issue.id'

# Filter by state
linear issues list --team INFRA --json | jq '.issues.nodes[] | select(.state.name == "Todo")'

# Get all active issues for a team
linear issues list --team INFRA --json | jq '[.issues.nodes[] | select(.state.type != "completed") | .identifier]'
```

## Common Gotchas

| Problem | Cause | Solution |
|---------|-------|----------|
| Empty results | No team specified | Add `--team INFRA` |
| 401 Unauthorized | Invalid/missing API key | Run `linear auth test` |
| Mutation does nothing | Missing confirmation | Add `--yes` flag |
| `--parent` fails | Using identifier | `--parent` requires UUID, not INFRA-123 |
| Can't find issue | Wrong ID | Use `linear search "text"` to find |

## GraphQL (Advanced)

For operations not covered by CLI commands:

```bash
# Raw GraphQL query
linear gql '{
  issues(filter: { team: { key: { eq: "INFRA" } } }, first: 10) {
    nodes {
      identifier
      title
      state { name }
      assignee { name }
    }
  }
}'

# Create issue via GraphQL
linear gql 'mutation {
  issueCreate(input: {
    teamId: "TEAM_UUID",
    title: "New issue",
    description: "Description here"
  }) {
    issue { identifier }
    success
  }
}'
```

## External Links
- [Linear API Docs](https://linear.app/developers/graphql)
- [Linear CLI GitHub](https://github.com/0xBigBoss/linear-cli)
- [Schema Explorer](https://studio.apollographql.com/public/Linear-API/variant/current/schema/reference)
