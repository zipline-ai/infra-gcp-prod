#!/usr/bin/env python3
"""Generate Excalidraw diagrams for the GCP deployment doc.

Produces native, editable .excalidraw files (rectangles/ellipses + bound text
labels + bound arrows). Import into Excalidraw via File -> Open or drag-drop.

Run: python3 gen_excalidraw.py
"""
import json

# ---- palette (Excalidraw default-ish tints) ----
COLORS = {
    "control": "#a5d8ff",   # blue
    "write":   "#b2f2bb",   # green
    "read":    "#ffec99",   # yellow
    "store":   "#ffd8a8",   # orange
    "meta":    "#eebefa",   # violet
    "support": "#e9ecef",   # gray
    "actor":   "#ced4da",   # darker gray
}
STROKE = "#1e1e1e"

_counter = [1000]
def _id():
    _counter[0] += 1
    return f"el{_counter[0]}"
def _nonce():
    _counter[0] += 1
    return _counter[0]


def _base(kind, x, y, w, h):
    return {
        "type": kind, "version": 1, "versionNonce": _nonce(), "isDeleted": False,
        "id": _id(), "fillStyle": "solid", "strokeWidth": 1, "strokeStyle": "solid",
        "roughness": 0, "opacity": 100, "angle": 0, "x": x, "y": y,
        "strokeColor": STROKE, "backgroundColor": "transparent",
        "width": w, "height": h, "seed": _nonce(), "groupIds": [], "frameId": None,
        "roundness": None, "boundElements": [], "updated": 1, "link": None, "locked": False,
    }


def add_text_bound(els, container, text):
    cx = container["x"] + container["width"] / 2
    cy = container["y"] + container["height"] / 2
    lines = text.split("\n")
    h = len(lines) * 20
    w = max(len(l) for l in lines) * 8
    t = _base("text", cx - w / 2, cy - h / 2, w, h)
    t.update({
        "fontSize": 16, "fontFamily": 2, "text": text, "textAlign": "center",
        "verticalAlign": "middle", "containerId": container["id"],
        "originalText": text, "lineHeight": 1.25, "baseline": 14,
    })
    container["boundElements"].append({"type": "text", "id": t["id"]})
    els.append(t)
    return t


def add_node(els, x, y, w, h, label, color, kind="rectangle", dashed=False):
    n = _base(kind, x, y, w, h)
    n["backgroundColor"] = color
    n["roundness"] = {"type": 3} if kind == "rectangle" else None
    if dashed:
        n["strokeStyle"] = "dashed"
    els.append(n)
    add_text_bound(els, n, label)
    return n


def add_container(els, x, y, w, h, title, color):
    c = _base("rectangle", x, y, w, h)
    c["backgroundColor"] = color
    c["opacity"] = 20
    c["roundness"] = {"type": 3}
    c["strokeStyle"] = "dashed"
    els.append(c)
    t = _base("text", x + 12, y + 8, len(title) * 8, 20)
    t.update({
        "fontSize": 16, "fontFamily": 2, "text": title, "textAlign": "left",
        "verticalAlign": "top", "containerId": None, "originalText": title,
        "lineHeight": 1.25, "baseline": 14, "strokeColor": "#495057",
    })
    els.append(t)
    return c


def _border(box, tx, ty):
    cx = box["x"] + box["width"] / 2
    cy = box["y"] + box["height"] / 2
    hw = box["width"] / 2
    hh = box["height"] / 2
    dx = tx - cx
    dy = ty - cy
    if dx == 0 and dy == 0:
        return cx, cy
    sx = hw / abs(dx) if dx != 0 else 1e9
    sy = hh / abs(dy) if dy != 0 else 1e9
    s = min(sx, sy)
    return cx + dx * s, cy + dy * s


