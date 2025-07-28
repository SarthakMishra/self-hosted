# 🔧 MCP Server Setup for OpenWebUI

This setup includes **mcpo** - a proxy that converts MCP (Model Context Protocol) servers into OpenAPI-compatible HTTP endpoints that OpenWebUI can use as tools.

## 🚀 Quick Setup

1. **Configure your MCP servers** in `mcp-config.json`
2. **Set your API key** in `.env`: `MCPO_API_KEY=your_secure_key_here`
3. **Deploy**: `docker compose up -d`
4. **Connect to OpenWebUI** at: `http://mcpo:8001`

## 📝 MCP Configuration

Edit `mcp-config.json` to add your MCP servers:

```json
{
  "mcpServers": {
    "memory": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"]
    },
    "time": {
      "command": "uvx", 
      "args": ["mcp-server-time", "--local-timezone=America/New_York"]
    }
  }
}
```

## 🛠️ Popular MCP Servers

| Server | Purpose | Setup |
|--------|---------|-------|
| **memory** | Persistent memory | `npx -y @modelcontextprotocol/server-memory` |
| **time** | Date/time utilities | `uvx mcp-server-time` |
| **filesystem** | File operations | `npx -y @modelcontextprotocol/server-filesystem /path` |
| **brave-search** | Web search | `npx -y @modelcontextprotocol/server-brave-search` |
| **github** | GitHub integration | `npx -y @modelcontextprotocol/server-github` |

## 🔑 Environment Variables

Required in your `.env` file:

```env
# MCPO Configuration
MCPO_API_KEY=your_secure_mcpo_api_key_here
MCPO_PORT=8001

# API Keys for specific servers
BRAVE_API_KEY=your_brave_api_key
GITHUB_PERSONAL_ACCESS_TOKEN=your_github_token
```

## 🔗 OpenWebUI Integration

After deployment, configure OpenWebUI to use MCP tools:

1. **Go to Settings → Connections → OpenAPI**
2. **Add new endpoint**: `http://mcpo:8001`
3. **API Key**: Use your `MCPO_API_KEY`
4. **Save and test connection**

Each MCP server will be available at its own route:
- `http://mcpo:8001/memory` - Memory tools
- `http://mcpo:8001/time` - Time tools
- `http://mcpo:8001/github` - GitHub tools

## 🔍 Testing

View auto-generated API docs for each server:
- `http://mcpo:8001/memory/docs`
- `http://mcpo:8001/time/docs`

## 📚 More MCP Servers

Find more servers at:
- [MCP Server Registry](https://github.com/modelcontextprotocol/servers)
- [Community Servers](https://github.com/topics/mcp-server)

## 🐛 Troubleshooting

**Check logs**: `docker compose logs mcpo`
**Test connectivity**: `docker compose exec openwebui curl http://mcpo:8001/health`
**Verify config**: Ensure `mcp-config.json` is valid JSON 