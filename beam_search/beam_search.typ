#import "@preview/cetz:0.3.4"

#set page(width: auto, height: auto, margin: (top: 1cm, bottom: 1.2cm, left: 2.5cm, right: 1cm))
#set text(font: ("Helvetica Neue", "Arial"), size: 10pt)

#let ts = 0.5
#let cl = 5
#let gap = 0.9
#let xB = 11

#let connections = (
  (0, 1),
  (0, 0),
  (0, 1),
  (0, 0),
)

#let row-y(step) = -step * (ts + gap)

#let trace-beam(step, beam) = {
  let result = ()
  let idx = beam
  let k = step
  while k > 1 {
    let tgt = connections.at(k - 2).at(idx)
    result.push((k, idx, tgt))
    idx = tgt
    k -= 1
  }
  result
}

#let beam-histories = {
  let result = ()
  let h = (((1, 0),), ((1, 1),))
  result.push(h)
  for i in range(4) {
    let conn = connections.at(i)
    let prev = result.at(i)
    let new-h = (
      prev.at(conn.at(0)) + ((i + 2, 0),),
      prev.at(conn.at(1)) + ((i + 2, 1),),
    )
    result.push(new-h)
  }
  result
}

#align(center)[
  #text(15pt, weight: "bold")[Beam Search Visualization]
  #h(0.3em)
  #text(10pt, fill: rgb("#999"))[(beam width = 2)]
]
#v(0.5cm)