def add_arrow(els, src, dst, label=None, dashed=False):
    scx = src["x"] + src["width"] / 2
    scy = src["y"] + src["height"] / 2
    dcx = dst["x"] + dst["width"] / 2
    dcy = dst["y"] + dst["height"] / 2
    sx, sy = _border(src, dcx, dcy)
    ex, ey = _border(dst, scx, scy)
    a = _base("arrow", sx, sy, abs(ex - sx), abs(ey - sy))
    a["roundness"] = {"type": 2}
    if dashed:
        a["strokeStyle"] = "dashed"
    a.update({
        "points": [[0, 0], [ex - sx, ey - sy]],
        "lastCommittedPoint": None,
        "startBinding": {"elementId": src["id"], "focus": 0, "gap": 6},
        "endBinding": {"elementId": dst["id"], "focus": 0, "gap": 6},
        "startArrowhead": None, "endArrowhead": "arrow",
    })
    src["boundElements"].append({"type": "arrow", "id": a["id"]})
    dst["boundElements"].append({"type": "arrow", "id": a["id"]})
    els.append(a)
    if label:
        mx = (sx + ex) / 2
        my = (sy + ey) / 2
        w = len(label) * 7
        t = _base("text", mx - w / 2, my - 10, w, 20)
        t.update({
            "fontSize": 13, "fontFamily": 2, "text": label, "textAlign": "center",
            "verticalAlign": "middle", "containerId": a["id"], "originalText": label,
            "lineHeight": 1.25, "baseline": 11, "backgroundColor": "#ffffff",
        })
        a["boundElements"].append({"type": "text", "id": t["id"]})
        els.append(t)
    return a


def write(path, els):
    doc = {
        "type": "excalidraw", "version": 2, "source": "gen_excalidraw.py",
        "elements": els,
        "appState": {"gridSize": None, "viewBackgroundColor": "#ffffff"},
        "files": {},
    }
    with open(path, "w") as f:
        json.dump(doc, f, indent=2)
    print(f"wrote {path} ({len(els)} elements)")


# ============================ System layout ============================
def system_layout():
    els = []
    add_container(els, 40, 45, 990, 125, "Control plane · zipline-system", COLORS["control"])
    nginx = add_node(els, 60, 95, 115, 55, "nginx proxy", COLORS["control"])
    ui = add_node(els, 190, 95, 115, 55, "Zipline UI", COLORS["control"])
    hub = add_node(els, 320, 95, 120, 55, "Orchestration\nHub", COLORS["control"])
    eval_ = add_node(els, 455, 95, 110, 55, "Eval", COLORS["control"])
    shs = add_node(els, 580, 95, 130, 55, "Spark History\nServer", COLORS["control"])
    grav = add_node(els, 725, 95, 130, 55, "Gravitino\ncatalog", COLORS["control"])
    ops = add_node(els, 870, 95, 145, 55, "Spark & Flink\noperators", COLORS["control"])

    add_container(els, 40, 200, 620, 125, "Write compute · zipline-{team}", COLORS["write"])
    spark = add_node(els, 60, 250, 120, 55, "Spark jobs", COLORS["write"])
    flink = add_node(els, 195, 250, 120, 55, "Flink jobs", COLORS["write"])
    loki = add_node(els, 330, 250, 150, 55, "Loki + promtail\nlogs", COLORS["write"])
    add_node(els, 495, 250, 150, 55, "Metrics\npluggable", COLORS["write"], dashed=True)

    add_container(els, 690, 200, 340, 125, "Read compute · zipline-system", COLORS["read"])
    fetcher = add_node(els, 720, 250, 290, 55, "Fetcher\nonline serving", COLORS["read"])

    add_container(els, 40, 355, 410, 135, "Data storage", COLORS["store"])
    gcs = add_node(els, 70, 405, 160, 65, "Cloud Storage\nIceberg datasets", COLORS["store"])
    bt = add_node(els, 255, 405, 160, 65, "Bigtable\nonline store", COLORS["store"])

    add_container(els, 480, 355, 260, 135, "Metadata storage", COLORS["meta"])
    sql = add_node(els, 510, 405, 200, 65, "Cloud SQL\njob data + table metadata", COLORS["meta"])

    add_container(els, 770, 355, 260, 220, "Source & supporting GCP", COLORS["support"])
    bq = add_node(els, 800, 405, 140, 60, "BigQuery\nsource warehouse", COLORS["store"])
    ps = add_node(els, 960, 405, 110, 60, "Pub/Sub", COLORS["support"])
    ar = add_node(els, 800, 495, 140, 55, "Artifact Registry", COLORS["support"])
    sm = add_node(els, 960, 495, 110, 55, "Secret Manager", COLORS["support"])

    add_arrow(els, nginx, ui)
    add_arrow(els, nginx, hub)
    add_arrow(els, hub, ops)
    add_arrow(els, ops, spark)
    add_arrow(els, ops, flink)
    add_arrow(els, spark, gcs)
    add_arrow(els, flink, gcs)
    add_arrow(els, spark, bt)
    add_arrow(els, flink, bt)
    add_arrow(els, grav, gcs)
    add_arrow(els, fetcher, bt)
    add_arrow(els, hub, sql, "job data")
    add_arrow(els, grav, sql, "table metadata")
    add_arrow(els, fetcher, ps, "logs", dashed=True)
    add_arrow(els, ps, bq)
    add_arrow(els, spark, ar, "pull images", dashed=True)
    add_arrow(els, hub, sm, "credentials", dashed=True)
    add_arrow(els, ar, sm, "token", dashed=True)
    return els


