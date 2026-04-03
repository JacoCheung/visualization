// Compile: typst compile pipeline_timeline.typ
// Online: https://typst.app (paste this file, instant preview)

#import "@preview/cetz:0.3.2"

#set page(width: 78cm, height: 21cm, margin: 0.8cm)
#set text(font: "Noto Sans", size: 9pt)

// ── Colors ──────────────────────────────────────────
#let cDef = rgb("#2B579A")
#let cMem = rgb("#217346")
#let cCpu = rgb("#C55A11")
#let cPre = rgb("#2E75B6")
#let cDat = rgb("#7030A0")
#let cSync = rgb("#C00000")
#let cOra = rgb("#ED7D31")
#let cBwd = rgb("#4a3580")

// ── Layout constants ────────────────────────────────
#let lane-h   = 1.3
#let lane-gap = 0.45
#let lane-total = lane-h + lane-gap
#let label-w  = 3.8
#let ts       = 0.27

#let CYCLE = 82
#let NUM-ITERS = 3
#let MAX-T = CYCLE * NUM-ITERS

#let tx(t) = label-w + t * ts
#let ly(i) = -(i * lane-total)
#let lmy(i) = ly(i) - lane-h / 2

// ── Batch name helper ───────────────────────────────
#let bn(n) = if n == 0 { "N" } else { "N+" + str(n) }

// ── Stream definitions ──────────────────────────────
#let streams = (
  (name: "default_stream",    thread: "main thread",  color: cDef),
  (name: "_memcpy_stream",    thread: "main thread",  color: cMem),
  (name: "CPU bg thread",     thread: "KK executor",  color: cCpu),
  (name: "_prefetch_stream",  thread: "main thread",  color: cPre),
  (name: "_data_dist_stream", thread: "main thread",  color: cDat),
)

// ── Per-iteration data generation ───────────────────
// Each op: (num, name, stream-idx, t0, t1, color, done)
#let all-ops = ()
#let all-barriers = ()
#let all-idles = ()

#let iter-bg = (
  cDef.lighten(95%),
  cMem.lighten(95%),
  cCpu.lighten(95%),
)
#let iter-border = (cDef, cMem, cCpu)

#for iter in range(NUM-ITERS) {
  let off = iter * CYCLE
  let bF = bn(iter)
  let bP = bn(iter + 1)
  let bH = bn(iter + 2)

  // done blocks for all iterations
  all-ops.push(("1",  "[" + bF + "] pf done",   3, off,    off + 6, cPre, true,  iter))
  all-ops.push(("3",  "[" + bP + "] dist done", 4, off,    off + 6, cDat, true,  iter))

  all-ops.push(("2",  "H2D [" + bH + "]",         1, off + 7,  off + 14, cMem, false, iter))
  all-ops.push(("4",  "AG wkld [" + bH + "]",      1, off + 16, off + 24, cMem, false, iter))
  all-ops.push(("6",  "forward [" + bF + "]",      0, off + 22, off + 42, cDef, false, iter))
  all-ops.push(("5",  "KK [" + bH + "]",           2, off + 24, off + 38, cCpu, false, iter))
  all-ops.push(("7",  "AG+idx [" + bH + "]",       1, off + 38, off + 50, cMem, false, iter))
  all-ops.push(("9",  "loss AR [" + bF + "]",      0, off + 52, off + 60, cOra, false, iter))
  all-ops.push(("10", "prefetch [" + bP + "]",     3, off + 53, off + 62, cPre, false, iter))
  all-ops.push(("12", "bwd+opt [" + bF + "]",      0, off + 65, off + 82, cBwd, false, iter))
  all-ops.push(("13", "dist [" + bH + "]",         4, off + 70, off + 82, cDat, false, iter))

  all-barriers.push(("8",  off + 50, 0, iter))
  all-barriers.push(("11", off + 63, 0, iter))

  // per-iteration idle: memcpy KK gap
  all-idles.push((1, off + 24, off + 38, "GPU idle (CPU: issue (6), then (5) KK)"))
}

