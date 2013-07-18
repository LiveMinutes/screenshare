BinaryServer = require('binaryjs').BinaryServer;

class ScreenSharingServer
  defaultPort = 9001
  maxClients = 5

  onError = null
  onStream = null
  closeRoom = null

  constructor: (port) ->
    @port = port or defaultPort

    onError = (e) ->
      console.log e.stack, e.message

    closeRoom = (roomId) =>
      room = @rooms[roomId]
      if room.receivers.length is 0 and room.transmitter is null
        console.log "Closing room", room
        room = null

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
          return

        # New transmitter, only one per room
        if meta.type is "write"
          if not @rooms[meta.room].transmitter
            console.log "Add transmitter", stream.id
            @rooms[meta.room].transmitter = stream

            @rooms[meta.room].transmitter.on "close", =>
              console.log "Close", @rooms[meta.room].transmitter
              @rooms[meta.room].transmitter = null
              closeRoom(meta.room)
              
            @rooms[meta.room].transmitter.on "data", (data) =>
              if @rooms[meta.room].processFrames
                console.log "Dropped frames"
                return
    
              if data         
                @rooms[meta.room].processFrames = true
                if data.k
                  console.log "Store keyframe", data
                  @rooms[meta.room].keyFrame = data
                  @rooms[meta.room].transmitter.write 1
                else
                  for frame in data
                    frame.ts = new Date().getTime().toString()
                    key = frame.x.toString() + frame.y.toString()
                    @rooms[meta.room].frames[key] = frame
                    console.log "Store frame", key, frame
                  @rooms[meta.room].transmitter.write data.length
                
                @rooms[meta.room].processFrames = false
          else
            console.error "Transmitter already registered"
            return

        # New receivers, only maxClients per room
        else if meta.type is "read"
          if @rooms[meta.room].receivers.length < maxClients
            console.log "Add receiver", stream.id
            @rooms[meta.room].receivers.push(stream)

            if @rooms[meta.room].keyFrame
              console.log "Sending keyframe", @rooms[meta.room].keyFrame
              stream.write @rooms[meta.room].keyFrame

            stream.on "close", =>
              index = @rooms[meta.room].receivers.indexOf(stream)
              if index > -1
                @rooms[meta.room].receivers.splice(index,1)
                closeRoom(meta.room)

            stream.on "data", (data) =>
              console.log "Client data", data
              
              timestamp = parseInt(data)
              console.log "Frames timestamp", timestamp
              updatedFrames = []
              for own key, frame of @rooms[meta.room].frames
                  updatedFrames.push(frame) if frame.t > timestamp
              
              if updatedFrames.length
                console.log "Sending", updatedFrames.length, "updated frames since", timestamp
                stream.write updatedFrames
              else
                console.log "Frame", data, "not modified"
                stream.write data
          else
            console.error "Room full"
            return
      else
        console.error "Type is mandatory"
        return

  run: ->
    @binaryServer = new BinaryServer({port:@port})
    @rooms = {}

    @binaryServer.on "connection", (client) =>
      client.on "error", onError
      client.on "stream", onStream

    return @binaryServer

exports.ScreenSharingServer = ScreenSharingServer

if require.main == module
  process.on 'uncaughtException', (err) ->
    console.error((new Date).toUTCString() + ' uncaughtException:', err.message)
    console.error(err.stack)
    process.exit(1)

  new ScreenSharingServer().run()