# ============================ Control flow ============================
def control_flow():
    els = []
    user = add_node(els, 40, 90, 160, 60, "User · CLI · schedule", COLORS["actor"], "ellipse")
    dev = add_node(els, 40, 200, 160, 55, "Developer", COLORS["actor"], "ellipse")
    app = add_node(els, 40, 440, 160, 60, "Your application", COLORS["actor"], "ellipse")

    hub = add_node(els, 260, 90, 150, 60, "Hub", COLORS["control"])
    eval_ = add_node(els, 260, 200, 150, 55, "Eval", COLORS["control"])
    ops = add_node(els, 470, 90, 140, 60, "Operators", COLORS["control"])
    comp = add_node(els, 660, 90, 180, 60, "Spark / Flink jobs", COLORS["write"])
    grav = add_node(els, 660, 200, 180, 55, "Gravitino", COLORS["control"])
    fetcher = add_node(els, 260, 440, 150, 60, "Fetcher", COLORS["read"])
    ps = add_node(els, 470, 440, 140, 60, "Pub/Sub", COLORS["support"])

    gcs = add_node(els, 920, 40, 170, 65, "Cloud Storage", COLORS["store"])
    bt = add_node(els, 920, 150, 170, 65, "Bigtable", COLORS["store"])
    sql = add_node(els, 920, 260, 180, 65, "Cloud SQL", COLORS["meta"])
    bq = add_node(els, 920, 400, 170, 70, "BigQuery\nsource", COLORS["store"])

    add_arrow(els, user, hub, "define & trigger")
    add_arrow(els, dev, eval_, "interactive test")
    add_arrow(els, hub, ops, "create CRDs")
    add_arrow(els, ops, comp, "launch")
    add_arrow(els, bq, comp, "raw data")
    add_arrow(els, comp, gcs, "produced datasets")
    add_arrow(els, comp, bt, "online features")
    add_arrow(els, comp, grav, "register tables")
    add_arrow(els, hub, sql, "job data")
    add_arrow(els, grav, sql, "table metadata")
    add_arrow(els, app, fetcher, "feature request")
    add_arrow(els, fetcher, bt, "read features")
    add_arrow(els, fetcher, ps, "log response")
    add_arrow(els, ps, bq)
    return els


if __name__ == "__main__":
    import os
    here = os.path.dirname(os.path.abspath(__file__))
    write(os.path.join(here, "architecture-gcp-system-layout.excalidraw"), system_layout())
    _counter[0] = 5000  # fresh id space for the second doc
    write(os.path.join(here, "architecture-gcp-control-flow.excalidraw"), control_flow())
