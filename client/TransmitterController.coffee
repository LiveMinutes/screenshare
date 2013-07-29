class window.ScreenSharingTransmitter extends Base
  ### Private members ###
  _snap = null
  _dataURItoBlob = null
  _canPlayHandler = null
  _snapInterval = null
  _processNetworkStatsInterval = null
  _processNetworkStats = null
  _getQuality = null
  _equal = null
  _export = null

  ### Defaults options ###
  defaults:
    exportFormat: 'image/jpeg'
    highQuality: 0.8
    mediumQuality: 0.3
    lowQuality: 0.1
    width: if screen.width <= 1024 then screen.width else 1024
    height: false
  
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

    @streaming = false
    @sending = 0
    @lastFrames = {}
    @sentFrameRate = []
    @mismatchesCount = {}

    @cvs = document.createElement 'canvas'
    @ctx = @cvs.getContext '2d'
    @video = document.createElement 'video'

    ###*
    * Detect if a screen is static
    ###
    _processStatic = =>
      @avgSendFrames = 0 if @sending is 0 and not @hasSent
      _processStaticInterval = setTimeout _processStatic, 50

    ###*
     * Process the network stats (frames to send / sent)
    ###
    _processNetworkStats = =>
      if not @hasSent
        _processNetworkStatsInterval = setTimeout _processNetworkStats, 1000
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

      _processNetworkStatsInterval = setTimeout _processNetworkStats, 1000

    ###*
     * Return the correct quality regarding network quality and screen activity
     * @param {key} Frame's key
     * @return The correct quality
    ###
    _getQuality = (key) =>
      quality = @options.highQuality

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
    _equal = (a, b, tolerance) ->
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
    _export = (data, format, quality) ->
      canvas = document.createElement 'canvas'
      canvas.width = data.width
      canvas.height = data.height
      context = canvas.getContext("2d")
      context.putImageData data, 0, 0
      canvas.toDataURL format, quality

    ###*
     * Take a snapshot of each modified part of the screen
    ###
    _snap = =>        
      @ctx.drawImage @video, 0, 0, @options.width, @options.height

      if @stream and @stream.writable and (not @sending or @keyFrame)
        # Sending a Keyframe
        if @keyFrame
          keyFramequality = _getQuality()
        else 
          keyFramequality = @options.lowQuality
          
        if not @keyFrame or keyFramequality > @keyFrame.quality
          @keyFrame = 
            data: @ctx.getImageData 0, 0, @options.width, @options.height
            quality: keyFramequality

          keyFrame =
            k: true
            d: _dataURItoBlob @cvs.toDataURL(@options.exportFormat, keyFramequality)
            w: @options.width
            h: @options.height
            t: new Date().getTime().toString()

          @mismatchesCount = {}
          console.log 'Send keyframe', keyFrame
          @sending++
          @hasSent = true
          @framesToSend++
          @stream.write keyFrame
        # Sending diff frames
        else
          do () =>
            framesToSend = 0
            xOffset = 0
            yOffset = 0
            
            framesUpdates = do () =>
              framesUpdates = []
              stop = false
              while not stop
                stop = do () =>
                  key = xOffset.toString() + yOffset.toString()
                
                  lastFrame = @lastFrames[key]
                  newFrame = @ctx.getImageData(xOffset * @constructor.TILE_SIZE, yOffset * @constructor.TILE_SIZE, @constructor.TILE_SIZE, @constructor.TILE_SIZE)

                  if lastFrame and lastFrame.data
                    equal = _equal(newFrame, lastFrame.data)
                    if not equal
                      lastFrame.data = newFrame
                      unless @mismatchesCount[key]?
                        @mismatchesCount[key] = 1
                      else
                        @mismatchesCount[key]++

                        mismatchesCount = 0
                        for key, mismatchesCountKey of @mismatchesCount 
                          if mismatchesCountKey >= 1
                            mismatchesCount++

                        if mismatchesCount >= @gridSize * 0.8
                          console.log 'Total mismatches', mismatchesCount
                          @mismatchesCount = {}
                          @keyFrame = null 
                          return true

                    quality = _getQuality(key)

                    console.log 'Mismatch',  @mismatchesCount[key]

                    if not @sending and (@mismatchesCount[key] > 0 or quality > lastFrame.quality)
                      console.log 'Compressing at rate', quality, 'vs before', lastFrame.quality
                      
                      lastFrame.quality = quality
                      data = _export newFrame, @options.exportFormat, quality
                      framesUpdates.push
                        d: _dataURItoBlob(data)
                        x: xOffset
                        y: yOffset
                       
                  xOffset++
                  if @options.width - xOffset * @constructor.TILE_SIZE <= 0
                    xOffset = 0
                    yOffset++
                    if @options.height - yOffset * @constructor.TILE_SIZE <= 0
                      yOffset = 0
                      return true
                    return false
                  return false

              return framesUpdates

            if @keyFrame and not @sending
              console.debug "Sending diff"
              for frame in framesUpdates
                key = frame.x.toString() + frame.y.toString()
                @mismatchesCount[key] = 0
                frame.t = new Date().getTime().toString()
                @sending++
                @hasSent = true
                @framesToSend++
                @stream.write frame

      _snapInterval = setTimeout _snap, 10

    ###*
     * Convert base64 to raw binary data held in a string.
     * Doesn't handle URLEncoded DataURIs
     * @param {dataURI} ASCII Base64 string to encode
     * @return {ArrayBuffer} ArrayBuffer representing the input string in binary
    ###
    _dataURItoBlob = (dataURI) ->
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

    _createBinaryClient = =>
      if not @client
        @client = BinaryClient(@serverUrl)

        @client.on 'open', =>
          console.log 'Stream open'
          @stream = @client.createStream
            room: @room
            type: 'write'

          @stream.on 'data', (data) =>
            if data
              console.log 'Received'
              @framesSent += data
              @sending -= data

          @stream.on 'error', (e) =>
            @stop()
            @trigger 'error', e

          @stream.on 'close', =>
            if @started
              @stop()
              @trigger 'close'

          @trigger 'open'

        @client.on 'close', =>
          if @started
            @stop()
            @trigger 'close'

        @client.on 'error', (e) =>
          @stop()
          @trigger 'error', e

    _canPlayHandler = =>
      @startTime = new Date().getTime()
      @keyFrame = false
      @streaming = true

      @options.height = @video.videoHeight / (@video.videoWidth/@options.width)
      @video.setAttribute 'width', @options.width
      @video.setAttribute 'height', @options.height
      @cvs.setAttribute 'width', @options.width
      @cvs.setAttribute 'height', @options.height

      @gridSize = Math.round(@options.width / @constructor.TILE_SIZE) * Math.round(@options.height / @constructor.TILE_SIZE)

      @framesSent = 0
      @framesToSend = 0

      xOffset = 0
      yOffset = 0
      stop = false
      while not stop
        stop = do () =>
          key = xOffset.toString() + yOffset.toString()
        
          @lastFrames[key] = 
            data: @ctx.getImageData(xOffset * @constructor.TILE_SIZE, yOffset * @constructor.TILE_SIZE, @constructor.TILE_SIZE, @constructor.TILE_SIZE)
          
          xOffset++
          if @options.width - xOffset * @constructor.TILE_SIZE <= 0
            xOffset = 0
            yOffset++
            if @options.height - yOffset * @constructor.TILE_SIZE <= 0
              yOffset = 0
              return true
            return false
          return false

      _snapInterval = setTimeout _snap, 0
      _processNetworkStatsInterval = setTimeout _processNetworkStats, 0
      _processStaticInterval = setTimeout _processStatic, 0

      _createBinaryClient()

      @trigger 'canplay'

  start: (e) ->
    if @started
      return

    @started = true    

    # Seems to only work over SSL.
    navigator.getUserMedia = navigator.webkitGetUserMedia or navigator.getUserMedia
    navigator.getUserMedia
      video:
        mandatory:
          chromeMediaSource: 'screen'
      (s) =>
        @streaming = true
        @localStream = s
        @localStream.onended = (e) =>
          if @started
            console.log 'onended'
            @trigger 'onended'

        @video.src = window.URL.createObjectURL(@localStream);
        @video.autoplay = true
      (e) =>
        console.log('Error', e)
        @trigger 'error', e

    @video.addEventListener 'canplay', _canPlayHandler, false

  stop: ->
    if not @started
      return

    @started = false

    if _snapInterval and @localStream
      clearInterval _snapInterval
      _snapInterval = false

      clearInterval _processNetworkStatsInterval
      _processNetworkStatsInterval = false

      clearInterval _processStaticInterval
      _processStaticInterval = false

      @sending = 0
      @streaming = false
      @localStream.stop()
      @video.removeEventListener 'canplay', _canPlayHandler
      
      if @client
        @client.close()
        @client = null
        @stream = null





