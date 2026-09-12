rules/
======

Path-scoped rules. Each .md file here carries YAML frontmatter naming the globs it
applies to:

    ---
    paths:
      - "**/scripts/**"
      - "**/*.ps1"
    ---

A rule reaches the model when a file matching one of its globs is opened with the Read
tool. That is the whole point of the mechanism: knowledge that is only occasionally
relevant costs nothing until the moment it is.

Two consequences worth remembering:

  * A rule with no `paths:` frontmatter is not scoped, and is paid for in every session.
    If something is true everywhere, it belongs in CLAUDE.md instead, where it is at
    least visible in one place.

  * This file is .txt, not .md, on purpose. A .md file in this directory is treated as a
    rule. Notes to a human reader are not rules and should not be loaded as ones.

Keep a rule to what a competent person would get wrong on the first attempt, and say why
— a rule that only states a conclusion gets argued with; one that explains the failure it
prevents does not.
