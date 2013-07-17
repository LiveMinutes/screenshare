module.exports = (grunt) ->
    grunt.loadNpmTasks "grunt-contrib-coffee"
    grunt.loadNpmTasks "grunt-contrib-uglify"
    grunt.loadNpmTasks "grunt-contrib-clean"
    grunt.loadNpmTasks "grunt-contrib-watch"
    grunt.loadNpmTasks "grunt-cafe-mocha"
    grunt.loadNpmTasks 'grunt-shell'
    grunt.loadNpmTasks 'grunt-contrib-copy'

    grunt.initConfig
      dest: "build"
      pkg: "<json:package.json>"
      meta:
          banner: "/*! <%=pkg.name%> - v<%=pkg.version%> (build <%=pkg.build%>) - " + "<%=grunt.template.today(\"dddd, mmmm dS, yyyy, h:MM:ss TT\")%> */"

      clean:
          build: ["<%=dest%>"]

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
            expand: true # includes files in path and its subdirs
            src: ["package.json"]
            dest: "<%=dest%>/"
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

      uglify:
          js:
              files:
                  "<%=dest%>/server.min.js": "<%=dest%>/server.js"

      watch:
          scripts:
              files: ["server.coffee"]
              tasks: ["coffee:server"]
              options:
                  nospawn: true

    grunt.registerTask "build", ["clean:build", "copy", "coffee", "uglify"]
    grunt.registerTask "start", ["shell:npm", "shell:start"]
    grunt.registerTask "default", ["build", "start"]