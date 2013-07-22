class window.ScreenSharingTransmitter extends Base
  ### Private members ###
  _snap = null
  _dataURItoBlob = null
  _canPlayHandler = null
  _processNetworkStatsInterval = null
  _processNetworkStats = null
  _getQuality = null

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
    @sending = false
    @lastFrames = {}
    @frameDropped = 0

    @sentFrameRate = []

    @diffFrames = {}
    @avgDiffFrames = {}

    @cvs = document.createElement 'canvas'
    @ctx = @cvs.getContext '2d'
    @video = document.createElement 'video'

    _processStatic = =>
      @avgSendFrames = 0 if not @sending and not @hasSent
      _processStaticInterval = setTimeout _processStatic, 50

    ###*
     * Process the network stats (frames to send / sent)
    ###
    _processNetworkStats = =>
      if not @hasSent
        #unless @notSent? then @notSent = 0 else @notSent++
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
     * @param {key} Key of the frame to sample
     * @return The correct quality
    ###
    _getQuality = (key) =>
      quality = @options.highQuality

      if @avgDiffFrames[key] > 2 or (@avgSendFrames > 0 and @avgSendFrames <= 50 or @avgSendFrames >= 150)
        console.log key, 'Low quality', @options.lowQuality
        quality = @options.lowQuality
      else if @avgDiffFrames[key] > 1 or (@avgSendFrames > 0 and @avgSendFrames <= 90 or @avgSendFrames >= 110)
        console.log key, 'Medium quality', @options.mediumQuality
        quality = @options.mediumQuality

      return quality

    ###*
     * Take a snapshot of each modified part of the screen
    ###
    _snap = =>        
      @ctx.drawImage @video, 0, 0, @options.width, @options.height

      if @stream and @stream.writable
        # Sending a Keyframe
        if not @keyFrame
            frame =
              d: _dataURItoBlob @cvs.toDataURL(@options.exportFormat, @options.compression)
              w: @options.width
              h: @options.height
              k: true
            console.log 'Send keyframe', frame
            @stream.write frame
            @keyFrame = true
        # Sending diff frames
        else
          do () =>
            framesUpdate = do () =>
              framesUpdate = []
              
              xOffset = 0
              yOffset = 0
              stop = false
              while not stop
                stop = do () =>
                  key = xOffset.toString() + yOffset.toString()
                
                  lastFrame = @lastFrames[key]
                  newFrame = @ctx.getImageData(xOffset * @constructor.TILE_SIZE, yOffset * @constructor.TILE_SIZE, @constructor.TILE_SIZE, @constructor.TILE_SIZE)

                  if lastFrame and lastFrame.data
                    equal = imagediff.equal(newFrame, lastFrame.data)
                    if not equal
                      lastFrame.data = newFrame
                      unless @avgDiffFrames[key]?
                        @avgDiffFrames[key] = 0
                      else
                        @avgDiffFrames[key]++

                    quality = _getQuality(key)

                    console.log 'Mismatch',  @avgDiffFrames[key]

                    if not @sending and (@avgDiffFrames[key] > 0 or quality > lastFrame.quality)
                      console.log 'Compressing at rate', quality, 'vs before', lastFrame.quality
                      
                      if not @sending
                        lastFrame.quality = quality
                        data = imagediff.toCanvas(newFrame).toDataURL @options.exportFormat, quality
                        frame = []
                        frame.push
                          d: _dataURItoBlob(data)
                          x: xOffset
                          y: yOffset
                          t: new Date().getTime().toString()
                        if not @sending and @stream and @stream.writable
                          # console.log 'Send frame', framesUpdate
                          @sending = true    
                          @hasSent = true
                          @framesToSend += framesUpdate.length
                          @stream.write frame

                        @avgDiffFrames[key] = 0
                    
                  xOffset++
                  if @options.width - xOffset * @constructor.TILE_SIZE <= 0
                    xOffset = 0
                    yOffset++
                    if @options.height - yOffset * @constructor.TILE_SIZE <= 0
                      yOffset = 0
                      return true
                    return false
                  return false
              return framesUpdate

            #console.log 'Stop X', xOffset
            #console.log 'Stop Y', xOffset

            # if not @sending and framesUpdate.length and @stream and @stream.writable
            #   # console.log 'Send frame', framesUpdate
            #   @sending = true    
            #   @hasSent = true
            #   @framesToSend += framesUpdate.length
            #   @stream.write framesUpdate
            # @timestamp = timestamp
      @timer = setTimeout(_snap, 10)

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
            console.log 'Received'
            @framesSent += data
            @sending = false

          @trigger 'socketOpen'

        @client.on 'close', =>
          @stop()
          @client = null
          @trigger 'socketClose'

    _canPlayHandler = =>
      @startTime = new Date().getTime()
      @keyFrame = false
      @streaming = true

      @options.height = @video.videoHeight / (@video.videoWidth/@options.width)
      @video.setAttribute 'width', @options.width
      @video.setAttribute 'height', @options.height
      @cvs.setAttribute 'width', @options.width
      @cvs.setAttribute 'height', @options.height

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

      @timer = setTimeout _snap, 0
      _processNetworkStatsInterval = setTimeout _processNetworkStats, 0
      _processStaticInterval = setTimeout _processStatic, 0

      _createBinaryClient()

      @trigger 'canplay'

  start: (e) ->
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
          console.log 'onended'
          @trigger 'onended'

        @video.src = window.URL.createObjectURL(@localStream);
        @video.autoplay = true
      (e) =>
        console.log('Error', e)
        @trigger 'error', {error: e}

    @video.addEventListener 'canplay', _canPlayHandler, false

  stop: ->
    if @timer and @localStream
      clearInterval @timer
      @timer = false

      clearInterval _processNetworkStatsInterval
      _processNetworkStatsInterval = false

      @sending = false
      @streaming = false
      @localStream.stop()
      @video.removeEventListener 'canplay', _canPlayHandler
      if @client
        @client.close(10, '')
        @client = null





