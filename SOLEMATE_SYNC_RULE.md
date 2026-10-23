# Workflow Rule: solemate-p1 and project 1 Pairing

### Roles
- **solemate-p1**: Dedicated analyzer & bug finder (runs scheduled audits on the codebase to identify false outputs, dead UI elements, and bugs).
- **project 1**: Dedicated builder & fixer (where all features, fixes, and builds happen).

### Protocol when user says "fix the issues from solemate-p1":
1. **Direct Transcript Ingestion (No copy-paste needed from user)**:
   - Check `C:\Users\PC\.gemini\antigravity\sidecar_data\solemate-p1\events/` for the latest event.
   - Read the latest output from `C:\Users\PC\.gemini\antigravity\brain/<conversationId>/.system_generated/logs/transcript.jsonl`.
2. **List All Discovered Issues**:
   - Provide a clear, categorized list of everything `solemate-p1` identified so the user can verify full comprehension.
3. **Fix and Validate**:
   - Resolve every issue in `c:\Users\PC\Desktop\project 1`.
   - Run `npm run build` and `npx cap sync`.
