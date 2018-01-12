[
  # functions to let allow the no parens like def print value
  # locals_without_parens: [hello: 2, get_user: 1, addtion: *],

  # files to format
  inputs: ["mix.exs", "{config,lib,test}/**/*.{ex,exs}"],

  line_length: 80,

  # importing configs from other libraries it is depending
  #import_deps: [:dependency1, :dependency2],

  # configuration export to other projects to use in their projects
  #export: [
  # [
  #      locals_without_parens: [hello: 2, get_user: 1, addtion: *]
  #  ]
  #]
]
