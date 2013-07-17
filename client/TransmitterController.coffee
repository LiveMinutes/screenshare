class window.ScreenSharingTransmitter extends Base
  snap = null
  dataURItoBlob = null
  canPlayHandler = null
  TILE_SIZE = 256

  defaults:
    eventNS: "screensharing"
    exportFormat: 'image/jpeg'
    compression: 0.8
    width: screen.width * 0.8
    height: false
  
  constructor: (serverUrl, room, options) ->
    @serverUrl = serverUrl
    @room = room
    super options

    @streaming = false
    @sending = false
    @lastFrames = null
    @frameDropped = 0

    @cvs = document.createElement("canvas")
    @ctx = @cvs.getContext "2d"
    @video = document.createElement 'video'

    timer = =>
      console.log "Frames sent", @framesSent
      @framesSent = 0
      @counting = false
    snap = =>
      if @sending
        console.log "dropped frame"
#        if @frameDropped > 25
#          @frameDropped = 0
#          @sending = false
#        else
#          @frameDropped++
        return

      if not @counting
        @counting = true
        setTimeout(timer, 1000)
        
      @ctx.drawImage @video, 0, 0, @options.width, @options.height

      if @stream and @stream.writable
        @sending = true
        if not @keyFrame
            frame =
              d: dataURItoBlob @cvs.toDataURL(@options.exportFormat, @options.compression)
              w: @options.width
              h: @options.height
              k: true
            console.log 'Send keyframe', frame
            @stream.write frame
            @keyFrame = true
        else
          xOffset = 0
          yOffset = 0
          framesUpdate = []
          while not stop
            key = xOffset.toString() + yOffset.toString()
            lastFrame = @lastFrames[key]
            newFrame = @ctx.getImageData(xOffset * TILE_SIZE, yOffset * TILE_SIZE, TILE_SIZE, TILE_SIZE)

            if !imagediff.equal(newFrame, lastFrame) and @stream and @stream.writable
              data = imagediff.toCanvas(newFrame).toDataURL @options.exportFormat, @options.compression
              @lastFrames[key] = newFrame
              @framesSent++
              framesUpdate.push
                d: dataURItoBlob(data)
                x: xOffset
                y: yOffset

            xOffset++
            if xOffset*TILE_SIZE >= @options.width
              xOffset = 0

              yOffset++
              if yOffset*TILE_SIZE >= @options.height
                yOffset = 0
                stop = true

          #console.log "Stop X", xOffset
          #console.log "Stop Y", xOffset

          if framesUpdate.length
            console.log 'Send frame', framesUpdate
            @stream.write framesUpdate
            setTimeout (=>
              if @sending
                @sending = false
              ), 500
      #@sending = false



      ###if @lastFrame
        diff = imagediff.diff(new_frame, @lastFrame)
        r_width = diff.maxXY[0] - diff.minXY[0]
        r_height = diff.maxXY[1] - diff.minXY[1]
        r_x = diff.minXY[0]
        r_y = diff.minXY[1]
        console.log "% diff", (r_width * r_height) / (@options.width * @options.height)
        @keyFrame = (r_width * r_height) / (@options.width * @options.height) > 0.50

      if @keyFrame or not @lastFrame
        console.log "Key frame"
        r_width = @options.width
        r_height = @options.height
        r_x = 0
        r_y = 0
  
        data = @cvs.toDataURL("image/jpeg", @options.compression) # can also use 'image/png'
        @keyFrame = new_frame
      else
        data = imagediff.toCanvas(@ctx.getImageData(r_x, r_y, r_width, r_height)).toDataURL @options.exportFormat, @options.compression

      @lastFrame = new_frame
      @sending = true

      if @stream and @stream.writable
        @stream.write
          d: dataURItoBlob(data)
          w: r_width
          h: r_height
          x: r_x
          y: r_y
          k: (@keyFrame is @lastFrame)###


    dataURItoBlob = (dataURI, callback) ->
      # convert base64 to raw binary data held in a string
      # doesn't handle URLEncoded DataURIs

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
            if data is 1
              console.log "Received"
              @sending = false

          @trigger "socketOpen"

        @client.on "close", =>
          @stop()
          @client = null
          @trigger "socketClose"

    canPlayHandler = =>
      @keyFrame = false
      @streaming = true

      @options.height = @video.videoHeight / (@video.videoWidth/@options.width)
      @video.setAttribute 'width', @options.width
      @video.setAttribute 'height', @options.height
      @cvs.setAttribute 'width', @options.width
      @cvs.setAttribute 'height', @options.height

      @framesSent = 0
      stop = false
      xOffset = 0
      yOffset = 0
      @lastFrames = {}
      while not stop
        key = xOffset.toString() + yOffset.toString()
        lastFrame = @ctx.getImageData(xOffset*TILE_SIZE, yOffset*TILE_SIZE, TILE_SIZE, TILE_SIZE)
        @lastFrames[key] = lastFrame

        xOffset++
        if xOffset*TILE_SIZE >= @options.width
          xOffset = 0

          yOffset++
          if yOffset*TILE_SIZE >= @options.height
            yOffset = 0
            stop = true

      console.log "Stop X", xOffset
      console.log "Stop Y", xOffset

      @timer = setInterval(snap, 10)

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
      @sending = false
      @streaming = false
      @localStream.stop()
      @video.removeEventListener "canplay", canPlayHandler
      @stream.end()





