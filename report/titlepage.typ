// Standalone ETH IIS-style title page for Typst.
// No mandatory fields — every parameter is optional.
// No external packages required — works on typst.app out of the box.
//
// Usage:
//   #import "titlepage.typ": eth-title
//   #show: eth-title.with(
//     title: "My Title",
//     author: "My Name",
//     ...
//   )

#let _current-semester() = {
  let now = datetime.today()
  let season = if now.month() <= 6 { "Spring" } else { "Fall" }
  season + " Semester " + str(now.year()).slice(2)
}

#let _format-date(d) = {
  let months = (
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
  )
  months.at(d.month() - 1) + " " + str(d.day()) + ", " + str(d.year())
}

#let eth-title(
  title: none,
  subtitle: none,
  author: none,
  email: none,
  date: none,
  semester: none,
  reporttype: none,
  advisors: none,
  professors: none,
  logo: none,
  abstract: none,
  acknowledgements: none,
  show-toc: false,
  body,
) = {
  set page(paper: "a4", margin: (top: 25mm, bottom: 25mm, left: 30mm, right: 30mm))
  set text(size: 12pt)

  // ===================== Title Page =====================
  set page(numbering: none)

  v(2em)
  line(length: 100%, stroke: 0.5pt)
  v(1em)

  align(center, text(features: ("smcp",), [
    Department of Information Technology and Electrical Engineering\
    Integrated Systems Laboratory

    #v(0.25em)

    #let sem = if semester != none { semester } else { _current-semester() }
    #sem
  ]))

  v(2em)

  if title != none {
    align(center, text(size: 28pt, weight: "bold", title))
    v(1.5em)
  }
  
  if subtitle != none {
    align(center, text(size: 18pt, weight: "bold", subtitle))
    v(1.5em)
  }
  
  if reporttype != none {
    align(center, text(size: 16pt, features: ("smcp",), reporttype))
    v(1.5em)
  }

  if logo != none {
    align(center, logo)
    v(1.5em)
  }

  v(1fr)

  if author != none {
    align(center, text(size: 14pt, author))
    v(0.5em)
  }

  if email != none {
    align(center, text(size: 12pt, fill: blue, email))
    v(0.5em)
  }

  let d = if date != none { date } else { datetime.today() }
  align(center, text(size: 12pt, _format-date(d)))

  v(1fr)

  line(length: 100%)
  v(0.5em)

  if advisors != none {
    text(weight: "bold", "Advisors:")
    for p in advisors {
      linebreak()
      if p.mail != none {
        [\- #p.name, #text(fill: blue, p.mail)]
      } else {
        [\- #p.name]
      }
    }
  }

  if professors != none {
    if advisors != none { v(0.5em) }
    text(weight: "bold", "Professor:")
    for p in professors {
      linebreak()
      if p.mail != none {
        [\- #p.name, #text(fill: blue, p.mail)]
      } else {
        [\- #p.name]
      }
    }
  }

  pagebreak()

  // ===================== Front Matter =====================
  set page(numbering: "i")

  if acknowledgements != none {
    align(center, text(size: 24pt, weight: "bold", "Acknowledgements"))
    v(1em)
    acknowledgements
    pagebreak()
  }

  if abstract != none {
    align(center, text(size: 24pt, weight: "bold", "Abstract"))
    v(1em)
    abstract
    pagebreak()
  }

  if show-toc {
    align(center, text(size: 24pt, weight: "bold", "Contents"))
    v(1em)
    outline()
    pagebreak()
  }

  // ===================== Main Body =====================
  set page(numbering: "1")
  body
}
