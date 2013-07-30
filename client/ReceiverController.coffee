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

      @timestamp = -1
      @timestamps = {}
      @sending = {}

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
        if @width isnt keyFrame.w or @height isnt keyFrame.h
          @width = keyFrame.w
          @height = keyFrame.h
          @canvas.width = @width
          @canvas.height = @height

        keyFrame.x = keyFrame.y = 0
        _draw keyFrame, callback

    ###*
    * Draw a set of frames on the canvas
    * @param {frames} Frames to draw
    ###
    _drawDiff = (frames, callback) =>
      for frame in frames
        if frame is frames[frames.length-1]
          _draw frame, callback
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
    * Ask to the server if new rectangles are available
    ###
    _getRectangle = =>
      @xOffset++  
      if @width - @xOffset * @constructor.TILE_SIZE <= 0
        @xOffset = 0
        @yOffset++
        if @height - @yOffset * @constructor.TILE_SIZE <= 0
          @yOffset = 0

      key = @xOffset.toString() + @yOffset.toString()

      @sending[key] = false unless key of @sending
      @timestamps[key] = @timestamp or -1 unless key of @timestamps

      if not @sending[key]
        console.debug 'Asking frame', key
        @sending[key] = true
        @stream.write 
          key: key
          t: @timestamps[key].toString()
      setTimeout _getRectangle, 10

    _onDataHandler = (frame) =>
      console.log frame

      if frame? and @started
        if frame is 0
          @trigger 'transmitterLeft'
        else 
          frame.t = parseInt(frame.t)
          frame.ts = parseInt(frame.t)
          frame.d = 'data:image/jpeg;base64,' + _arrayBufferToBase64(frame.d)

          now = new Date().getTime()
          console.log 'Latence from transmitter now', now, 'and', frame.t, (now - frame.t)/1000, 's'
          console.log 'Latence from server now', now, 'and', frame.t, (now - frame.ts)/1000, 's'

          if frame.k
            if frame.t > @timestamp
              console.debug "Keyframe"
              
              _drawKeyFrame frame, (=> 
                console.debug "Drawn keyFrame"

                @timestamps = {}  
                @sending = {}

                if @timestamp is -1
                  console.debug "Start _getRectangle"
                  setTimeout _getRectangle, 0
                  @trigger 'firstKeyframe'

                @timestamp = frame.t
              )
          else
            key = frame.x.toString() + frame.y.toString()

            if @sending[key] and frame.t > @timestamps[key]
              _draw frame, => 
                @sending[key] = false
                @timestamps[key] = frame.t
                @timestamp = frame.t

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
          if @started
            @stop()
            @trigger 'close'

        @stream.on 'error', (e) =>
          @stop()
          @trigger 'error', e
          
        @trigger 'open'

      @client.on 'error', (e) =>
        console.log 'error', e
        @stop()
        @trigger 'error', e

      @client.on 'close', =>
        if @started
          @stop()
          @trigger 'close'

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
    


