# vane

AI-powered search interface using a local LLM and SearXNG as the search backend.

## Prerequisites

### SearXNG Configuration

SearXNG instance must have the following enabled:

- **JSON format** — enable under Settings → Search → Formats
- **Wolfram Alpha** — enable under Settings → Engines → Wolfram Alpha

## Configuration

| Variable | Value |
|---|---|
| `SEARXNG_URL` | Internal SearXNG service URL |
| `OPENAI_API_BASE` | LM Studio API base URL |
| `OPENAI_API_KEY` | Dummy value (`sk-xx`) — not validated by LM Studio |
