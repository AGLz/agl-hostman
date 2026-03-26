#!/usr/bin/env bash
jq '.agents.defaults.models // {} | keys' /root/.openclaw/openclaw.json
