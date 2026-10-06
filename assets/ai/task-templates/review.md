---
name: Review
description: Review the uncommitted changes and fix real problems
mode: run
---
Review the current uncommitted changes of this project for bugs, missing
error handling, unclear code and missing tests. Fix the problems you are
confident about; list the rest as suggestions in your summary.

{{input}}

Changes to review:

```diff
{{diff}}
```
