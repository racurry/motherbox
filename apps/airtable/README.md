# Airtable

Web-based database and spreadsheet platform. No local installation required.

This app entry provides MCP server configuration and a data export script.

## Contents

- `.mcp.json` - MCP server configuration for Claude Desktop integration
- `extract-data.js` - Script to export all data from an Airtable base

## MCP Server Setup

The MCP configuration uses [airtable-mcp-server](https://github.com/domdomegg/airtable-mcp-server) to allow Claude Desktop or Claude Code to read and write Airtable data.

### 1. Get an API Token

1. Go to [Airtable Developer Hub](https://airtable.com/create/tokens)
2. Click **Create new token**
3. Name your token and select scopes:
   - `schema.bases:read` (required)
   - `data.records:read` (required)
   - `data.records:write` (optional, for write access)
4. Select which bases/workspaces the token can access
5. Copy the token (shown only once)

### 2. Set Environment Variable

Add to `~/.zshenv`:

```bash
export AIRTABLE_API_TOKEN="pat..."
```

### 3. Configure Claude Desktop

Copy `.mcp.json` contents to your Claude Desktop MCP configuration.

## Data Export Script

Export all tables, records, and attachments from any Airtable base:

```bash
# List available bases
node apps/airtable/extract-data.js

# Export by name or ID
node apps/airtable/extract-data.js "Base Name"
node apps/airtable/extract-data.js apphIp20oHxZ7JbW1
```

Exports to `airtable-export/{base-id}/` with:

- `data/` - JSON files per table (schema + records)
- `images/` - Downloaded attachments
- `migration-report.txt` - Summary report

## Syncing Preferences

Not applicable. Airtable is web-based; data lives in the cloud.

## References

- [Airtable Developer Hub](https://airtable.com/developers)
- [Creating Personal Access Tokens](https://support.airtable.com/docs/creating-personal-access-tokens)
- [airtable-mcp-server](https://github.com/domdomegg/airtable-mcp-server)
