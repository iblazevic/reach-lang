#lang scribble/manual
@(require scribble/core
          scribble/html-properties
          "lib.rkt")

@title[#:version reach-vers #:tag "reach-top"]{Reach: The Safest and Easiest DApp Programming Language}
@author[(author+email "Jay McCarthy" "jay@reach.sh")]

Reach is a domain-specific language for building decentralized applications (@|DApps|).

This set of documents contains everything you need to know about Reach.

@itemize[

@item{@seclink["overview"]{The overview} briefly introduces the basic ideas of Reach. It can be helpful to get some context before diving into other sections.}

@item{@seclink["tut"]{The tutorial} is a directed series of steps to create a simple @|DApp|. You should start here if you've never used Reach before and want to start at the beginning.}

@item{@seclink["guide"]{The guide} continues @seclink["overview"]{the overview} by discussing the key ideas and concepts used throughout Reach.
You will often want to visit the guide to learn the background and "why" of some topic after you get started.}

@item{@seclink["howtos"]{The how-tos} are a collection of recipes for building specific things in Reach and demonstrate effective use of Reach, as well as some of the design decisions that Reach programmers are faced with.}

@item{Finally, @seclink["ref"]{the reference} provides an exhaustive technical reference on each aspect of Reach.}

]

If you are looking for something specific, here are some places to look:

@itemize[

@item{Try consulting the @secref["doc-index"] or the @link["#toc"]{Table of Contents}.}

@item{Start a discussion on @(the-community-link).}

@item{Report issues with the @link["https://github.com/reach-sh/reach-lang/issues"]{GitHub issue tracker}.}

]

@margin-note{The source of this site is available on @hyperlink["https://github.com/reach-sh/reach-lang/tree/master/docs-src"]{GitHub};
we welcome @link["https://github.com/reach-sh/reach-lang/pulls"]{Pull Requests} for improvements and @link["https://github.com/reach-sh/reach-lang/issues"]{Issues} for problem reports!}

@(element (make-style #f (list (url-anchor "toc"))) '())
@(table-of-contents)

@include-section["overview.scrbl"]
@include-section["tut.scrbl"]
@include-section["guide.scrbl"]
@include-section["howto.scrbl"]
@include-section["ref.scrbl"]
@index-section[]
