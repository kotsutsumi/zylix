# Zylix GTK4 - Meson Build

project('zylix-counter', 'c',
  version: '0.1.0',
  default_options: ['warning_level=3', 'c_std=c11']
)

# Dependencies
gtk4_dep = dependency('gtk4', version: '>= 4.0')

# Zylix Core library (pre-built)
zylix_lib = declare_dependency(
  link_args: [
    '-L' + meson.source_root() + '/../../../core/zig-out/linux-x64',
    '-lzylix',
    '-lm'
  ]
)

# Sources
sources = [
  'main.c'
]

# Executable
executable('zylix-counter',
  sources,
  dependencies: [gtk4_dep, zylix_lib],
  install: true
)
