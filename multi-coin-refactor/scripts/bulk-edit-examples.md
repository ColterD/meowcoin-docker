// #region Bulk Editing Examples
/**
 * # Bulk Editing Examples for Large-Scale Codebase Changes
 * Includes sed/find+sed for rollback, recovery, secret management, backup/restore, and advanced use cases.
 * See also: Red Hat, Karandeep Singh, and GeeksforGeeks sed guides.
 * Cross-links: ONBOARDING.md, MONITORING.md, FAQ.md, TROUBLESHOOTING.md, BACKUP_RESTORE.md, SECURITY.md, core/secrets/index.ts
 * TODO[roadmap]: Expand with onboarding, rollback, secret management, and advanced bulk edit flows.
 */

## VS Code Multi-Cursor & Find/Replace
- **Change All Occurrences**: Select a word, then press `Ctrl+D` (Windows/Linux) or `Cmd+D` (Mac) repeatedly to select all instances. Edit them all at once.
- **Multi-Cursor Editing**: Hold `Alt` (Windows/Linux) or `Option` (Mac) and click to place multiple cursors, or use `Ctrl+Alt+Down/Up` (`Cmd+Option+Down/Up` on Mac) to add cursors to adjacent lines.
- **Project-wide Find & Replace**: Press `Ctrl+Shift+F` (`Cmd+Shift+F` on Mac) to open the search panel, enter your search and replace terms, and apply changes across the entire workspace.
- [VS Code Bulk Edit Guide](https://dev.to/ahandsel/easily-bulk-edit-files-in-visual-studio-code-4pp1)

## sed & find+sed (CLI)
- **Batch update secret keys in all files:**
  ```bash
  find . -type f -name '*.ts' -exec sed -i 's/oldSecretKey/newSecretKey/g' {} +
  ```
- **Rotate all secrets in a config file:**
  ```bash
  sed -i 's/oldSecretValue/newSecretValue/g' secrets.json
  ```
- **Audit backup/restore changes in logs:**
  ```bash
  grep -i 'backup\|restore' logs/app.log
  ```
- **Basic single-file replacement:**
  ```bash
  sed -i 's/oldText/newText/g' file.txt
  ```
- **All files in a directory:**
  ```bash
  sed -i 's/oldText/newText/g' *.ts
  ```
- **Recursive replacement in subdirectories:**
  ```bash
  find . -name '*.ts' -exec sed -i 's/oldText/newText/g' {} +
  ```
- **Backup before replacing:**
  ```bash
  sed -i.bak 's/oldText/newText/g' *.ts
  ```
- **Rollback using backup:**
  ```bash
  find . -name '*.ts.bak' -exec sh -c 'mv "$1" "${1%.bak}"' _ {} \;
  ```
- **Recovery: revert all .bak files:**
  ```bash
  for f in $(find . -name '*.bak'); do mv "$f" "${f%.bak}"; done
  ```
- **Replace only nth occurrence in a line:**
  ```bash
  sed -i 's/oldText/newText/2' file.txt
  # Replace 2nd occurrence; use /3, /4, etc. for nth
  ```
- **Replace all occurrences from nth onward in a line:**
  ```bash
  sed -i 's/oldText/newText/3g' file.txt
  # Replace 3rd and onward
  ```
- **Replace on a specific line number:**
  ```bash
  sed -i '5 s/oldText/newText/' file.txt
  # Replace only on line 5
  ```
- **Regex replace (e.g., parenthesize first char of each word):**
  ```bash
  sed -i 's/\(\b[A-Z]\)/\(\1\)/g' file.txt
  ```
- **Advanced: Replace across multiple file types and directories:**
  ```bash
  find . -type f \( -name '*.ts' -o -name '*.js' \) -exec sed -i 's/oldText/newText/g' {} +
  ```
- **Advanced: Replace with confirmation (interactive):**
  ```bash
  find . -name '*.ts' -exec sed -i.bak -e 's/oldText/newText/g' {} +
  # Review .bak files before finalizing
  ```
- [Red Hat sed guide](https://www.redhat.com/en/blog/edit-text-bash-command)
- [Karandeep Singh sed guide](https://karandeepsingh.ca/posts/replace-text-multiple-files-sed-guide/)
- [GeeksforGeeks sed guide](https://www.geeksforgeeks.org/sed-command-in-linux-unix-with-examples/)

## Sourcegraph Batch Changes (Cross-Repo)
- **Batch spec YAML example:**
  ```yaml
  name: update-api-endpoint
  description: Update API endpoint across all repos
  on:
    - repositoriesMatchingQuery: old_api.example.com
  steps:
    - run: |
        find . -type f -name '*.ts' | xargs sed -i 's/old_api.example.com/new_api.example.com/g'
      container: alpine:3
  changesetTemplate:
    title: Update API endpoint
    body: Update API endpoint in all TypeScript files
    branch: batch-changes/update-api-endpoint
    commit:
      message: Update API endpoint
    published: false
  ```
- [Sourcegraph Batch Changes Docs](https://about.sourcegraph.com/batch-changes)
- [Sourcegraph Search & Replace Guide](https://sourcegraph.com/docs/batch-changes/search-and-replace-specific-terms)

## Best Practices
- Always create backups or use version control before bulk edits.
- Test on a subset of files first.
- Review all changes with `git diff` before committing.
- Commit in logical, reviewable steps.
- For onboarding, monitoring, secret management, and FAQ-related bulk edits, see ONBOARDING.md, MONITORING.md, BACKUP_RESTORE.md, SECURITY.md, and core/secrets/index.ts for rollback/recovery guidance. After bulk edits or rollback, review the secret audit log (see getSecretAuditLog in core/secrets/index.ts).
- For feedback loop persistence and validation, see core/feedback/index.ts and core/feedback/feedbacks.json. After bulk edits, validate feedback storage and monitoring logs. TODO[roadmap]: DB integration for feedback.
// #endregion 

// #region Documentation Index
// ... existing code ...
// TODO[roadmap]: Add OpenAPI/Swagger integration, DB-backed storage, advanced E2E, and region folding best practices
// #endregion 