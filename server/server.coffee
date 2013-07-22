BinaryServer = require('binaryjs').BinaryServer
Canvas = require 'canvas'
btoa = require 'btoa'
atob = require 'atob'

class ScreenSharingServer
  defaultPort = 9001
  maxClients = 5

  onError = null
  onStream = null
  closeRoom = null
  drawFrame = null
  _arrayBufferToBase64 = null
  _dataURItoBlob = null

  constructor: (port) ->
    @port = port or defaultPort

    onError = (e) ->
      console.log e.stack, e.message

    closeRoom = (roomId) =>
      room = @rooms[roomId]
      if room.receivers.length is 0 and room.transmitter is null
        console.log "Closing room", room
        room = null

    ###*
     * Convert base64 to raw binary data held in a string.
     * Doesn't handle URLEncoded DataURIs
     * @param {dataURI} ASCII Base64 string to encode
     * @return {ArrayBuffer} ArrayBuffer representing the input string in binary
    ###
    _dataURItoBlob = (dataURI) ->
      byteString = undefined
      if dataURI.split(",")[0].indexOf("base64") >= 0
        byteString = atob(dataURI.split(",")[1])
      else
        byteString = unescape(dataURI.split(",")[1])
  
      # separate out the mime component
      mimeString = dataURI.split(",")[0].split(":")[1].split(";")[0]
  
      # write the bytes of the string to an ArrayBuffer
      ab = new ArrayBuffer(byteString.length)
      ia = new Uint8Array(ab)
      i = 0
  
      while i < byteString.length
        ia[i] = byteString.charCodeAt(i)
        i++
  
      # write the ArrayBuffer to a blob, and you're done
      ab

    _arrayBufferToBase64 = (buffer) ->
      binary = ""
      bytes = new Uint8Array(buffer)
      len = bytes.byteLength
      i = 0

      while i < len
        binary += String.fromCharCode(bytes[i])
        i++

      btoa binary

    drawFrame = (room, frame) =>
      console.log "Draw frame", frame, "in room", room
      dataBase64 = "data:image/jpeg;base64," + _arrayBufferToBase64 frame.d

      if frame.k
        frame.x = frame.y = 0

      tileSize = 256
      image = new Canvas.Image()
      image.onload = =>
        @ctx.drawImage image, frame.x*tileSize, frame.y*tileSize, frame.w or tileSize, frame.h or tileSize
        console.log "Keyframe.d before", @rooms[room].keyFrame.d
        dataURI = @canvas.toDataURL 'image/jpeg'
        console.log "Err", err.message
        console.log "DataURI", dataURI
        @rooms[room].keyFrame.d = _dataURItoBlob dataURI
          #console.log "Keyframe.d after", @rooms[room].keyFrame.d
      image.src = dataBase64

    onStream = (stream, meta) =>
      if meta.type
        if meta.room
          if not @rooms[meta.room]
            @rooms[meta.room] = {
              keyFrame: null,
              frames: {},
              transmitter: null,
              receivers: {}
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
                  @canvas = new Canvas(data.w, data.h)
                  @ctx = @canvas.getContext('2d')
                  drawFrame meta.room, data
                  @rooms[meta.room].transmitter.write 1
                else
                  updatedFrames = {}
                  for frame in data
                    #console.log "Store frame", key, frame
                    key = frame.x.toString() + frame.y.toString()
                    frame.ts = new Date().getTime().toString()

                    for id, client of @rooms[meta.room].receivers
                      console.log "Client", id, client.lastTimestamp
                      if frame.t > client.lastTimestamp
                        if not updatedFrames[client.id]
                          updatedFrames[client.id] = []
                        console.log "Updated frame", frame.x, frame.y
                        updatedFrames[client.id].push frame

                    drawFrame meta.room, frame
                    #@rooms[meta.room].frames[key] = frame

                  @rooms[meta.room].transmitter.write data.length

                  for client of updatedFrames
                    console.log "Sending updated frames to client", client
                    client.lastTimestamp = null
                    @rooms[meta.room].receivers[client].write updatedFrames[client]
                
                @rooms[meta.room].processFrames = false
          else
            console.error "Transmitter already registered"
            return

        # New receivers, only maxClients per room
        else if meta.type is "read"
          if Object.keys(@rooms[meta.room].receivers).length < maxClients
            console.log "Add receiver", stream.id
            @rooms[meta.room].receivers[stream.id] = stream

            if @rooms[meta.room].keyFrame
              console.log "Sending keyframe", @rooms[meta.room].keyFrame
              stream.write @rooms[meta.room].keyFrame

            stream.on "close", =>
              index =
              if @rooms[meta.room].receivers[stream.id]
                delete @rooms[meta.room].receivers[stream.id]
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
                console.log "Frame not modified since", data, "storing timestamp"
                if @rooms[meta.room].receivers[stream.id] 
                  @rooms[meta.room].receivers[stream.id].lastTimestamp = data
                
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

