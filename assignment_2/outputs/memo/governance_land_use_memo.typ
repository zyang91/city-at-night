// Simple numbering for non-book documents
#let equation-numbering = "(1)"
#let callout-numbering = "1"
#let subfloat-numbering(n-super, subfloat-idx) = {
  numbering("1a", n-super, subfloat-idx)
}

// Theorem configuration for theorion
// Simple numbering for non-book documents (no heading inheritance)
#let theorem-inherited-levels = 0

// Theorem numbering format (can be overridden by extensions for appendix support)
// This function returns the numbering pattern to use
#let theorem-numbering(loc) = "1.1"

// Default theorem render function
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  if full-title != "" and full-title != auto and full-title != none {
    strong[#full-title.]
    h(0.5em)
  }
  body
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}


// syntax highlighting functions from skylighting:
/* Function definitions for syntax highlighting generated by skylighting: */
#let EndLine() = raw("\n")
#let Skylighting(fill: none, number: false, start: 1, sourcelines) = {
   let blocks = []
   let lnum = start - 1
   let bgcolor = rgb("#f1f3f5")
   for ln in sourcelines {
     if number {
       lnum = lnum + 1
       blocks = blocks + box(width: if start + sourcelines.len() > 999 { 30pt } else { 24pt }, text(fill: rgb("#aaaaaa"), [ #lnum ]))
     }
     blocks = blocks + ln + EndLine()
   }
   block(fill: bgcolor, width: 100%, inset: 8pt, radius: 2pt, blocks)
}
#let AlertTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let AnnotationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let AttributeTok(s) = text(fill: rgb("#657422"),raw(s))
#let BaseNTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let BuiltInTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let CharTok(s) = text(fill: rgb("#20794d"),raw(s))
#let CommentTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let CommentVarTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ConstantTok(s) = text(fill: rgb("#8f5902"),raw(s))
#let ControlFlowTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let DataTypeTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DecValTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DocumentationTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ErrorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let ExtensionTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let FloatTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let FunctionTok(s) = text(fill: rgb("#4758ab"),raw(s))
#let ImportTok(s) = text(fill: rgb("#00769e"),raw(s))
#let InformationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let KeywordTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let NormalTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let OperatorTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let OtherTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let PreprocessorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let RegionMarkerTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let SpecialCharTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let SpecialStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let StringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let VariableTok(s) = text(fill: rgb("#111111"),raw(s))
#let VerbatimStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let WarningTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))



#let article(
  title: none,
  subtitle: none,
  authors: none,
  keywords: (),
  date: none,
  abstract-title: none,
  abstract: none,
  thanks: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: none,
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: none,
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  mathfont: none,
  codefont: none,
  linestretch: 1,
  sectionnumbering: none,
  linkcolor: none,
  citecolor: none,
  filecolor: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  // Set document metadata for PDF accessibility
  set document(title: title, keywords: keywords)
  set document(
    author: authors.map(author => content-to-string(author.name)).join(", ", last: " & "),
  ) if authors != none and authors != ()
  set par(
    justify: true,
    leading: linestretch * 0.65em
  )
  set text(lang: lang,
           region: region,
           size: fontsize)
  set text(font: font) if font != none
  show math.equation: set text(font: mathfont) if mathfont != none
  show raw: set text(font: codefont) if codefont != none

  set heading(numbering: sectionnumbering)

  show link: set text(fill: rgb(content-to-string(linkcolor))) if linkcolor != none
  show ref: set text(fill: rgb(content-to-string(citecolor))) if citecolor != none
  show link: this => {
    if filecolor != none and type(this.dest) == label {
      text(this, fill: rgb(content-to-string(filecolor)))
    } else {
      text(this)
    }
   }

  let has-title-block = title != none or (authors != none and authors != ()) or date != none or abstract != none
  if has-title-block {
    place(
      top,
      float: true,
      scope: "parent",
      clearance: 4mm,
      block(below: 1em, width: 100%)[

        #if title != none {
          align(center, block(inset: 2em)[
            #set par(leading: heading-line-height) if heading-line-height != none
            #set text(font: heading-family) if heading-family != none
            #set text(weight: heading-weight)
            #set text(style: heading-style) if heading-style != "normal"
            #set text(fill: heading-color) if heading-color != black

            #text(size: title-size)[#title #if thanks != none {
              footnote(thanks, numbering: "*")
              counter(footnote).update(n => n - 1)
            }]
            #(if subtitle != none {
              parbreak()
              text(size: subtitle-size)[#subtitle]
            })
          ])
        }

        #if authors != none and authors != () {
          let count = authors.len()
          let ncols = calc.min(count, 3)
          grid(
            columns: (1fr,) * ncols,
            row-gutter: 1.5em,
            ..authors.map(author =>
                align(center)[
                  #author.name \
                  #author.affiliation \
                  #author.email
                ]
            )
          )
        }

        #if date != none {
          align(center)[#block(inset: 1em)[
            #date
          ]]
        }

        #if abstract != none {
          block(inset: 2em)[
          #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
          ]
        }
      ]
    )
  }

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  doc
}

