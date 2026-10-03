---
name: project-visualization
description: Use when an HTML call graph or code-flow visualization shows function names without explaining their implementations, or when a user wants a source-backed, explorable view of how project functions work.
---

# Project Visualization

Turn a generated code graph into an explorable, source-backed guide. Preserve the existing graph and explain each symbol from its real implementation; never infer behavior from a function name alone.

## Workflow

1. **Establish scope.** Read the HTML and identify its graph entrypoint, node IDs, labels, embedded metadata, and current interactions. Determine which source checkout/version generated it. State what the graph covers and what it omits; a call graph is not automatically a map of the whole repository.
2. **Resolve symbols to code.** Inventory every function, method, and constructor shown. Use node metadata first, then search and language parsers (for Python, prefer AST over text-only matches) to locate exact qualified definitions. Record source path, line span, signature, decorators, docstring, and relevant callers/callees. Disambiguate repeated names by module, class, and call path.
3. **Write evidence-based notes.** For each resolved symbol, explain its actual role, important inputs/outputs or side effects, and why it appears in this path. Separate direct code facts from interpretation. If the definition is missing, generated, external, or ambiguous, label it unresolved and say what is unknown. Do not fill gaps with name-based guesses. Use the user's language; keep summaries concise and use exact project terminology.
4. **Expose the implementation.** Keep the original graph layout and IDs. Add a searchable function list or detail panel linked to graph-node selection. For each resolved symbol show its purpose, source path and line span, existing docstring, and the exact function body in a collapsible, readable code block so the implementation is available without crowding the graph. Do not edit project source files to add these explanations.
5. **Preserve the page safely.** Escape source and annotation text as data; do not interpolate code into executable HTML/JavaScript. Keep graph libraries and existing interactions intact. Make the panel usable at narrow widths and with keyboard focus; selecting a graph node and its detail entry should stay synchronized.
6. **Validate before delivery.** Check that every graph node has exactly one annotation status, every resolved source link points to the correct definition, and no annotation IDs are missing or duplicated. Parse the HTML/data, run a JavaScript syntax check, and open the page to test search plus graph-to-detail navigation when a browser is available. Spot-check ambiguous and representative symbols against source. Report any check that could not be run; do not claim it passed.
7. **Deliver narrowly.** Preserve the original file or create a clearly named annotated copy, according to the user's request. Inspect the diff and leave unrelated work untouched. Summarize coverage, unresolved symbols, graph scope, output path, and validation.

## Annotation shape

Keep one record per stable graph node ID, for example:

```json
{
  "node_id": "module.py:42:method",
  "qualified_name": "Model.forward",
  "source": {"path": "pkg/model.py", "start_line": 42, "end_line": 68},
  "status": "verified",
  "purpose": "Combines ... and returns ...",
  "implementation": "Exact source text, if requested"
}
```

Use `status: "unresolved"` when exact source mapping is not established, with a short reason instead of a fabricated purpose. A symbol's label alone is not source evidence.

## Common mistakes

- **Guessing from names:** inspect the body, signature, docstring, and relevant call sites; otherwise mark unknown.
- **Confusing duplicate names:** resolve by qualified symbol and source path, not the first text match.
- **Overstating coverage:** name the graph entrypoint and generated scope, and call out omitted scripts or packages.
- **Breaking the visualization:** preserve its graph data, IDs, layout, and existing controls; add annotation UI alongside them.
- **Hiding uncertainty:** report unresolved and externally implemented nodes instead of silently presenting them as verified.
- **Claiming an unrun check:** distinguish static checks from actual browser interaction tests.
