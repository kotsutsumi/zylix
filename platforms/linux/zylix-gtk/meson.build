# Zylix GTK4 - Meson Build

project('zylix-gtk', 'c',
  version: '0.1.0',
  default_options: ['warning_level=3', 'c_std=c11']
)

# Dependencies
gtk4_dep = dependency('gtk4', version: '>= 4.0')
m_dep = meson.get_compiler('c').find_library('m', required: false)

# Counter app
executable('zylix-counter',
  'main.c',
  dependencies: [gtk4_dep, m_dep],
  install: true
)

# Todo app
executable('zylix-todo',
  'todo_app.c',
  dependencies: [gtk4_dep, m_dep],
  install: true
)