#set table(
  inset: 6pt,
  stroke: none
)
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "us-letter",
  margin: (x: 0.55in,y: 0.5in,),
  numbering: "1",
  columns: 1,
)

#show: doc => article(
  font: ("Helvetica Neue",),
  fontsize: 9pt,
  toc_title: [Table of contents],
  toc_depth: 3,
  doc,
)

#set par(justify: false, leading: 0.55em)
#show heading: set block(above: 0.9em, below: 0.45em)
#show heading.where(level: 1): set text(size: 14pt)
#show heading.where(level: 2): set text(size: 10.5pt)
#set table(inset: (x: 4pt, y: 3pt))
#show table: set text(size: 8.5pt)
#show list: set block(spacing: 0.6em)
= Governance and Land Use: Nighttime Activities in Rittenhouse Square
<governance-and-land-use-nighttime-activities-in-rittenhouse-square>
#emph[CPLN 6890 The City at Night · Governance & Land Use Brief, Phase 2 (final) · October 2026]

#strong[Question.] Do licensed nighttime establishments in the study area operate in districts where their uses are permitted #emph[by right]? "Not permitted by right" is #strong[not] a finding of illegality: a use may be lawful through a special exception, a variance, or lawful nonconforming status.

== 1. Governance structure
<governance-structure>
#table(
  columns: (30.77%, 69.23%),
  align: (auto,auto,),
  table.header([Governance], [Jurisdiction],),
  table.hline(),
  [City Council], [Districts 5 (73%) and 2 (27%)],
  [Police], [9th District],
  [RCO], [Center City Residents' Association (CCRA); Center City Organized for Responsible Development],
  [BID / SSD], [Center City District (69%)],
  [Commercial corridor], [Market West (Central)],
)
Council regulates zoning, Police handles enforcement, RCOs take part in zoning review, and the Center City District provides district services.

== 2. Zoning geography
<zoning-geography>
#box(image("../figures/zoning_licensed_businesses.png", width: 96.0%))

#grid(
columns: (1fr, 1fr), gutter: 1em, rows: 1,
  rect(stroke: none, width: 100%)[
- #strong[Commercial mixed-use districts] cover #strong[50%] of zoned land. The most intensive commercial zoning sits on the blocks north and east of the Square (Chestnut, Walnut, Sansom, 18th).
- #strong[Residential districts] cover #strong[29%], mainly west of the Square and south of Spruce.
- #strong[The park] (Rittenhouse Square) covers #strong[21%].

],
  rect(stroke: none, width: 100%)[
- #strong[The Chestnut and Walnut Street overlay] adds a requirement on top of the base district. On lots fronting these streets, which make up 65% of commercially zoned land here, restaurants and bars need a special exception even where the base district allows them.
- Other overlays in the area contain no nighttime-use rules.

],
)
#pagebreak()
== 3. Nighttime use permission matrix
<nighttime-use-permission-matrix>
#box(image("../figures/permission_matrix.png", width: 66.0%))

