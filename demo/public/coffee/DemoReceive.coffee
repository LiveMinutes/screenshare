class window.DemoReceive
  draw = null

  constructor: (serverUrl, room, canvasKeyFrame, canvasDiff) ->
    @canvasKeyFrame = canvasKeyFrame
    @canvasDiff = canvasDiff

    @last_key_frame = false

    @receiver = new ScreenSharingReceiver serverUrl, room
    @receiver.on "snap", (e) =>
      data = e.data
      if (data.k)
        draw(data)
      else
        draw(data)

    draw = (data) =>
      if data.k
        canvas = @canvasKeyFrame
        @canvasDiff.getContext("2d").clearRect 0, 0, @canvasDiff.width, @canvasDiff.height
      else
        canvas = @canvasDiff

      image = new Image()
      image.src = data.d
      image.onload = ->
        #if (!data.k && !last_key_frame) return;
        width = data.w
        height = data.h

        if canvas.width isnt width or canvas.height isnt height
          canvas.width = width
          canvas.height = height

        context = canvas.getContext("2d")
        context.clearRect data.x, data.y, data.w, data.h
        context.drawImage this, data.x, data.y, data.w, data.h

      @last_key_frame = true
