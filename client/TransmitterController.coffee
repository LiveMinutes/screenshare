class window.ScreenSharingTransmitter extends Base
  TILE_SIZE = 256

  ### Private members ###
  snap = null
  dataURItoBlob = null
  canPlayHandler = null
  calculateNetworkStats = null
  getQuality = null
  sampleDiff = null

  ### Defaults options ###
  defaults:
    exportFormat: 'image/jpeg'
    highQuality: 0.8
    mediumQuality: 0.6
    lowQuality: 0.4
    width: if screen.width <= 1280 then screen.width else 1280
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

    @cvs = document.createElement("canvas")
    @ctx = @cvs.getContext "2d"
    @video = document.createElement 'video'

    ###*
     * Process the network stats (frames to send / sent)
    ###
    calculateNetworkStats = =>
      if not @hasSent
        @calculateNetworkStatsInterval = setTimeout calculateNetworkStats, 1000
        return

      @hasSent = false

      # Calculate sent frames per sec.
      ratioSent = (@framesSent/@framesToSend) * 100
      @framesToSend = 0
      @framesSent = 0

      @sentFrameRate.push(ratioSent)
      sum = @sentFrameRate.reduce (t, s) -> t + s
      @avgSendFrames = sum/@sentFrameRate.length

      console.log "Sent frames:", ratioSent
      console.log "Avg:", @avgSendFrames

      @calculateNetworkStatsInterval = setTimeout calculateNetworkStats, 1000

    ###*
     * Return the correct quality regarding network quality and screen activity
     * @param {key} Key of the frame to sample
     * @return The correct quality
    ###
    getQuality = (key) =>
      quality = @options.highQuality

      if @avgDiffFrames[key] > 60 or @avgSendFps <= 60
        console.log key, "Low quality", @options.mediumQuality
        quality = @options.lowQuality
      else if @avgDiffFrames[key] > 30 or @avgSendFps <= 30
        console.log key, "Medium quality", @options.mediumQuality
        quality = @options.mediumQuality

      return quality

    ###*
     * Sample differences on a frame
     * @param {key} Key of the frame to sample
     * @param {misMatchPercentage} Percentage of mismatch 
    ###
    sampleDiff = (key, misMatchPercentage) =>
      if not @diffFrames[key]
        @diffFrames[key] = []
      # Starting new samples series every 100 frames
      else if @diffFrames[key].length >= 100
        console.log "Reset"
        @diffFrames[key].length = 0 

      @diffFrames[key].push misMatchPercentage
      sum = @diffFrames[key].reduce (t, s) -> t + s
      @avgDiffFrames[key] = sum/@diffFrames[key].length

    ###*
     * Take a snapshot of each modified part of the screen
    ###
    snap = =>
      timestamp = new Date().getTime()
      if @sending
        console.log "dropped frame"
        @frameDropped++

        # If dead locked (no response received for the last frame)
        # TODO: Call server to check is alive
        if timestamp - @timestamp >= 500
          console.log "Unlock"
          @sending = false

        @timestamp = timestamp
        return
        
      @ctx.drawImage @video, 0, 0, @options.width, @options.height

      if @stream and @stream.writable
        # Sending a Keyframe
        if not @keyFrame
            frame =
              d: dataURItoBlob @cvs.toDataURL(@options.exportFormat, @options.compression)
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
                  newFrame = @ctx.getImageData(xOffset * TILE_SIZE, yOffset * TILE_SIZE, TILE_SIZE, TILE_SIZE)

                  if lastFrame and lastFrame.data
                    quality = getQuality(key)

                    diff = imagediff.diff(newFrame, lastFrame.data)

                    sampleDiff(key, diff.misMatchPercentage)

                    if diff.misMatchPercentage > 0 or quality > lastFrame.quality
                      console.log "Compressing at rate", quality, 'vs before', lastFrame.quality
                      data = imagediff.toCanvas(newFrame).toDataURL @options.exportFormat, quality
                      lastFrame.quality = quality
                      lastFrame.data = newFrame
                  else
                    @lastFrames[key] = 
                      data: newFrame

                  if data
                    framesUpdate.push
                      d: dataURItoBlob(data)
                      x: xOffset
                      y: yOffset
                      t: new Date().getTime().toString()

                  xOffset++
                  if @options.width - xOffset*TILE_SIZE <= 0
                    xOffset = 0
                    yOffset++
                    if @options.height - yOffset*TILE_SIZE <= 0
                      yOffset = 0
                      return true
                    return false
                  return false
              return framesUpdate

            #console.log "Stop X", xOffset
            #console.log "Stop Y", xOffset

            if framesUpdate.length and @stream and @stream.writable
              # console.log 'Send frame', framesUpdate
              @sending = true    
              @hasSent = true
              @framesToSend += framesUpdate.length
              @stream.write framesUpdate
            @timestamp = timestamp

    ###*
     * Convert base64 to raw binary data held in a string.
     * Doesn't handle URLEncoded DataURIs
     * @param {dataURI} ASCII Base64 string to encode
     * @return {ArrayBuffer} ArrayBuffer representing the input string in binary
    ###
    dataURItoBlob = (dataURI) ->
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

    createBinaryClient = =>
      if not @client
        @client = BinaryClient(@serverUrl)

        @client.on "open", =>
          console.log "Stream open"
          @stream = @client.createStream
            room: @room
            type: "write"

          @stream.on "data", (data) =>
            console.log "Received"
            @framesSent += data
            @sending = false

          @trigger "socketOpen"

        @client.on "close", =>
          @stop()
          @client = null
          @trigger "socketClose"

    canPlayHandler = =>
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

      @timer = setInterval(snap, 10)
      @calculateNetworkStatsInterval = setTimeout calculateNetworkStats, 0

      @trigger "canplay"

      createBinaryClient()

  start: (e) ->
    # Seems to only work over SSL.
    navigator.getUserMedia = navigator.webkitGetUserMedia or navigator.getUserMedia
    navigator.getUserMedia
      video:
        mandatory:
          chromeMediaSource: "screen"
      (s) =>
        @streaming = true
        @localStream = s
        @localStream.onended = (e) =>
          console.log "onended"
          @trigger "onended"

        @video.src = window.URL.createObjectURL(@localStream);
        @video.autoplay = true
      (e) =>
        console.log("Error", e)
        @trigger "error", {error: e}

    @video.addEventListener "canplay", canPlayHandler, false

  stop: ->
    if @timer and @localStream
      clearInterval @timer
      @timer = false

      clearInterval @calculateNetworkStatsInterval
      @calculateNetworkStatsInterval = false

      @sending = false
      @streaming = false
      @localStream.stop()
      @video.removeEventListener "canplay", canPlayHandler
      if @client
        @client.close(10, "")
        @client = null





