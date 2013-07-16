module.exports = (grunt) ->
  grunt.loadNpmTasks 'grunt-hub'
  grunt.loadNpmTasks 'grunt-shell'

  grunt.initConfig
    shell:
      installClient:
        options:
          stdout: true
          execOptions:
            cwd: './client'
        command: 'npm install'
      installServer:
        options:
          stdout: true
          execOptions:
            cwd: './server'
        command: 'npm install'

      installDemo:
        options:
          stdout: true
          execOptions:
            cwd: './demo'
        command: 'npm install'

    hub:
      server:
        src: ['./server/Gruntfile.coffee']
        tasks: ['build']

      runServer:
        src: ['./server/Gruntfile.coffee']
        tasks: ['start']

      client:
        src: ['./client/Gruntfile.coffee']
        tasks: ['build']

      demo:
        src: ['./demo/Gruntfile.coffee']
        tasks: ['build']

      runDemo:
        src: ['./demo/Gruntfile.coffee']
        tasks: ['start']

  grunt.registerTask "install", ["shell"]
  grunt.registerTask "build:server", ["hub:server"]
  grunt.registerTask "build:demo", ["hub:demo"]
  grunt.registerTask "run:server", ["hub:runServer"]
  grunt.registerTask "run:demo", ["hub:runDemo"]