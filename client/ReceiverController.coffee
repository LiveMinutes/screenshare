class window.ScreenSharingReceiver extends Base
  ### Private members ###
  _init = null
  _drawKeyFrame = null
  _drawDiff = null
  _draw = null
  _arrayBufferToBase64 = null
  _getRectangle = null
  _createClient = null
  _onDataHandler = null

  ###*
   * Constructor
   * @param {serverUrl} URL to the Binary server
   * @param {room} Room to use
   * @params {canvas} Canvas to draw on
  ###
  constructor: (serverUrl, room, canvas) ->
    @serverUrl = serverUrl
    @room = room
    @canvas = canvas

    _init = =>
      @started = false
      @getRectangle = false
      @client = null
      @stream = null
      @xOffset = 0
      @yOffset = 0
      @canvasContext = canvas.getContext '2d'

      @frames = {}

    ###*
     * Decode a binary base64 arraybuffer to a Base64 string
     * @param {buffer} Buffer to decode
    ###
    _arrayBufferToBase64 = (buffer) ->
      binary = ''
      bytes = new Uint8Array(buffer)
      len = bytes.byteLength
      i = 0

      while i < len
        binary += String.fromCharCode(bytes[i])
        i++

      window.btoa binary

    ###*
    * Draw a key frame on the canvas
    * @param {keyFrame} The key frame to draw
    ###
    _drawKeyFrame = (keyFrame, callback) =>
      if keyFrame.k
        width = keyFrame.w
        height = keyFrame.h

        if @canvas.width isnt width or @canvas.height isnt height
          @canvas.width = width
          @canvas.height = height

        keyFrame.x = keyFrame.y = 0
        _draw keyFrame, callback or _endDrawCallback

    ###*
    * Draw a set of frames on the canvas
    * @param {frames} Frames to draw
    ###
    _drawDiff = (frames) =>
      for frame in frames
        if frame is frames[frames.length-1]
          _draw frame, _endDrawCallback
        else
          _draw frame

    ###*
    * Draw a frame on the canvas
    * @param {frame} the frame to draw
    * @param {callback} Callback to call when drawn
    ###
    _draw = (frame, callback) =>
      tileSize = @constructor.TILE_SIZE
      context = @canvasContext

      image = new Image()
      image.onload = ->
        context.drawImage this, frame.x*tileSize, frame.y*tileSize, frame.w or tileSize, frame.h or tileSize
        callback() if callback
      image.src = frame.d

    ###*
    * Callback when drawn
    ###
    _endDrawCallback = =>
      @getRectangle = false

    ###*
    * Ask to the server if new rectangles are available
    ###
    _getRectangle = =>
      if @getRectangle and @started
        setTimeout _getRectangle, 10
        return
      @getRectangle = true

      if not @timestamp
        @timestamp = -1

      if @stream and @stream.writable
        @stream.write @timestamp.toString()
        setTimeout _getRectangle, 0

    _onDataHandler = (frame) =>
      #console.log frame
      if frame and @started
        if frame.k
          setTimeout _getRectangle, 0
          frame.d = 'data:image/jpeg;base64,' + _arrayBufferToBase64(frame.d)
          _drawKeyFrame frame, (=> 
            _endDrawCallback()
            @trigger 'firstKeyframe'
            )
        else if typeof frame is 'object' and not frame.length
          now = new Date().getTime()
          frame.t = parseInt(frame.t)
          frame.ts = parseInt(frame.t)
          console.log 'Latence from transmitter now', now, 'and', frame.t, (now - frame.t)/1000, 's'
          console.log 'Latence from server now', now, 'and', frame.t, (now - frame.ts)/1000, 's'

          frame.d = 'data:image/jpeg;base64,' + _arrayBufferToBase64(frame.d)

          if frame.t > @timestamp
            @timestamp = frame.t unless frame.t < @timestamp
            _draw frame, _endDrawCallback
        else
          _endDrawCallback()

    _init()

    ###
    * Create the WS binary client
    ###
    _createClient = =>
      @client = new BinaryClient(@serverUrl)

      @client.on 'open', =>
        @stream = @client.createStream
          room: @room
          type: 'read'

        @stream.on 'data', _onDataHandler

        @stream.on 'close', =>
          @stop()
          @trigger 'streamClose'

        @stream.on 'error', =>
          @stop()
          @trigger 'error'
          
        @trigger 'open'

      @client.on 'error', (e) =>
        console.log 'error', e
        @stop()
        @trigger 'error'

      @client.on 'close', =>
        @stop()
        @trigger 'clientClose'

  ###*
  * Start the receiver, connect to the server
  ###
  start: ->
    if @started
      return
    @started = true

    _createClient()
    @trigger 'start'

  ###*
  * Start the receiver, connect to the server
  ###
  stop: ->
    if not @started
      return
    @started = false

    @client.close() if @client
    _init()
    @trigger 'stop'
    


