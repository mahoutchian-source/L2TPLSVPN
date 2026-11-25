#!/bin/bash
echo "$@" >> /tmp/claude-0/-home-claude/f0cc29cf-e6f5-55c9-bb53-60df7b8738b7/scratchpad/t21/gw.log
exec bash /tmp/claude-0/-home-claude/f0cc29cf-e6f5-55c9-bb53-60df7b8738b7/scratchpad/t21/../build/l2tp-gw "$@"
