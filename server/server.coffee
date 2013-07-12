BinaryServer = require('binaryjs').BinaryServer;

class ScreenSharingServer
  defaultPort = 9001
  maxClients = 5

  onError = null
  onStream = null

  constructor: (port) ->
    @port = port or defaultPort

    onError = (e) ->
      console.log e.stack, e.message

    onStream = (stream, meta) =>
      if meta.type
        if meta.room
          if not @rooms[meta.room]
            @rooms[meta.room] = {
              keyFrame: null,
              transmitter: null,
              receivers: []
            }
        else
          console.error "Room is mandatory"

        # New transmitter, only one per room
        if meta.type is "write"
          if not @rooms[meta.room].transmitter
            console.log "Add transmitter", stream.id
            @rooms[meta.room].transmitter = stream
            @rooms[meta.room].transmitter.on "data", (data) =>
              if data.k
                console.log "Store keyframe", data
                @rooms[meta.room].keyFrame = data

            if @rooms[meta.room].receivers.length
              console.log "Existing clients", @rooms[meta.room].receivers.length
              for client in @rooms[meta.room].receivers
                console.log "Pipe to client", client
                @rooms[meta.room].transmitter.pipe client
          else
            console.error "Transmitter already registered"
        # New receivers
        else if meta.type is "read"
          if @rooms[meta.room].receivers.length < maxClients
            console.log "Add receiver", stream.id
            @rooms[meta.room].receivers.push(stream)

            stream.on "close", =>
              index = @rooms[meta.room].receivers.indexOf(stream)
              console.log "Close", stream
              @rooms[meta.room].receivers.splice(index,1)

            if @rooms[meta.room].transmitter
              @rooms[meta.room].transmitter.pipe stream
              if @rooms[meta.room].keyFrame
                console.log "Sending keyframe", @rooms[meta.room].keyFrame
                stream.write @rooms[meta.room].keyFrame
          else
            console.error "Room full"
      else
        console.error "Type is mandatory"

  run: ->
    @binaryServer = new BinaryServer({port:@port})
    @rooms = {}
    @binaryServer.on "connection", (client) =>
      client.on "error", onError
      client.on "stream", onStream

    return @binaryServer

exports.ScreenSharingServer = ScreenSharingServer

if require.main == module
  new ScreenSharingServer().run()

