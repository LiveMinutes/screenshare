fs = require('fs')
express = require('express')
routes = require('./routes')
https = require('https')
path = require('path')

screenshare = exports? and @

class screenshare.DemoApp
  defaultPort = 3000
  constructor: ->
    @app = express()
    @options =
      key: fs.readFileSync(path.join(__dirname, "cert", "privatekey.pem"))
      cert: fs.readFileSync(path.join(__dirname, "cert", "certificate.pem"))

    @app.set "port", process.env.PORT or defaultPort
    @app.set "views", __dirname + "/views"
    @app.set "view engine", "ejs"
    @app.engine "html", require("ejs").renderFile
    @app.use express.favicon()
    @app.use express.logger("dev")
    @app.use express.bodyParser()
    @app.use express.methodOverride()
    @app.use @app.router
    @app.use express.static(path.join(__dirname, "public"))
    @app.use express.bodyParser({uploadDir: path.join(__dirname, "public", "uploads")});

    # development only
    @app.use express.errorHandler()  if "development" is @app.get("env")
    @app.get "/emit/:room", routes.emit
    @app.get "/receive/:room", routes.receive
    @app.post "/screenshot/:room", routes.screenshot

  run: ->
    fs.mkdirSync path.join(__dirname, "public", "images")
    server = https.createServer(@options, @app).listen @app.get("port"), =>
      console.log "Express server listening on port " + @app.get("port")

if require.main == module
  new screenshare.DemoApp().run()