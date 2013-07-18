class window.DemoReceive
  draw = null

  constructor: (serverUrl, room, canvasKeyFrame, canvasDiff) ->
    @canvasKeyFrame = canvasKeyFrame
    @contextKeyFrame = @canvasKeyFrame.getContext('2d')

    @receiver = new ScreenSharingReceiver serverUrl, room
    @receiver.on "snap", (e) =>
      data = e.data
      if (data.k)
        drawKeyFrame(data, e.callback)
      else
        drawDiff(data, e.callback)

    drawKeyFrame = (keyFrame, callback) =>
      if keyFrame.k
        width = keyFrame.w
        height = keyFrame.h

        if @canvasKeyFrame.width isnt width or @canvasKeyFrame.height isnt height
          @canvasKeyFrame.width = width
          @canvasKeyFrame.height = height

      keyFrame.x = keyFrame.y = 0
      draw keyFrame, callback

    drawDiff = (frames, callback) =>
      for frame in frames
        draw frame
        callback() if frame is frames[frames.length-1]

    draw = (frame, callback) =>
      context = @contextKeyFrame
      image = new Image()
      image.src = frame.d
      image.onload = ->
        context.drawImage this, frame.x*256, frame.y*256, frame.w or 256, frame.h or 256
        callback if callback
