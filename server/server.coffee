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
              frames: {},
              transmitter: null,
              receivers: []
            }

        else
          console.error "Room is mandatory"

        stream.on "close", =>
          console.log "Close", stream

          if stream is @rooms[meta.room].transmitter
            @rooms[meta.room].transmitter = null
          else
            index = @rooms[meta.room].receivers.indexOf(stream)
            if index > -1
              @rooms[meta.room].receivers.splice(index,1)

        # New transmitter, only one per room
        if meta.type is "write"
          if not @rooms[meta.room].transmitter
            console.log "Add transmitter", stream.id
            @rooms[meta.room].transmitter = stream
            @rooms[meta.room].transmitter.on "data", (data) =>
              #console.log data
              @rooms[meta.room].transmitter.write 1
              if data.k
                console.log "Store keyframe", data
                @rooms[meta.room].keyFrame = data
              else
                for frame in data
                  console.log "Store frame", frame
                  frame.t = new Date().getTime()
                  key = frame.x.toString() + frame.y.toString()
                  @rooms[meta.room].frames[key] = frame

            if @rooms[meta.room].receivers.length
              console.log "Existing clients", @rooms[meta.room].receivers.length
              for client in @rooms[meta.room].receivers
                console.log "Pipe to client", client
                @rooms[meta.room].transmitter.pipe client
          else
            console.error "Transmitter already registered"
        # New receivers, only maxClients per room
        else if meta.type is "read"
          if @rooms[meta.room].receivers.length < maxClients
            console.log "Add receiver", stream.id
            @rooms[meta.room].receivers.push(stream)

            if @rooms[meta.room].keyFrame
              console.log "Sending keyframe", @rooms[meta.room].keyFrame
              stream.write @rooms[meta.room].keyFrame

            stream.on "data", (data) =>
              console.log "Client data", data
              if data.command == 0
                timestamp = parseInt(data.t)
                console.log "Frames timestamp", timestamp
                updatedFrames = []
                for frame in room].frames
                  if frame.t > data.t
                    updatedFrames.push(frame)
                
                if updatedFrames.length
                  stream.write updatedFrames
                else
                  console.log "Frame", data.i, "not modified"
                  stream.write data.i
          else
            console.error "Room full"
      else
        console.error "Type is mandatory"

  run: ->
    @binaryEmitServer = new BinaryServer({port:@port})
    @binaryDispatchServer = new BinaryServer({port:@port+1})
    @rooms = {}

    @binaryEmitServer.on "connection", (client) =>
      client.on "error", onError
      client.on "stream", onStream

    @binaryDispatchServer.on "connection", (client) =>
      client.on "error", onError
      client.on "stream", onStream

    return @binaryServer

exports.ScreenSharingServer = ScreenSharingServer

if require.main == module
  new ScreenSharingServer().run()

