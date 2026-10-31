// ============================================================================
//                    ╔═════════════════════════════════════════════════════╗
//                    ║     PROFESSIONAL LAB TEMPLATE FOR TYPST            ║
//                    ║     Version: 1.5 (Final Alignment & Ender)         ║
//                    ╚═════════════════════════════════════════════════════╝
// ============================================================================

#let student_name = "CHAITANYA SHINDE"
#let student_id = "Final Year BTECH CE 231070066"
#let assignment_type = "CPAD ESE Mini Project"
#let assignment_num = ""

// Original Accent Colors
#let accent-tan = rgb(212, 184, 150)
#let accent-tan-dark = rgb(180, 140, 100)
#let black-clean = rgb("#000000")
#let text-main = rgb("#1A1A1A")
#let text-muted = rgb("#4A4A4A")

#let note-bg = rgb(240, 250, 240)
#let note-frame = rgb(60, 120, 60)
#let warn-bg = rgb(255, 248, 240)
#let warn-frame = rgb(180, 90, 30)
#let info-bg = rgb(240, 248, 255)
#let info-frame = rgb(50, 90, 150)
#let viva-bg = rgb(250, 245, 255)
#let viva-frame = rgb(90, 60, 150)
#let key-bg = rgb(255, 253, 245)
#let key-frame = rgb(180, 150, 100)
#let code-bg = rgb(250, 250, 250)
#let code-frame = rgb(220, 220, 220)

// Primary serif font stack
#let serif-stack = ("Liberation Serif", "DejaVu Serif", "Noto Serif")

#let setup(body) = {
  set page(
    paper: "a4",
    margin: (top: 1.1in, bottom: 1.1in, x: 1in),
    header: {
      set align(left)
      block(width: 100%)[
        #text(weight: "bold", size: 11.5pt, fill: black-clean, font: serif-stack)[
          #student_name #h(0.5em) #student_id
        ]
        #v(2pt)
        #line(length: 100%, stroke: (paint: accent-tan, thickness: 0.8pt))
      ]
    },
    footer: context {
      set align(center)
      stack(
        spacing: 5pt,
        line(length: 85%, stroke: (paint: accent-tan, thickness: 1.2pt)),
        line(length: 25%, stroke: (paint: accent-tan, thickness: 1.2pt)),
        v(3pt),
        text(size: 9pt, fill: text-muted, weight: "regular", font: serif-stack)[
          #counter(page).display()
        ]
      )
    },
  )
  
  set text(size: 11pt, font: serif-stack, fill: text-main)
  set par(justify: true, leading: 0.65em)
  
  body
}

// ============================================================================
//                        HELPER FUNCTIONS
// ============================================================================

#let section_heading(title) = {
  v(1.5em, weak: true)
  block(width: 100%, sticky: true)[
    #text(weight: "bold", size: 16pt, fill: black-clean)[#title]
    #v(-0.5em)
    #line(length: 100%, stroke: (paint: rgb("#EEEEEE"), thickness: 1pt))
    #v(-1.1em)
    #line(length: 15%, stroke: (paint: accent-tan, thickness: 2.5pt))
  ]
  v(0.8em)
}

#let topic_subheading(title) = {
  v(0.6em)
  block(sticky: true, text(weight: "bold", size: 12.5pt, fill: rgb("#333333"))[#title])
  v(0.2em)
}

#let case_heading(num, title) = {
  v(0.6em)
  block(
    fill: key-bg,
    stroke: (paint: key-frame, thickness: 0.5pt),
    radius: 2pt,
    width: 100%,
    inset: 10pt,
  )[
    #text(weight: "bold", size: 11pt)[Case #num: #title]
  ]
  v(0.4em)
}

#let note_box(body, title: "Note") = {
  block(fill: note-bg, stroke: note-frame, radius: 3pt, width: 100%, inset: 10pt, breakable: true)[
    #text(weight: "bold", fill: note-frame, size: 10.5pt)[#title]\ #v(0.3em) #body
  ]
}

#let warn_box(body, title: "Observation") = {
  block(fill: warn-bg, stroke: warn-frame, radius: 3pt, width: 100%, inset: 10pt, breakable: true)[
    #text(weight: "bold", fill: warn-frame, size: 10.5pt)[#title]\ #v(0.3em) #body
  ]
}

#let info_box(body, title: "Analysis") = {
  block(fill: info-bg, stroke: info-frame, radius: 3pt, width: 100%, inset: 10pt, breakable: true)[
    #text(weight: "bold", fill: info-frame, size: 10.5pt)[#title]\ #v(0.3em) #body
  ]
}

#let viva_box(body, title: "Useful Trivia") = {
  block(fill: viva-bg, stroke: viva-frame, radius: 3pt, width: 100%, inset: 10pt, breakable: false)[
    #text(weight: "bold", fill: viva-frame, size: 10.5pt)[#title]\ #v(0.3em) #body
  ]
}

#let key_box(body, title: "Key Principle") = {
  block(fill: key-bg, stroke: key-frame, radius: 3pt, width: 100%, inset: 10pt, breakable: true)[
    #text(weight: "bold", fill: rgb("#444444"), size: 10.5pt)[#title]\ #v(0.3em) #body
  ]
}

#let cmd(command_text) = {
  v(0.2em)
  block(fill: code-bg, stroke: code-frame, radius: 2pt, width: 100%, inset: 8pt)[
    #text(size: 9.5pt, font: "DejaVu Sans Mono")[#command_text]
  ]
  v(0.2em)
}

#let code_block(code, lang: none) = {
  v(0.4em)
  block(width: 100%, fill: code-bg, inset: 10pt, radius: 3pt, stroke: code-frame, breakable: true)[
    #raw(code, lang: lang, block: true)
  ]
  v(0.4em)
}

#let figure_inline(filename, width: 90%, caption: none) = {
  v(1em)
  align(center)[
    #block(stroke: (paint: rgb("#DDDDDD"), thickness: 0.5pt), radius: 1pt, inset: 1pt)[
      #image(filename, width: width)
    ]
    #if caption != none { v(0.5em); text(size: 9.5pt, style: "italic", fill: text-muted)[#caption] }
  ]
  v(1em)
}

#let make_title() = {
  align(center)[
    #v(1.5cm)
    #line(length: 35%, stroke: (paint: accent-tan, thickness: 2.5pt))
    #v(1cm)
    #text(weight: "bold", size: 26pt, fill: black-clean)[
      #assignment_type
    ]
    #v(0.6cm)
    #line(length: 45%, stroke: (paint: accent-tan, thickness: 1.2pt))
    #v(1.5cm)
  ]
}

#let make_ender() = {
  v(1.5cm)
  align(center)[
    #line(length: 40%, stroke: (paint: accent-tan, thickness: 1.5pt))
    #v(0.4cm)
    #text(weight: "bold", size: 14pt, fill: black-clean)[
      END OF REPORT
    ]
    #v(0.3cm)
    #text(fill: text-muted, size: 10.5pt)[
      #student_name #h(0.6em) | #h(0.6em) #student_id
    ]
    #v(0.5cm)
    #line(length: 40%, stroke: (paint: accent-tan, thickness: 1.5pt))
  ]
}