#grid(
columns: (1fr, 1fr), gutter: 1em, rows: 1,
  rect(stroke: none, width: 100%)[
- #strong[Restaurants] (prepared food shop, take-out, sit-down) are by right in every CMX district and RMX-3, except take-out in CMX-2 (special exception); they are prohibited in RM-1 and RM-4.
- #strong[Nightclubs / public entertainment] (≥50 people gathering primarily for entertainment, §14-601(7)(c)(.2)) and other assembly uses are by right only in #strong[CMX-4/5], special exception in CMX-2/3, prohibited elsewhere.

],
  rect(stroke: none, width: 100%)[
- #strong["Bar" is not a zoning use.] Drinking places are Eating & Drinking Establishments unless they meet the nightclub definition; a liquor licence does not decide the zoning use.
- #strong[Hotels] (Visitor Accommodations) are by right in CMX-3/4/5 and RMX-3, but not in CMX-2, RM-1 or RM-4.

],
)
== 4. Existing establishments vs.~by-right zoning
<existing-establishments-vs.-by-right-zoning>
#strong[Data and method.] 124 current licence records (City business licences and PLCB liquor licences) correspond to #strong[63 identifiable establishments]. Each establishment was placed in its zoning district and overlay, its likely zoning use was assigned from licence evidence, and that use was checked against the Code. Cases where the use or the lot could not be pinned down are marked undetermined.

#grid(
columns: (42fr, 58fr), gutter: 1em, rows: 1,
  rect(stroke: none, width: 100%)[
#table(
  columns: 2,
  align: (auto,right,),
  table.header([Classification], [Establishments],),
  table.hline(),
  [By right], [29 (46%)],
  [Special approval required], [16 (25%)],
  [Not permitted by right], [6 (10%)],
  [Undetermined], [12 (19%)],
  [#strong[Total]], [#strong[63 (100%)]],
)
],
  rect(stroke: none, width: 100%)[
- #strong[All 16 special-approval cases] are on the Chestnut and Walnut frontage: the overlay, not the base district, triggers the review.
- #strong[All 6 not-by-right cases] are in multi-family residential districts, where restaurants and hotels are not allowed by right.
- City permit and Zoning Board records confirm an approval for #strong[6 of these 22] establishments. For example, #strong[Lucy's] (1720 Chestnut) received a special exception in 2023 for a restaurant with entertainment, on condition of no exterior music.

],
)
#strong[Not permitted by right ≠ illegal.] An establishment can operate lawfully through a special exception, a variance, or nonconforming status for a use that predates the 2012 Code. A licence does not show which applies; that needs an establishment-level check in Atlas.

== 5. Key takeaways
<key-takeaways>
+ #strong[Zoning separates commercial nightlife from residential areas.] Restaurants and entertainment uses are allowed by right in the commercial core north and east of the Square. The multi-family residential districts allow neither by right, and entertainment uses are barred from all residential districts and the park.
+ #strong[The Chestnut/Walnut overlay adds another layer of regulatory review.] Along the two main streets, even the most intensive commercial zoning sends restaurants and bars to the Zoning Board for case-by-case approval.
+ #strong[Business licensing and zoning authorization are distinct processes.] A current licence does not show zoning authorization: 22 licensed establishments run uses that need special approval or are not permitted by right, and only 6 of them have a confirmed approval in City records.

#block[
#emph[Sources:] Phila. Code Title 14, §§14-502, 14-529, 14-601, 14-602 (Tables 14-602-1/-2/-4), 14-502-2 (codelibrary.amlegal.com, accessed Oct 2026). OpenDataPhilly zoning base districts and overlays, council and police districts, RCOs, BIDs, commercial corridors. L&I business licences and PLCB licence extracts (teammate, Oct 2026). L&I zoning permits and ZBA appeals via phl.carto.com (the data behind atlas.phila.gov), retrieved 18 Oct 2026. Full tables: #NormalTok("outputs/analysis/licensing_zoning_comparison.csv");\; methods: #NormalTok("outputs/methodology/sources_and_methods.md");.

]



