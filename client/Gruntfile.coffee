module.exports = (grunt) ->
    grunt.loadNpmTasks "grunt-contrib-coffee"
    grunt.loadNpmTasks "grunt-contrib-uglify"
    grunt.loadNpmTasks "grunt-contrib-clean"
    grunt.loadNpmTasks "grunt-contrib-watch"
    grunt.loadNpmTasks "grunt-cafe-mocha"

    grunt.initConfig
      dest: "build"
      pkg: "<json:package.json>"
      meta:
          banner: "/*! <%=pkg.name%> - v<%=pkg.version%> (build <%=pkg.build%>) - " + "<%=grunt.template.today(\"dddd, mmmm dS, yyyy, h:MM:ss TT\")%> */"

      clean:
          build: ["<%=dest%>"]

      coffee:
          options:
              join: true
          transmitter:
              files:
                  "<%=dest%>/transmitter.js": ["Base.coffee", "TransmitterController.coffee"]
          receiver:
            files:
              "<%=dest%>/receiver.js": ["Base.coffee", "ReceiverController.coffee"]

      cafemocha:
        testThis:
          src: "test/*.coffee"
          options:
            ui: "bdd"
            require: ["should"]

      uglify:
          transmitter:
              files:
                  "<%=dest%>/transmitter.min.js": "<%=dest%>/transmitter.js"
          receiver:
            files:
              "<%=dest%>/receiver.min.js": "<%=dest%>/receiver.js"


      watch:
          scripts:
              files: ["*.coffee"]
              tasks: ["coffee:client"]
              options:
                  nospawn: true

    grunt.registerTask "build", ["clean:build", "coffee", "uglify"]
    grunt.registerTask "default", ["build"]