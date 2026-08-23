# Rules for Codex

- **Use parallelization**: Delegate non-trivial,self-contained tasks when they can run in parallel or when the main agent needs only their conclusions rather than their full working context. 
    - Trivial tasks should be handled by the main agent - delegation causes more session & token consumption that just doing it.
- **No boilerplate in new projects**: When creating a new project, focus on the application. Do not add open-source, community, or other boilerplate; no licenses, author or contributor attribution, contributing guides, or similar.
