'use strict'

mountFolder = (connect, dir) ->
    connect.static require('path').resolve(dir)

module.exports = (grunt) ->
  require('matchdep').filterDev('grunt-*').forEach(grunt.loadNpmTasks)

  grunt.initConfig

    # Concat all the files into one file.
    concat:
      dist:
        dest: '.tmp/backbone-forms.coffee'
        src:  [
          'src/form.coffee',
          'src/validators.coffee',
          'src/fieldset.coffee',
          'src/field.coffee',
          'src/nestedField.coffee',
          'src/editor.coffee',
          'src/editors/text.coffee',
          'src/editors/textarea.coffee',
          'src/editors/password.coffee',
          'src/editors/number.coffee',
          'src/editors/hidden.coffee',
          'src/editors/checkbox.coffee',
          'src/editors/select.coffee',
          'src/editors/radio.coffee',
          'src/editors/checkboxes.coffee',
          'src/editors/object.coffee',
          'src/editors/nestedmodel.coffee',
          'src/editors/date.coffee',
          'src/editors/datetime.coffee',
          'src/editors/extra/list.coffee',
        ]

    # Convert CoffeeScript to Javascript
    coffee:
      dist:
        src: '.tmp/backbone-forms.coffee'
        dest: 'dist/backbone-forms.js'

    # Uglify/minify the build
    uglify:
      dist:
        src: 'dist/backbone-forms.js'
        dest: 'dist/backbone-forms.min.js'

    # Copy additional JS/CSS assets over
    copy:
      dist:
        files: [
          {
            expand: true
            cwd: 'src/templates'
            src:  '*'
            dest: 'dist/templates'
          },
          {
            expand: true
            cwd: 'lib'
            src:  '*'
            dest: 'dist/lib'
          }
        ]

    grunt.registerTask 'default', [
      'concat'
      'coffee'
      'uglify'
      'copy'
    ]