#cetz.canvas(length: 1cm, {
  import cetz.draw: *

  let ofill = rgb("#FFE0B2")
  let ostk  = rgb("#FF8C00")
  let cfill = rgb("#E8E8E8")
  let acol  = (rgb("#E74C3C"), rgb("#3498DB"))
  let bfill = (rgb("#FADBD8"), rgb("#D4E6F1"))

  let draw-context(x, y) = {
    rect((x, y), (x + cl * ts, y - ts), fill: cfill, stroke: 0.5pt + black)
    for i in range(1, cl) {
      line((x + i * ts, y), (x + i * ts, y - ts), stroke: (paint: rgb("#D0D0D0"), thickness: 0.3pt))
    }
  }

  let draw-confirmed(x, y) = {
    rect((x, y), (x + ts, y - ts), fill: white, stroke: 0.5pt + black)
  }

  let draw-candidate(x, y, label) = {
    rect(
      (x, y), (x + ts, y - ts),
      fill: ofill,
      stroke: (paint: ostk, dash: "dashed", thickness: 1pt),
    )
    content((x + ts / 2, y - ts / 2), text(size: 4.5pt, weight: "bold", fill: ostk)[#label])
  }

  let draw-beam-token(x, y, label, fc, shared: false) = {
    rect((x, y), (x + ts, y - ts), fill: fc, stroke: 0.5pt + black)
    if shared {
      content((x + ts / 2, y - ts / 2), text(size: 4.5pt, weight: "bold", fill: rgb("#333"))[#label])
    } else {
      content((x + ts / 2, y - ts / 2), text(size: 4.5pt, fill: rgb("#555"))[#label])
    }
  }

  let draw-label(x0, y, label) = {
    content((x0 - 0.3, y), anchor: "east", text(size: 7pt, fill: rgb("#666"))[#label])
  }

  let draw-divider(x, y) = {
    line((x, y + 0.06), (x, y - ts - 0.06), stroke: 1.8pt + black)
  }

  let draw-arrow(src-cx, tgt-cx, y, color, src-j) = {
    let dx = src-cx - tgt-cx
    let arch = 0.18 + dx * 0.13 + src-j * 0.1
    bezier(
      (src-cx, y),
      (tgt-cx, y),
      (src-cx, y + arch),
      (tgt-cx, y + arch),
      stroke: 0.5pt + color,
      mark: (end: ">", fill: color, size: 0.06),
    )
  }

  let tok-label(gen-step, tok-idx) = {
    "s" + str(gen-step - 1) + "t" + str(tok-idx)
  }

  // === Column subtitles ===
  content((3.75, 0.7), text(size: 10pt, weight: "bold")[Method A: Incremental Append])
  content((xB + 3.75, 0.7), text(size: 10pt, weight: "bold")[Method B: Beam-Grouped])

  // ================================================================
  //  METHOD A  (x-origin = 0)
  // ================================================================

  let y0 = row-y(0)
  draw-context(0, y0)
  content((cl * ts / 2, y0 - ts / 2), text(size: 7pt, fill: rgb("#AAA"))[context])
  draw-label(0, y0 - ts / 2, [Initial Context])

  let y1 = row-y(1)
  draw-context(0, y1)
  draw-candidate(cl * ts, y1, "s0t0")
  draw-candidate((cl + 1) * ts, y1, "s0t1")
  draw-divider((cl + 2) * ts, y1)
  draw-label(0, y1 - ts / 2, [Decode Step 1])

  for step in range(2, 6) {
    let y = row-y(step)
    let nc = 2 * (step - 1)

    draw-context(0, y)
    for i in range(nc) { draw-confirmed(cl * ts + i * ts, y) }

    let cand-base = (cl + nc) * ts
    for j in range(2) {
      draw-candidate(cand-base + j * ts, y, tok-label(step, j))
    }

    for k in range(1, step + 1) { draw-divider((cl + 2 * k) * ts, y) }

    let chain0 = trace-beam(step, 0)
    let chain1 = trace-beam(step, 1)

    for arrow in chain0 {
      let src-cx = (cl + 2 * (arrow.at(0) - 1) + arrow.at(1)) * ts + ts / 2
      let tgt-cx = (cl + 2 * (arrow.at(0) - 2) + arrow.at(2)) * ts + ts / 2
      let color = if chain1.contains(arrow) { black } else { acol.at(0) }
      draw-arrow(src-cx, tgt-cx, y, color, arrow.at(1))
    }
    for arrow in chain1 {
      if not chain0.contains(arrow) {
        let src-cx = (cl + 2 * (arrow.at(0) - 1) + arrow.at(1)) * ts + ts / 2
        let tgt-cx = (cl + 2 * (arrow.at(0) - 2) + arrow.at(2)) * ts + ts / 2
        draw-arrow(src-cx, tgt-cx, y, acol.at(1), arrow.at(1))
      }
    }

    draw-label(0, y - ts / 2, [Decode Step #{step}])
  }

  // ================================================================
  //  METHOD B  (x-origin = xB)
  // ================================================================

  draw-context(xB, y0)
  content((xB + cl * ts / 2, y0 - ts / 2), text(size: 7pt, fill: rgb("#AAA"))[context])
  draw-label(xB, y0 - ts / 2, [Initial Context])

  draw-context(xB, y1)
  draw-candidate(xB + cl * ts, y1, "s0t0")
  draw-candidate(xB + (cl + 1) * ts, y1, "s0t1")
  draw-divider(xB + (cl + 2) * ts, y1)
  draw-label(xB, y1 - ts / 2, [Decode Step 1])

  for step in range(2, 6) {
    let y = row-y(step)
    let hist = beam-histories.at(step - 1)

    draw-context(xB, y)

    let bx = xB + cl * ts
    for beam in range(2) {
      let tokens = hist.at(beam)
      let beam-start = if beam == 0 { bx } else { bx + hist.at(0).len() * ts }

      let other = hist.at(1 - beam)
      for i in range(tokens.len()) {
        let tok = tokens.at(i)
        let label = tok-label(tok.at(0), tok.at(1))
        let x = beam-start + i * ts
        let is-shared = i < other.len() and other.at(i) == tok
        if i == tokens.len() - 1 {
          draw-candidate(x, y, label)
        } else {
          draw-beam-token(x, y, label, bfill.at(beam), shared: is-shared)
        }
      }
      draw-divider(beam-start + tokens.len() * ts, y)
    }

    draw-label(xB, y - ts / 2, [Decode Step #{step}])
  }
})

#v(0.3cm)
#align(center)[
  #set text(size: 7pt, fill: rgb("#888"))
  #box(width: 7pt, height: 7pt, fill: rgb("#E8E8E8"), stroke: 0.5pt + black, baseline: 20%)
  Context
  #h(0.6em)
  #box(width: 7pt, height: 7pt, fill: white, stroke: 0.5pt + black, baseline: 20%)
  Confirmed
  #h(0.6em)
  #box(width: 7pt, height: 7pt, fill: rgb("#FFE0B2"), stroke: (paint: rgb("#FF8C00"), dash: "dashed", thickness: 0.6pt), baseline: 20%)
  Candidate
  #h(0.6em)
  #box(width: 7pt, height: 7pt, fill: rgb("#FADBD8"), stroke: 0.5pt + black, baseline: 20%)
  Beam 0
  #h(0.6em)
  #box(width: 7pt, height: 7pt, fill: rgb("#D4E6F1"), stroke: 0.5pt + black, baseline: 20%)
  Beam 1
  #h(0.6em)
  #text(fill: rgb("#E74C3C"))[→]/#text(fill: rgb("#3498DB"))[→]/#text(fill: black)[→]
  Beam 0 / Beam 1 / Shared
]
