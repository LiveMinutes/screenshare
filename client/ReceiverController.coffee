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

    client = new BinaryClient(serverUrl)

    client.on "open", =>
      @stream = client.createStream(
        room: room
        type: "read"
      )
      @stream.on "data", (data) =>
        @sending = false
        console.log data

        data.d = "data:image/jpeg;base64," + _arrayBufferToBase64(data.d)

        if data.k
          @keyFrameReceived = true
          @width = data.w
          @height = data.h
          setInterval getRectangle, 50
          @trigger "snap", {data:data}
        else if typeof data.x isnt 'undefined' and typeof data.y isnt 'undefined'
          key = data.x.toString() + data.y.toString()
          @frames[key] = data
          @trigger "snap", {data:data}
        else if @frames[data] and @frames[data].sending
          @frames[data].sending = false

    client.on "error", (e) =>
      console.log "error", e
      @trigger "error"

    getRectangle = () =>
      if @getRectangle
        return
      @getRectangle = true

      key = @xOffset.toString() + @yOffset.toString()
      sending = if @frames[key] then @frames[key].sending else false

      @xOffset++
      if @xOffset*TILE_SIZE >= @width
        @xOffset = 0

        @yOffset++
        if @yOffset*TILE_SIZE >= @height
          @yOffset = 0

      if sending
        @getRectangle = false
        return

      console.log "Ask frame", key

      if not @frames[key]
        @frames[key] =
          sending: true
          t: -1
      else
        @frames[key].sending = true

      @stream.write
        command: 0
        i : key
        t:  @frames[key].t

      @getRectangle = false


