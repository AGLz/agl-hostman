#!/usr/bin/env bash
jq '.agents.defaults.model // .agents.defaults, .agents.list // empty' /root/.openclaw/openclaw.json 2>/dev/null | head -40
