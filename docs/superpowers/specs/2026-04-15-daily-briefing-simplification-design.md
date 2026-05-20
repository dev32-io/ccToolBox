# Daily Briefing Skill Simplification Design

## Overview
This document outlines a simplified approach to the daily briefing skill that flattens the agent layer structure, reduces complexity for smaller models, and provides platform-specific handling while maintaining core functionality.

## Problem Statement
The current implementation uses multiple parallel agents which:
- Increases complexity for smaller language models
- Creates potential for hallucinations due to complex flow control
- Requires platform-specific model specifications (claude-code vs opencode)
- Makes debugging more difficult

## Solution Approach

### 1. Flattened Agent Structure
Replace the multi-agent workflow with a simplified, single-agent approach:
- Sequential execution instead of parallel agents
- Reduced number of sub-agents from ~13 to 1 main agent
- Simplified data flow and decision points

### 2. Platform Agnostic Configuration
Remove platform-specific model requirements from skill definition:
- Default to cheaper/faster models automatically for all platforms  
- Use consistent model selection across both Claude Code and OpenCode
- Allow users to configure advanced settings through the existing configuration system if needed

## Implementation Details

### Agent Workflow Simplification
Instead of running 13+ agents in parallel, we'll consolidate into:
1. Settings initialization (read user config, initialize paths)
2. Data fetching (sequential step-by-step)  
3. Lead story selection and image acquisition
4. Content generation (TTS text + HTML)
5. Output generation and cleanup

### Model Selection Strategy
- For Claude Code: Default to "sonnet" for content generation tasks
- For OpenCode: Default to "haiku" or cheaper alternatives
- All configuration handled through settings files, not skill definition  

## Architecture Changes

### Before (Current):
```
Skill → Orchestrator Agent → 13+ Parallel Subagents 
    ↓
[Weather] [Tech-HN] [Tech-Dev.to] ... [Extra]
     ↓       ↓        ↓          ↓
   Fetch   Fetch   Fetch      Fetch
```

### After (Simplified):  
```
Skill → Simplified Single Agent
    ↓
Fetch Data → Select Lead Story → Generate Content → Output Files
```

## Technical Implementation Plan

1. **Modify daily-briefing-agent.md** to use simplified workflow
2. **Update skill definition** to remove model-specific requirements 
3. **Refactor agent execution patterns** to be more straightforward for smaller models
4. **Create platform handling logic** that works across Claude Code and OpenCode with appropriate defaults

## Error Handling Improvements
- Clearer error messages
- Fallback strategies for missing data  
- Better graceful degradation when components fail

This approach reduces complexity from 13+ parallel agents to a single agent with sequential steps, making it much more suitable for execution by smaller language models while preserving all core functionality.