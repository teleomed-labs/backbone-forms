mountFolder = (connect, dir) ->
    connect.static require('path').resolve(dir)

module.exports = (grunt) ->
  require('matchdep').filterDev('grunt-*').forEach(grunt.loadNpmTasks)

  grunt.initConfig
    watch:
      options:
        nospawn: true
      coffee:
        files: [ 'src/{,*/}*.coffee' ]
        tasks: [ 'concat:dist', 'coffee:dist' ]
      coffeeTest:
        files: [ 'test/{,*/}*.coffee' ]
        tasks: [ 'concat:test', 'coffee:test', 'mocha_phantomjs' ]

    # Concat all the files into one file.
    concat:
      dist:
        dest: '.tmp/backbone-forms.coffee'
        src:  [
          'src/form.coffee',
          'src/validators.coffee',
          'src/fieldset.coffee',
          'src/field.coffee',
          'src/nestedfield.coffee',
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
      test:
        dest: '.tmp/specs.coffee'
        src:  'test/main.coffee'

    # Convert CoffeeScript to Javascript
    coffee:
      dist:
        src: '.tmp/backbone-forms.coffee'
        dest: 'dist/backbone-forms.js'
      test:
        src: '.tmp/specs.coffee'
        dest: '.tmp/specs.js'

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

    mocha_phantomjs:
      all: [ 'test/index.html' ]


    grunt.registerTask 'default', [
      'concat'
      'coffee'
      'uglify'
      'copy'
    ]

    grunt.registerTask 'test', [
      'concat'
      'coffee:test'
      'mocha_phantomjs'
    ]
