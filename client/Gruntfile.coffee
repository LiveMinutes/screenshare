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
          unminified: ["<%=dest%>/base.js", "<%=dest%>/transmitter.js", "<%=dest%>/receiver.js"]

      coffee:
          options:
              join: true
          base:
              files:
                  "<%=dest%>/base.js": ["../common/Base.coffee"]
          transmitter:
              files:
                  "<%=dest%>/transmitter.js": ["TransmitterController.coffee"]
          receiver:
            files:
              "<%=dest%>/receiver.js": ["ReceiverController.coffee"]

      cafemocha:
        testThis:
          src: "test/*.coffee"
          options:
            ui: "bdd"
            require: ["should"]

      uglify:
          options:
            compress:
              global_defs:
                "DEBUG": false
              dead_code: true

          transmitter:
            files:
                "<%=dest%>/transmitter.min.js": ["<%=dest%>/base.js", "<%=dest%>/transmitter.js"]
          receiver:
            files:
              "<%=dest%>/receiver.min.js": ["<%=dest%>/base.js", "<%=dest%>/receiver.js"]


      watch:
          scripts:
              files: ["*.coffee"]
              tasks: ["coffee:client"]
              options:
                  nospawn: true

    grunt.registerTask "build", ["clean:build", "coffee"]
    grunt.registerTask "build:dev", ["build"]
    grunt.registerTask "build:production", ["build", "uglify", "clean:unminified"]
    grunt.registerTask "default", ["build"]