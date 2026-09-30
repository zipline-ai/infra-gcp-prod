# Diagrams

Editable Excalidraw sources for the GCP deployment architecture.

| File | Diagram |
|---|---|
| `architecture-gcp-system-layout.excalidraw` | System layout — components grouped by function |
| `architecture-gcp-control-flow.excalidraw` | Control flow — write path + read/serving path |

## Editing

Open at [excalidraw.com](https://excalidraw.com) via **File → Open**, or drag a
`.excalidraw` file onto the canvas. Elements are native (rectangles, ellipses, bound
arrows + labels), so positions and text are fully editable.

## Regenerating

The files are generated from `gen_excalidraw.py` (so layout changes can be scripted
rather than hand-placed):

```
python3 gen_excalidraw.py
```

The script lays out the functional groups in bands and wires the arrows; nudge node
positions afterwards in Excalidraw if you want a tighter layout. Keep these in sync with
the Mermaid diagrams in `../architecture-gcp.md`.
