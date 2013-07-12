class window.ScreenSharingTransmitter extends Base
  snap = null
  dataURItoBlob = null
  canPlayHandler = null

  defaults:
    eventNS: "screensharing"
    exportFormat: 'image/jpeg'
    compression: 0.7
    width: 800
    height: false
  
  constructor: (serverUrl, room, options) ->
    @serverUrl = serverUrl
    @room = room
    super options

    @streaming = false
    @sending = false
    @lastFrame = false
    @frameDropped = 0

    @cvs = document.createElement("canvas")
    @ctx = @cvs.getContext "2d"
    @video = document.createElement 'video'

    snap = =>
      if @sending
        console.log "dropped frame"
        if @frameDropped > 25
          @frameDropped = 0
          @sending = false
        else
          @frameDropped++
        return
        
      @ctx.drawImage @video, 0, 0, @options.width, @options.height
      new_frame = @ctx.getImageData(0, 0, @options.width, @options.height)
      
      if @lastFrame
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
          k: (@keyFrame is @lastFrame)


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
          @stream = @client.createStream
            room: @room
            type: "write"

          @sending = true

          @trigger "socketOpen"

        @client.on "close", =>
          @stop
          @client = null
          @trigger "socketClose"

    canPlayHandler = =>
      @keyFrame = true
      @streaming = true

      @options.height = @video.videoHeight / (@video.videoWidth/@options.width)
      @video.setAttribute 'width', @options.width
      @video.setAttribute 'height', @options.height
      @cvs.setAttribute 'width', @options.width
      @cvs.setAttribute 'height', @options.height

      @timer = setInterval(snap, 50)

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
      @timer = false;
      @sending = false
      @streaming = false
      @localStream.stop()
      @video.removeEventListener "canplay", canPlayHandler
      @stream.end()





