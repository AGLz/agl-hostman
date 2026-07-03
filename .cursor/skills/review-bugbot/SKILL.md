---
name: review-bugbot
description: Review code changes with Bugbot subagent.
origin: agl-hostman (vendored from cursor skills-cursor)
---
# Review Bugbot

Use this skill when the user asks to run `/review-bugbot`.

Launch exactly one `bugbot` subagent with:

- `readonly: true`
- `run_in_background: false` unless explicitly asked to run in background
- `description: "Bugbot"`
- `subagent_type: "bugbot"`

The review subagent computes the local diff from the repository path, so do not compute the diff yourself before launching it. The repository path should be the active workspace or repository root for the code the user wants reviewed.

By default, the review subagent infers the repository's actual base branch, such as `main`, when computing `branch changes`. In most cases, do not provide `Base Branch`. Only provide it if you know the current branch or PR should be compared against a specific branch other than the repository's default base branch, such as when you created the current branch from another branch.

Use this exact prompt shape:

```text
Full Repository Path: <absolute repository path>
Diff: <one of: "branch changes", "uncommitted changes", "natural language">
Base Branch: <only include this line when reviewing branch changes against a known specific base branch>
Change Description: <required only when Diff is "natural language">
Custom Instructions: <only include this line when the user gave specific review instructions>
```

Default to `branch changes`.

After the subagent finishes, summarize findings in a table: Severity | Location | Finding.

Do not fix findings unless the user explicitly asks.
