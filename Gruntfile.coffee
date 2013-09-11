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
      buildServerDev:
        src: ['./server/Gruntfile.coffee']
        tasks: ['build:dev']

      buildServerProduction:
        src: ['./server/Gruntfile.coffee']
        tasks: ['build:production']

      runServerProduction:
        src: ['./server/Gruntfile.coffee']
        tasks: ['start:production']

      runServerDev:
        src: ['./server/Gruntfile.coffee']
        tasks: ['start:dev']

      demo:
        src: ['./demo/Gruntfile.coffee']
        tasks: ['build']

      runDemo:
        src: ['./demo/Gruntfile.coffee']
        tasks: ['start']

  grunt.registerTask "install", ["shell"]
  grunt.registerTask "build:server:dev", ["hub:buildServerDev"]
  grunt.registerTask "build:server:production", ["hub:buildServerProduction"]
  grunt.registerTask "build:demo", ["hub:demo"]
  grunt.registerTask "run:server:production", ["hub:runServerProduction"]
  grunt.registerTask "run:server:dev", ["hub:runServerDev"]
  grunt.registerTask "run:demo", ["hub:runDemo"]