// cross-iteration idles (auto: prefetch, datadist, default gaps)
#for iter in range(NUM-ITERS) {
  let off = iter * CYCLE
  if iter == 0 {
    all-idles.push((3, 6, 53, none))
    all-idles.push((4, 6, 70, none))
    all-idles.push((0, 0, 22, none))
  } else {
    let prev-off = (iter - 1) * CYCLE
    all-idles.push((3, prev-off + 62, off, none))       // prefetch gap
    all-idles.push((3, off + 6, off + 53, none))        // prefetch gap within iter
    all-idles.push((4, off, off + 70, none))            // datadist gap
    all-idles.push((0, prev-off + 82, off + 22, none))  // default gap between iters
    // memcpy gap between iters
    all-idles.push((1, prev-off + 50, off + 7, none))
  }
}

// ── Drawing ─────────────────────────────────────────
#cetz.canvas(length: 1cm, {
  import cetz.draw: *

  let rrect(x1, y1, w, h, r: 0.08, fill: white, stroke: black, dash: none) = {
    rect(
      (x1, y1), (x1 + w, y1 - h),
      radius: r, fill: fill,
      stroke: (paint: stroke, thickness: 0.7pt, dash: dash),
    )
  }

  // ── Title ──
  content(
    (label-w, 1.6),
    text(size: 13pt, weight: "bold")[progress() — 3-Iteration Pipeline Timeline],
    anchor: "west",
  )

  // ── Iteration regions ──
  for iter in range(NUM-ITERS) {
    let x0 = tx(iter * CYCLE)
    let x1 = tx((iter + 1) * CYCLE)
    let y0 = 0.15
    let y1 = ly(4) - lane-h - 0.1
    rect(
      (x0 - 0.1, y0), (x1 + 0.1, y1),
      radius: 0.1,
      fill: iter-bg.at(iter),
      stroke: (paint: iter-border.at(iter).lighten(70%), thickness: 0.4pt),
    )
    content(
      ((x0 + x1) / 2, 1.05),
      text(fill: iter-border.at(iter), weight: "bold", size: 9pt)[Iter #bn(iter)],
      anchor: "center",
    )
    if iter < NUM-ITERS - 1 {
      line(
        (x1, y0), (x1, y1),
        stroke: (paint: luma(190), thickness: 0.6pt, dash: "dashed"),
      )
    }
  }

  // ── Time arrow ──
  line(
    (label-w - 0.2, 0.5), (tx(MAX-T) + 1.0, 0.5),
    stroke: (paint: luma(180), thickness: 1pt),
    mark: (end: "stealth", fill: luma(180), size: 0.2),
  )
  content((tx(MAX-T) + 1.3, 0.5), text(fill: luma(150), weight: "bold", size: 8pt)[Time →], anchor: "west")

  // ── Lane backgrounds ──
  for (i, s) in streams.enumerate() {
    let y = ly(i)
    rect(
      (label-w - 0.2, y + 0.06), (tx(MAX-T) + 0.5, y - lane-h - 0.06),
      radius: 0.06,
      fill: s.color.lighten(96%),
      stroke: (paint: s.color.lighten(88%), thickness: 0.3pt),
    )
    content(
      (label-w - 0.35, lmy(i) - 0.08),
      text(fill: s.color, weight: "bold", size: 8.5pt)[#s.name],
      anchor: "east",
    )
    content(
      (label-w - 0.35, lmy(i) + 0.22),
      text(fill: luma(160), style: "italic", size: 6.5pt)[#{("[" + s.thread + "]")}],
      anchor: "east",
    )
  }

  // ── Idle segments ──
  for idle in all-idles {
    let y = lmy(idle.at(0))
    line(
      (tx(idle.at(1)), y), (tx(idle.at(2)), y),
      stroke: (paint: luma(200), thickness: 0.8pt, dash: "dotted"),
    )
    let lab = idle.at(3)
    if lab != none {
      content(
        (tx((idle.at(1) + idle.at(2)) / 2), y + 0.22),
        text(fill: luma(185), size: 5.5pt)[#lab],
        anchor: "center",
      )
    }
  }

  // ── Operation boxes ──
  let op-rects = (:)
  for op in all-ops {
    let (num, name, si, t0, t1, clr, done, iter) = op
    let x1 = tx(t0)
    let x2 = tx(t1)
    let w = x2 - x1
    let y = ly(si) - 0.12
    let h = lane-h - 0.24
    let mid-x = (x1 + x2) / 2
    let mid-y = y - h / 2

    let key = "i" + str(iter) + "_" + (if name.starts-with("KK") { "KK" } else { num })
    op-rects.insert(key, (
      x1: x1, x2: x2, y: y, h: h, mx: mid-x, my: mid-y, si: si,
    ))

    rrect(
      x1, y, w, h,
      fill: if done { clr.lighten(96%) } else { clr.lighten(93%) },
      stroke: clr.lighten(if done { 40% } else { 20% }),
      dash: if done { "dashed" } else { none },
    )

    if num != "" {
      let r = if num.len() > 1 { 0.26 } else { 0.22 }
      circle(
        (x1 + 0.3, y - 0.28),
        radius: r,
        fill: clr.lighten(10%),
        stroke: none,
      )
      content(
        (x1 + 0.3, y - 0.28),
        text(fill: white, weight: "bold", size: if num.len() > 1 { 7pt } else { 8.5pt })[#num],
        anchor: "center",
      )
    }

    content(
      (mid-x, mid-y + (if num != "" { 0.06 } else { 0 })),
      text(fill: clr, weight: "bold", size: if w < 3.0 { 5.5pt } else { 6.5pt })[#name],
      anchor: "center",
    )
  }

  // ── Barriers ──
  let bar-rects = (:)
  for b in all-barriers {
    let (label, bx, si, iter) = b
    let x = tx(bx)
    let y-top = ly(si) - 0.06
    let y-bot = ly(si) - lane-h + 0.06

    let key = "i" + str(iter) + "_" + label
    bar-rects.insert(key, (x: x, yt: y-top, yb: y-bot, si: si))

    line(
      (x, y-top), (x, y-bot),
      stroke: (paint: cSync, thickness: 2pt, cap: "round"),
    )
    content(
      (x, y-top + 0.3),
      text(fill: cSync, weight: "bold", size: 7.5pt)[#label],
      anchor: "center",
    )
  }

  // ── Sync arrows helper ──
  let draw-sync(x1, y1, x2, y2, label, clr, is-cross: false) = {
    let dx = x2 - x1
    let dy = y2 - y1
    let (c1x, c1y, c2x, c2y) = if is-cross { (0.15, 0.1, 0.85, 0.9) } else { (0.3, 0.15, 0.7, 0.85) }
    bezier(
      (x1, y1),
      (x2, y2),
      (x1 + dx * c1x, y1 + dy * c1y),
      (x1 + dx * c2x, y1 + dy * c2y),
      stroke: (paint: clr, thickness: if is-cross { 1.0pt } else { 0.8pt }, dash: if is-cross { (4pt, 3pt) } else { "dashed" }),
      mark: (end: "stealth", fill: clr, size: 0.15),
    )
    let lx = x1 + dx * 0.5
    let ly2 = y1 + dy * 0.5
    rect(
      (lx - label.len() * 0.08, ly2 + 0.2),
      (lx + label.len() * 0.08, ly2 + 0.02),
      fill: white.transparentize(15%),
      stroke: none,
    )
    content(
      (lx, ly2 + 0.12),
      text(fill: clr, size: 5pt, weight: "medium")[#label],
      anchor: "center",
    )
  }

  // ── Per-iteration sync arrows ──
  for iter in range(NUM-ITERS) {
    let pfx = "i" + str(iter) + "_"

    // (1) done → forward  (intra-iteration)
    let r1 = op-rects.at(pfx + "1")
    let r6 = op-rects.at(pfx + "6")
    draw-sync(r1.mx, r1.y + 0.02, r6.x1 + 0.3, r6.y - r6.h - 0.02, "GPU wait: pf", cPre)

    // (3) done → H2D  (intra-iteration)
    let r3 = op-rects.at(pfx + "3")
    let r2 = op-rects.at(pfx + "2")
    draw-sync(r3.mx, r3.y + 0.02, r2.x1 - 0.1, r2.y - r2.h - 0.02, "CPU block: dist", cDat)

    // (4) → KK(5)
    let r4 = op-rects.at(pfx + "4")
    let rk = op-rects.at(pfx + "KK")
    draw-sync(r4.mx, r4.y - r4.h - 0.02, rk.x1 + 0.3, rk.y + 0.02, "submit KK", cMem)

    // KK(5) → (7)
    let r7 = op-rects.at(pfx + "7")
    draw-sync(rk.x2 - 0.3, rk.y + 0.02, r7.mx, r7.y - r7.h - 0.02, "Future.result()", cCpu)

    // (7) → barrier 8
    let b8 = bar-rects.at(pfx + "8")
    draw-sync(r7.x2 - 0.3, r7.y + 0.02, b8.x, b8.yb, "(8) wait(_memcpy)", cSync)

    // (10) → barrier 11
    let r10 = op-rects.at(pfx + "10")
    let b11 = bar-rects.at(pfx + "11")
    draw-sync(r10.x2 - 0.3, r10.y + 0.02, b11.x, b11.yb, "(11) wait(_pf)", cSync)

    // (7) → (13)
    let r13 = op-rects.at(pfx + "13")
    draw-sync(r7.x2 - 0.2, r7.y - r7.h - 0.02, r13.x1 + 0.3, r13.y + 0.02, "dist.wait(_memcpy)", cDat)
  }

  // ── Cross-iteration arrows ──
  for iter in range(NUM-ITERS - 1) {
    let pfx = "i" + str(iter) + "_"
    let npfx = "i" + str(iter + 1) + "_"

    // (10) prefetch → next iter's (1) done block  (same stream: _prefetch_stream)
    let src-pf = op-rects.at(pfx + "10")
    let dst-pf = op-rects.at(npfx + "1")
    draw-sync(
      src-pf.x2 - 0.1, src-pf.y - 0.02,
      dst-pf.x1 + 0.1, dst-pf.y - 0.02,
      "(10)→(1) pf [" + bn(iter + 1) + "]", cPre,
      is-cross: true,
    )

    // (13) input_dist → next iter's (3) done block  (same stream: _data_dist_stream)
    let src-dd = op-rects.at(pfx + "13")
    let dst-dd = op-rects.at(npfx + "3")
    draw-sync(
      src-dd.x2 - 0.1, src-dd.y - 0.02,
      dst-dd.x1 + 0.1, dst-dd.y - 0.02,
      "(13)→(3) dist [" + bn(iter + 2) + "]", cDat,
      is-cross: true,
    )
  }

  // ── Batch lifecycle chains (red connecting lines) ──
  let cBatch = rgb("#E8363B")
  let batch-yoff = 0.15

  let draw-batch-link(x1, y1, x2, y2, same-stream: false) = {
    let c = red
    if same-stream {
      line(
        (x1, y1), (x2, y2),
        stroke: (paint: c, thickness: 1.2pt),
        mark: (end: "stealth", fill: c, size: 0.12),
      )
    } else {
      let dx = x2 - x1
      let dy = y2 - y1
      bezier(
        (x1, y1), (x2, y2),
        (x1 + dx * 0.25, y1 + dy * 0.05),
        (x1 + dx * 0.75, y1 + dy * 0.95),
        stroke: (paint: c, thickness: 1.2pt),
        mark: (end: "stealth", fill: c, size: 0.12),
      )
    }
  }

  // Build set of already-linked pairs (from sync arrows)
  let linked = (:)
  for iter in range(NUM-ITERS) {
    let p = "i" + str(iter) + "_"
    // s1: prev_pf → fwd;  s3: prev_dd → h2d (different batch, but still linked)
    linked.insert(p + "1|" + p + "6", true)
    // s4: ag_wkld → kk;  sf: kk → finish;  s11: finish → inp_dist
    linked.insert(p + "4|" + p + "KK", true)
    linked.insert(p + "KK|" + p + "7", true)
    linked.insert(p + "7|" + p + "13", true)
  }
  for iter in range(NUM-ITERS - 1) {
    let p = "i" + str(iter) + "_"
    let np = "i" + str(iter + 1) + "_"
    // cross-iter: pf → next prev_pf;  inp_dist → next prev_dd
    linked.insert(p + "10|" + np + "1", true)
    linked.insert(p + "13|" + np + "3", true)
  }

  for b in range(NUM-ITERS + 2) {
    let chain = ()
    let i1 = b - 2
    let i2 = b - 1
    let i3 = b
    if i1 >= 0 and i1 < NUM-ITERS {
      let p = "i" + str(i1) + "_"
      chain.push(p + "2")
      chain.push(p + "4")
      chain.push(p + "KK")
      chain.push(p + "7")
      chain.push(p + "13")
    }
    if i2 >= 0 and i2 < NUM-ITERS {
      let p = "i" + str(i2) + "_"
      chain.push(p + "3")
      chain.push(p + "10")
    }
    if i3 >= 0 and i3 < NUM-ITERS {
      let p = "i" + str(i3) + "_"
      chain.push(p + "1")
      chain.push(p + "6")
      chain.push(p + "9")
      chain.push(p + "12")
    }

    for j in range(chain.len() - 1) {
      let key = chain.at(j) + "|" + chain.at(j + 1)
      if key in linked { continue }
      let from = op-rects.at(chain.at(j))
      let to = op-rects.at(chain.at(j + 1))
      let fx = from.x2
      let fy = from.y - from.h / 2
      let tx2 = to.x1
      let ty = to.y - to.h / 2
      draw-batch-link(fx, fy, tx2, ty, same-stream: from.si == to.si)
    }

    if chain.len() > 0 {
      let first = op-rects.at(chain.at(0))
      content(
        (first.x1 - 0.05, first.y - first.h / 2),
        text(fill: red, weight: "bold", size: 5.5pt)[batch\[#bn(b)\]],
        anchor: "east",
      )
    }
  }

  // ── Legend ──
  let lg-y = ly(4) - lane-h - 1.0
  content((label-w, lg-y + 0.1), text(weight: "bold", size: 7.5pt)[Legend:], anchor: "west")

  line(
    (label-w + 1.2, lg-y - 0.15), (label-w + 2.5, lg-y - 0.15),
    stroke: (paint: cSync, thickness: 0.8pt, dash: "dashed"),
    mark: (end: "stealth", fill: cSync, size: 0.12),
  )
  content((label-w + 2.7, lg-y - 0.15), text(size: 6.5pt)[GPU wait\_stream], anchor: "west")

  line(
    (label-w + 5.8, lg-y - 0.15), (label-w + 7.1, lg-y - 0.15),
    stroke: (paint: cCpu, thickness: 0.8pt, dash: "dashed"),
    mark: (end: "stealth", fill: cCpu, size: 0.12),
  )
  content((label-w + 7.3, lg-y - 0.15), text(size: 6.5pt)[CPU sync / Future], anchor: "west")

  line(
    (label-w + 10.3, lg-y - 0.0), (label-w + 10.3, lg-y - 0.3),
    stroke: (paint: cSync, thickness: 2pt, cap: "round"),
  )
  content((label-w + 10.6, lg-y - 0.15), text(size: 6.5pt)[wait\_stream barrier], anchor: "west")

  line(
    (label-w + 14.2, lg-y - 0.15), (label-w + 15.4, lg-y - 0.15),
    stroke: (paint: luma(200), thickness: 0.8pt, dash: "dotted"),
  )
  content((label-w + 15.6, lg-y - 0.15), text(size: 6.5pt)[stream idle], anchor: "west")

  line(
    (label-w + 18.0, lg-y - 0.15), (label-w + 19.3, lg-y - 0.15),
    stroke: (paint: cPre, thickness: 1.0pt, dash: (4pt, 3pt)),
    mark: (end: "stealth", fill: cPre, size: 0.12),
  )
  content((label-w + 19.5, lg-y - 0.15), text(size: 6.5pt)[cross-iteration dependency], anchor: "west")

  line(
    (label-w + 24.5, lg-y - 0.15), (label-w + 25.8, lg-y - 0.15),
    stroke: (paint: red, thickness: 1.2pt),
    mark: (end: "stealth", fill: red, size: 0.12),
  )
  content((label-w + 26.0, lg-y - 0.15), text(size: 6.5pt)[same batch flow (red)], anchor: "west")

  // ── Annotation (with background block) ──
  let ann-y = lg-y - 0.7
  let ann-right = tx(MAX-T) + 0.5
  let ann-bottom = ann-y - 4.6

  // background color block
  rect(
    (label-w - 0.2, ann-y + 0.4), (ann-right, ann-bottom),
    radius: 0.12,
    fill: rgb("#f0f2f8"),
    stroke: (paint: rgb("#d0d4e0"), thickness: 0.5pt),
  )

  // title: CPU code sequence
  content((label-w + 0.1, ann-y + 0.05), text(weight: "bold", size: 9pt)[序号含义：CPU 主线程代码执行顺序（progress() 函数内）], anchor: "west")
  content(
    (label-w + 0.3, ann-y - 0.4),
    text(size: 8pt)[
      CPU code sequence per iteration: 1 → 2 → 3 → 4 → 5(bg) → 6 → 7 → 8 → 9 → 10 → 11 → 12 → 13
    ],
    anchor: "north-west",
  )

  // title: batch lifecycle
  let bl-y = ann-y - 1.1
  content((label-w + 0.1, bl-y), text(weight: "bold", size: 9pt, fill: cSync)[每个 batch 的完整生命周期（跨 3 次迭代）：], anchor: "west")

  // line 1: Iter N
  content(
    (label-w + 0.5, bl-y - 0.45),
    text(size: 8pt, weight: "bold", fill: cSync)[
      Iter N #h(0.15cm) (as batch\[N+2\]) : #h(0.15cm) 2 → 4 → 5 → 7 → 13
    ],
    anchor: "north-west",
  )

  // line 2: Iter N+1  (new line at 13 → 3)
  content(
    (label-w + 0.5, bl-y - 1.05),
    text(size: 8pt, weight: "bold", fill: cSync)[
      Iter N+1 (as batch\[N+1\]) : #h(0.15cm) 3 → 10
    ],
    anchor: "north-west",
  )

  // line 3: Iter N+2  (new line at 10 → 1)
  content(
    (label-w + 0.5, bl-y - 1.65),
    text(size: 8pt, weight: "bold", fill: cSync)[
      Iter N+2 (as batch\[N\]) : #h(0.15cm) 1 → 6 → 8 → 9 → 11 → 12
    ],
    anchor: "north-west",
  )

  // cross-iteration hint
  content(
    (label-w + 0.5, bl-y - 2.35),
    text(size: 7pt, fill: luma(130))[
      ↑ 迭代之间通过 13→3 和 10→1 衔接
    ],
    anchor: "north-west",
  )
})
