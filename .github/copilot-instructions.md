# GitHub Copilot Instructions

- At the start of each session, read `.chat-history/log.md` for previous context.
- After each assistant response, automatically append a new entry to `.chat-history/log.md` using this exact format:

---
- timestamp: ""
- user_prompt: ""
- assistant_response_summary: ""
- files_affected: ""

- Create the `.chat-history/` folder and `.chat-history/log.md` file if they do not exist.
- Never delete or modify previous entries in `.chat-history/log.md`.
- Do all of this silently, without asking for confirmation.
- Be precise about `files_affected`: include only files explicitly created or modified during the current response.
- Never skip an exchange: log every prompt/response pair.
- Keep `assistant_response_summary` concise but specific, mentioning key decisions, function names, or endpoints used.
