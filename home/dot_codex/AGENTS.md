# Rules for Codex

- **Use parallelization**: Delegate non-trivial,self-contained tasks when they can run in parallel or when the main agent needs only their conclusions rather than their full working context. 
    - Trivial tasks should be handled by the main agent - delegation causes more session & token consumption that just doing it.
- **No boilerplate in new projects**: When creating a new project, focus on the application. Do not add open-source, community, or other boilerplate; no licenses, author or contributor attribution, contributing guides, or similar.

## Product copy

Treat user-facing copy as product design, not as evidence that an implementation task was completed. Do not add labels, notices, descriptions, badges, empty states, or helper text merely to narrate technical decisions, internal architecture, migrations, removed behavior, discarded alternatives, or capabilities the product does not have. Put that information in tests, developer documentation, commit or PR descriptions, and the agent's handoff instead.

Every piece of UI text must help the user perform the current task, understand the current state, make a decision, or recover from a problem. Ask: **Would this copy still belong here if the feature had always worked this way?** If not, omit it. Text about security, constraints, or implementation behavior is appropriate only when the user needs it at that point to choose an action or avoid a meaningful consequence; keep it concise and phrase it in terms of the user's task.

When changing behavior, do not add UI copy just to call attention to the change. Preserve the product's existing voice, and avoid changelog language such as “now,” “still,” “no longer,” “unlike before,” or lists of things the app does not do unless that historical contrast is itself necessary for the user.
