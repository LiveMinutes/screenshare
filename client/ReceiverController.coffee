class window.ScreenSharingReceiver extends Base
  _drawKeyFrame = null
  _drawDiff = null
  _draw = null
  _arrayBufferToBase64 = null
  _getRectangle = null

  constructor: (serverUrl, room, canvas) ->
    @serverUrl = serverUrl
    @room = room
    @canvas = canvas

    @xOffset = 0
    @yOffset = 0
    @canvasContext = canvas.getContext '2d'

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

    _drawKeyFrame = (keyFrame) =>
      if keyFrame.k
        width = keyFrame.w
        height = keyFrame.h

        if @canvas.width isnt width or @canvasKeyFrame.height isnt height
          @canvas.width = width
          @canvas.height = height

        keyFrame.x = keyFrame.y = 0
        _draw keyFrame, _endDrawCallback

    _drawDiff = (frames) =>
      for frame in frames
        if frame is frames[frames.length-1]
          _draw frame, _endDrawCallback
        else
          _draw frame

    _draw = (frame, callback) =>
      tileSize = @constructor.TILE_SIZE
      context = @canvasContext

      image = new Image()
      image.onload = ->
        context.drawImage this, frame.x*tileSize, frame.y*tileSize, frame.w or tileSize, frame.h or tileSize
        callback() if callback
      image.src = frame.d

    _endDrawCallback = =>
      @getRectangle = false

    _getRectangle = () =>
      if @getRectangle
        setTimeout _getRectangle, 10
        return
      @getRectangle = true

      if not @timestamp
        @timestamp = -1

      @stream.write @timestamp.toString()
      setTimeout _getRectangle, 0

  start: ->
    client = new BinaryClient(@serverUrl)

    client.on "open", =>
      @stream = client.createStream(
        room: @room
        type: "read"
      )
      @stream.on "data", (data) =>
        #console.log data

        if data
          if data.k
            setTimeout _getRectangle, 0
            data.d = "data:image/jpeg;base64," + _arrayBufferToBase64(data.d)
            _drawKeyFrame data
          else if typeof data is 'object' and data.length
            now = new Date().getTime()
            for frame in data
              frame.t = parseInt(frame.t)
              frame.ts = parseInt(frame.t)
              console.log "Latence from transmitter now", now, "and", frame.t, (now - frame.t)/1000, "s"
              console.log "Latence from server now", now, "and", frame.t, (now - frame.ts)/1000, "s"
              frame.d = "data:image/jpeg;base64," + _arrayBufferToBase64(frame.d)
              @timestamp = frame.t unless frame.t < @timestamp
              
            _drawDiff data
          else
            _endDrawCallback()
        
      client.on "error", (e) =>
        console.log "error", e
        @trigger "error"


