class window.ScreenSharingReceiver extends Base
  TILE_SIZE = 256
  constructor: (serverUrl, room) ->
    @keyFrameReceived = false
    @xOffset = 0
    @yOffset = 0
    @frames = {}

    _arrayBufferToBase64 = (buffer) ->
      binary = ""
      bytes = new Uint8Array(buffer)
      len = bytes.byteLength
      i = 0

      while i < len
        binary += String.fromCharCode(bytes[i])
        i++

      window.btoa binary

    _endDrawCallback = =>
      @getRectangle = false

    client = new BinaryClient(serverUrl)

    client.on "open", =>
      @stream = client.createStream(
        room: room
        type: "read"
      )
      @stream.on "data", (data) =>
        #console.log data

        if data
          if data.k
            @keyFrameReceived = true
            @width = data.w
            @height = data.h
            setInterval getRectangle, 500
            data.d = "data:image/jpeg;base64," + _arrayBufferToBase64(data.d)
            @trigger "snap", {data:data, callback: _endDrawCallback}
          else if typeof data is 'object' and data.length
            now = new Date().getTime()
            for frame in data
              frame.t = parseInt(frame.t)
              frame.ts = parseInt(frame.t)
              console.log "Latence from transmitter now", now, "and", frame.t, (now - frame.t)/1000, "s"
              console.log "Latence from server now", now, "and", frame.t, (now - frame.ts)/1000, "s"
              frame.d = "data:image/jpeg;base64," + _arrayBufferToBase64(frame.d)
              @timestamp = frame.t unless frame.t < @timestamp
              
            @trigger "snap", {data:data, callback: _endDrawCallback}
          else
            _endDrawCallback()
      
    client.on "error", (e) =>
      console.log "error", e
      @trigger "error"

    getRectangle = () =>
      if @getRectangle
        return
      @getRectangle = true

      if not @timestamp
        @timestamp = -1


      @stream.write @timestamp.toString()


