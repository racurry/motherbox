# Readwise

MCP servers for accessing Readwise highlights and Reader documents from AI tools. Two servers are available:

| Server                            | Auth            | Transport | Tools    | Best for                                     |
| --------------------------------- | --------------- | --------- | -------- | -------------------------------------------- |
| **readwise** (official)           | OAuth (browser) | HTTP      | Full API | General use, zero config                     |
| **readwise-enhanced** (community) | API token       | stdio/npx | 13 tools | Highlights search, daily review, bulk export |

## MCP Server Setup

### Official Readwise MCP

The official server is hosted remotely -- no npm package or API token needed. Authentication uses OAuth via browser.

**Claude Code:**

```bash
claude mcp add --transport http readwise https://mcp2.readwise.io/mcp
```

Run `/mcp` in Claude Code and follow the authentication prompt.

**Other MCP clients:** Copy the `readwise` entry from `.mcp.json` to your client's config.

### Readwise Enhanced MCP

A community server that adds highlights management, daily review, advanced search, and context-optimized responses. Runs locally via npx.

1. Get your Readwise API token: https://readwise.io/access_token

2. Add the token to `~/.local.zshrc`:

   ```bash
   export READWISE_TOKEN="your_token_here"
   ```

3. Add the server:

   ```bash
   claude mcp add readwise-enhanced npx readwise-mcp-enhanced --env READWISE_TOKEN="${READWISE_TOKEN}"
   ```

**Other MCP clients:** Copy the `readwise-enhanced` entry from `.mcp.json` to your client's config, replacing `${READWISE_TOKEN}` with your actual token.

#### Enhanced tools (beyond official)

- **readwise_list_highlights** -- filter by book, date, pagination
- **readwise_get_daily_review** -- spaced repetition highlights
- **readwise_search_highlights** -- field-specific queries with relevance scoring
- **readwise_list_books** -- books with highlight counts and metadata
- **readwise_get_book_highlights** -- all highlights from a specific book
- **readwise_export_highlights** -- bulk export for analysis/backup
- **readwise_create_highlight** -- manually add highlights with metadata

## Syncing Preferences

Repo sync. MCP server config stored in `.mcp.json` in this repo. Auth tokens are managed locally (`~/.local.zshrc` for the enhanced server, MCP client OAuth for the official server).

## References

- [Readwise MCP Setup (official)](https://readwise.io/mcp)
- [readwise-mcp-enhanced (GitHub)](https://github.com/arnaldo-delisio/readwise-mcp-enhanced)
- [readwise-mcp-enhanced (npm)](https://www.npmjs.com/package/readwise-mcp-enhanced)
- [Readwise API Token](https://readwise.io/access_token)
