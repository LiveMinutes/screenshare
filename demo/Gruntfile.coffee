module.exports = (grunt) ->
    grunt.loadNpmTasks "grunt-contrib-coffee"
    grunt.loadNpmTasks "grunt-contrib-uglify"
    grunt.loadNpmTasks "grunt-contrib-clean"
    grunt.loadNpmTasks "grunt-contrib-watch"
    grunt.loadNpmTasks 'grunt-contrib-copy'
    grunt.loadNpmTasks 'grunt-hub'
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

      copy:
        main:
          files: [
            {
              expand: true # includes files in path and its subdirs
              src: ["./!(node_modules)/**/*.!(coffee)", "package.json"]
              dest: "<%=dest%>/"
            }
            ,
            {
              expand: true,
              flatten:true,
              src: ["../client/build/*.js"]
              dest: "<%=dest%>/public/js"
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

      coffee:
          options:
              join: true
              bare: true
          demoClient:
              files:
                  "<%=dest%>/public/js/demo-client.js": ["public/coffee/*.coffee"]
          demoServer:
            files:
              "<%=dest%>/demo-server.js": ["DemoApp.coffee"]

      uglify:
          demoClient:
              files:
                  "<%=dest%>/public/js/demo-client.min.js": "<%=dest%>/public/js/demo-client.js"
          demoServer:
            files:
              "<%=dest%>/demo-server.min.js": "<%=dest%>/demo-server.js"

      watch:
          scripts:
              files: ["*.coffee"]
              tasks: ["coffee:demo"]
              options:
                  nospawn: true

    grunt.registerTask "build", ["clean:build", "hub:client", "copy", "coffee", "uglify"]
    grunt.registerTask "start", ["shell:npm", "shell:start"]
    grunt.registerTask "default", ["build", "start"]