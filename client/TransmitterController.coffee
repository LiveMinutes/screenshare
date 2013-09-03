screenshare = @screenshare? and @screenshare or @screenshare = {}

###*
  * Screen transmitter
###
class screenshare.ScreenSharingTransmitter extends screenshare.Base
  ### Defaults options ###
  defaults:
    exportFormat: 'image/jpeg'
    highQuality: 0.8
    mediumQuality: 0.3
    lowQuality: 0.1
    maxWidth: 800
  
  ###*
   * Constructor
   * @param {serverUrl} URL to the Binary server
   * @param {room} Room to use
   * @params {options} Options to use
  ###
  constructor: (serverUrl, room, options) ->
    @serverUrl = serverUrl
    @room = room
    super options

    # Retina support (devicePixelRatio == 2)
    if devicePixelRatio > 1
      @width = screen.width
    else
      @width = Math.min(@options.maxWidth, screen.width)

    @height = screen.height / (screen.width/@width)

    @cvs = document.createElement 'canvas'
    @ctx = @cvs.getContext '2d'

    @exportCanvas = document.createElement 'canvas'
    @exportCanvasCtx = @exportCanvas.getContext '2d'

    @video = document.createElement 'video'
    @video.autoplay = true

    @_init = =>
      @keyframe = false
      @streaming = false
      @sending = 0
      @lastFrames = null
      @sentFrameRate = []
      @mismatchesCount = null

    ###*
     * Process the network stats (frames to send / sent)
    ###
    @_processNetworkStats = =>
      return if not @started

      if not @hasSent
        @_processNetworkStatsInterval = setTimeout @_processNetworkStats, 1000
        return

      if @sentFrameRate.length >= 5
        console.log 'Reset network'
        @sentFrameRate.length = 0 
        @avgSendFrames = 0

      # process sent frames per sec.
      ratioSent = (@framesSent/@framesToSend) * 100
      @framesToSend = 0
      @framesSent = 0

      if ratioSent isnt NaN
        @sentFrameRate.push(ratioSent)
        sum = @sentFrameRate.reduce (t, s) -> t + s
        @avgSendFrames = sum/@sentFrameRate.length

      console.log 'Sent frames:', ratioSent
      console.log 'Avg:', @avgSendFrames

      @hasSent = false
      @notSent = 0

      @_processNetworkStatsInterval = setTimeout @_processNetworkStats, 1000

    ###*
     * Return the correct quality regarding network quality and screen activity
     * @param {key} Frame's key
     * @return The correct quality
    ###
    @_getQuality = (key) =>
      quality = @options.highQuality

      if @mismatchesCount?
        if key
          if key of @mismatchesCount
            if @mismatchesCount[key] >= 2 or (@avgSendFrames > 0 and @avgSendFrames <= 50 or @avgSendFrames >= 150)
              #console.log key, 'Low quality', @options.lowQuality
              quality = @options.lowQuality
            else if @mismatchesCount[key] >= 1 or (@avgSendFrames > 0 and @avgSendFrames <= 90 or @avgSendFrames >= 110)
              #console.log key, 'Medium quality', @options.mediumQuality
              quality = @options.mediumQuality
        else
          if @avgSendFrames > 0
            if @avgSendFrames <= 75 or @avgSendFrames >= 125
              #console.log 'Low quality', @options.lowQuality
              quality = @options.lowQuality
            else if @avgSendFrames <= 90 or @avgSendFrames >= 110
              #console.log 'Medium quality', @options.mediumQuality
              quality = @options.mediumQuality

      return quality

    ###*
     * Test equality between two frames
     * @param {a} First frame
     * @param {b} Second frame
     * @param {tolerance} Tolerance gap
     * @return True if equal, false otherwise
    ###
    @_equal = (a, b, tolerance) ->
      aData = a.data
      bData = b.data
      length = aData.length
      i = undefined
      tolerance = tolerance or 0

      i = length
      while i--
        return false  if aData[i] isnt bData[i] and Math.abs(aData[i] - bData[i]) > tolerance
      true

    ###*
     * Export a frame
     * @param {data} Raw image data
     * @param {format} Export format
     * @param {quality} Export quality
     * @return Base64 exported String
    ###
    @_export = (data, format, quality) =>
      @exportCanvas.width = data.width
      @exportCanvas.height = data.height
      @exportCanvasCtx.putImageData data, 0, 0
      @exportCanvas.toDataURL format, quality

    ###*
     * Send a key frame if necessary
     * Conditions: 
     * - No key frame
     * - Estimated quality superior to prior
    ###
    @_processKeyFrame = =>
      if @keyframe
        keyframeQuality = @_getQuality()

        if keyframeQuality <= @keyframeQuality
          return false
        else
          @keyframeQuality = keyframeQuality
      else
        @keyframe = true
        @keyframeQuality = @options.lowQuality

      console.debug 'Send keyframe'

      keyFrame =
        k: true
        d: @_dataURItoBlob @cvs.toDataURL(@options.exportFormat, @keyframeQuality)
        w: @width
        h: @height
        t: new Date().getTime().toString()

      @mismatchesCount = null
      @sending++
      @hasSent = true
      @framesToSend++
      @stream.write keyFrame

      return true

    ###*
     * Process a frame at x,y 
     * Updated conditions: 
     * - Mismatches detected
     * - Estimated quality superior to prior
    ###
    @_processFrame = (xOffset, yOffset) =>
      key = xOffset.toString() + yOffset.toString()
      updatedFrame = null
        
      lastFrame = @lastFrames[key]
      newFrame = @ctx.getImageData(xOffset * @constructor.TILE_SIZE, yOffset * @constructor.TILE_SIZE, @constructor.TILE_SIZE, @constructor.TILE_SIZE)

      if lastFrame and lastFrame.data
        equal = @_equal(newFrame, lastFrame.data)
        if not equal
          lastFrame.data = newFrame
          
          unless @mismatchesCount[key]?
            @mismatchesCount[key] = 1
          else
            @mismatchesCount[key]++

        quality = @_getQuality(key)

        # console.log 'Mismatch',  @mismatchesCount[key] if @mismatchesCount? 

        if @mismatchesCount[key] > 0 or quality > lastFrame.quality
          console.log 'Compressing at rate', quality, 'vs before', lastFrame.quality
          
          lastFrame.quality = quality
          data = @_export newFrame, @options.exportFormat, quality
          updatedFrame =
            d: @_dataURItoBlob(data)
            x: xOffset
            y: yOffset

      return updatedFrame

    ###*
     * Process and send grids' frames
     * Reinit key frame if more than 80% of the screen has been modified
    ###
    @_processFrames = =>
      framesUpdates = []

      unless @mismatchesCount?
        @mismatchesCount = {}

      xOffset = -1
      yOffset = 0
      mismatchesCount = 0 

      # Stop conditions : 80% of the screen modified, entire grid browsed
      stop = false
      while not stop
        xOffset++
        if @width - xOffset * @constructor.TILE_SIZE <= 0
          xOffset = 0
          yOffset++
          if @height - yOffset * @constructor.TILE_SIZE <= 0
            stop = true

        if not stop
          updatedFrame = @_processFrame(xOffset, yOffset)

          if updatedFrame?
            framesUpdates.push updatedFrame
            mismatchesCount++
              
            if mismatchesCount >= @gridSize * 0.8
              console.log 'Generate key frame, total mismatches', mismatchesCount
              @keyframe = false 
              stop = true

      if not @sending and framesUpdates.length and @keyframe
        console.debug "Sending diff"
        for frame in framesUpdates
          key = frame.x.toString() + frame.y.toString()
          delete @mismatchesCount[key]
          frame.t = new Date().getTime().toString()
          @sending++
          @hasSent = true
          @framesToSend++
          @stream.write frame

    ###*
     * Take a snapshot of each modified part of the screen
    ###
    @_snap = =>   
      return if not @started

      if @stream and @stream.writable and (not @sending or @keyFrame)
        @ctx.drawImage @video, 0, 0, @width, @height

        if not @_processKeyFrame()
          @_processFrames()

      @_snapInterval = setTimeout @_snap, 10

    @_takeScreenshot = =>
      screenshot = @ctx.getImageData(0, 0, @width, @height)
      exportedScreenshot = @_export screenshot, @options.exportFormat, 1.0
      @trigger 'screenshot-result', exportedScreenshot

    ###*
     * Convert base64 to raw binary data held in a string.
     * Doesn't handle URLEncoded DataURIs
     * @param {dataURI} ASCII Base64 string to encode
     * @return {ArrayBuffer} ArrayBuffer representing the input string in binary
    ###
    @_dataURItoBlob = (dataURI) ->
      byteString = undefined
      if dataURI.split(',')[0].indexOf('base64') >= 0
        byteString = atob(dataURI.split(',')[1])
      else
        byteString = unescape(dataURI.split(',')[1])
  
      # separate out the mime component
      mimeString = dataURI.split(',')[0].split(':')[1].split(';')[0]
  
      # write the bytes of the string to an ArrayBuffer
      ab = new ArrayBuffer(byteString.length)
      ia = new Uint8Array(ab)
      i = 0
  
      while i < byteString.length
        ia[i] = byteString.charCodeAt(i)
        i++
  
      # write the ArrayBuffer to a blob, and you're done
      ab

    ###*
     * Create and register handlers to binary client
    ###
    @_createBinaryClient = =>
      if not @client
        @client = BinaryClient(@serverUrl)

        @client.on 'open', @_openHandler
        @client.on 'close', @_closeHandler
        @client.on 'error', @_errorHandler

    ###*
     * Handler when client's connection opened
    ###
    @_openHandler = =>
      console.log 'Stream open'
      @stream = @client.createStream
        room: @room
        type: 'write'

      @stream.on 'data', @_frameReceivedHandler
      @stream.on 'error', @_errorHandler

      @stream.on 'close', @_closeHandler 
      @trigger 'open'

    ###*
     * Handler when client's connection closed
    ###
    @_closeHandler = =>
      @stop()
      @trigger 'close'

    ###*
     * Handler when error
    ###
    @_errorHandler = (e) =>
      @stop()
      console.error e
      @trigger 'error', e

    ###*
     * Handler when server respond to a frame
    ###
    @_frameReceivedHandler = (data) =>
      if data is @constructor.SIGNALS.SERVER_FRAME_RECEIVED
        console.debug 'Received'
        @framesSent++
        @sending--
      else if data is @constructor.SIGNALS.RECEIVER_SCREENSHOT_REQUEST
        @_takeScreenshot()

    ###*
     * Handler when screen stream is ready to play
    ###
    @_canPlayHandler = =>
      @keyFrame = null
      @streaming = true

      @cvs.setAttribute 'width', @width
      @cvs.setAttribute 'height', @height

      @gridSize = Math.round(@width / @constructor.TILE_SIZE) * Math.round(@height / @constructor.TILE_SIZE)

      @framesSent = 0
      @framesToSend = 0

      @lastFrames = {}

      xOffset = 0
      yOffset = 0
      stop = false
      while not stop
        stop = do () =>
          key = xOffset.toString() + yOffset.toString()
        
          @lastFrames[key] = 
            data: @ctx.getImageData(xOffset * @constructor.TILE_SIZE, yOffset * @constructor.TILE_SIZE, @constructor.TILE_SIZE, @constructor.TILE_SIZE)
          
          xOffset++
          if @width - xOffset * @constructor.TILE_SIZE <= 0
            xOffset = 0
            yOffset++
            if @height - yOffset * @constructor.TILE_SIZE <= 0
              yOffset = 0
              return true
            return false
          return false

      @_snapInterval = setTimeout @_snap, 0
      @_processNetworkStatsInterval = setTimeout @_processNetworkStats, 0

      @on 'screenshot', @_takeScreenshot

      @_createBinaryClient()

      @trigger 'canplay'

    ###*
     * Handler when screen stream ends
    ###
    @_onEndedHandler = (e) =>
      console.debug 'onended'
      @trigger 'onended'  
      @stop()

    ###*
     * Handler when get user media request succeeds
    ###
    @_getUserMediaSuccess = (s) =>
      @streaming = true
      @localStream = s
      @localStream.onended = @_onEndedHandler

      @video.src = window.URL.createObjectURL(@localStream)

    @_init()

    ###*
     * Handler when get user media request succeeds
    ###
    @_getUserMediaError = (e) =>
      @trigger 'getUserMediaError', e
      @_errorHandler(e)

  ###*
   * Start transmission, ask get user media screen
  ###
  start: ->
    if @started
      return

    @started = true 

    @_init()

    # Seems to only work over SSL.
    navigator.getUserMedia = navigator.webkitGetUserMedia or navigator.getUserMedia
    navigator.getUserMedia
      video:
        mandatory:
          chromeMediaSource: 'screen'
          maxWidth: @width
          maxHeight: @height
      @_getUserMediaSuccess
      @_getUserMediaError

    @video.addEventListener 'canplay', @_canPlayHandler, false

  ###*
   * Stop transmission, unregister events' handlers
  ###
  stop: ->
    if not @started
      return

    @started = false

    @_init()
    
    # Unregister events handlers
    if @client?
      @client.off 'open', @_openHandler
      @client.off 'close', @_closeHandler
      @client.off 'error', @_errorHandler
      @client.close()
      @client = null

    if @stream?
      @stream.off 'data', @_frameReceivedHandler
      @stream.off 'error', @_errorHandler
      @stream = null

    if @localStream
      @localStream.onended = null
      @localStream.stop()
      @localStream = null

    @off 'screenshot', @_takeScreenshot  
    @video.removeEventListener 'canplay', @_canPlayHandler

      





