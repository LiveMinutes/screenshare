module.exports = (grunt) ->
    grunt.loadNpmTasks "grunt-contrib-coffee"
    grunt.loadNpmTasks "grunt-contrib-clean"
    grunt.loadNpmTasks "grunt-contrib-watch"
    grunt.loadNpmTasks 'grunt-contrib-copy'
    grunt.loadNpmTasks "grunt-hub"
    grunt.loadNpmTasks "grunt-cafe-mocha"
    grunt.loadNpmTasks 'grunt-shell'

    grunt.initConfig
      dest: "build"
      pkg: "<json:package.json>"
      meta:
          banner: "/*! <%=pkg.name%> - v<%=pkg.version%> (build <%=pkg.build%>) - " + "<%=grunt.template.today(\"dddd, mmmm dS, yyyy, h:MM:ss TT\")%> */"

      clean:
          build: ["<%=dest%>"]

      hub:
        client:
          src: ['../client/Gruntfile.coffee']
          tasks: ['build']

      coffee:
          server:
            options:
              bare:true
            files:
                "<%=dest%>/server.js": ["server.coffee"]

      cafemocha:
        testThis:
          src: "test/*.coffee"
          options:
            ui: "bdd"
            require: ["should"]

      copy:
        main:
          files: [
            {
              expand: true # includes files in path and its subdirs
              src: ["cert/**/*"]
              dest: "<%=dest%>/"
            }
            ,
            {
              expand: true # includes files in path and its subdirs
              src: ["package.json"]
              dest: "<%=dest%>/"
            }
            ,
            {
              expand: true,
              flatten:true,
              src: ["../client/build/*.js"]
              dest: "<%=dest%>/public/js"
            }
            ,
            {
              expand: true,
              flatten:true,
              src: ["../client/libs/binaryjs/dist/*.js"]
              dest: "<%=dest%>/public/js/binaryjs"
            }
          ]
        coffee:
          files: [
            {
              expand: true # includes files in path and its subdirs
              src: ["server.coffee"]
              dest: "<%=dest%>/"
            }
          ]

      shell:
        npm:
          options:
            stdout: true
            execOptions:
              cwd: '<%=dest%>'
          command: 'npm install --production --no-registry'
        start:
          options:
            stdout: true
            execOptions:
              cwd: '<%=dest%>'
          command: 'npm start'

      watch:
          scripts:
              files: ["server.coffee"]
              tasks: ["coffee:server"]
              options:
                  nospawn: true

    grunt.registerTask "build", ["clean:build", "hub:client", "copy"]
    grunt.registerTask "build-js", ["clean:build", "hub:client", "copy:main", "coffee"]
    grunt.registerTask "start", ["shell:npm", "shell:start"]
    grunt.registerTask "default", ["build", "start"]