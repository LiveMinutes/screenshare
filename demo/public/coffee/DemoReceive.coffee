class window.DemoReceive
  draw = null

  constructor: (serverUrl, room, canvasKeyFrame, canvasDiff) ->
    @canvasKeyFrame = canvasKeyFrame
    @contextKeyFrame = @canvasKeyFrame.getContext('2d')

    @receiver = new ScreenSharingReceiver serverUrl, room
    @receiver.on "snap", (e) =>
      data = e.data
      if (data.k)
        drawKeyFrame(data)
      else
        drawDiff(data)

    drawKeyFrame = (keyFrame) =>
      if keyFrame.k
        width = keyFrame.w
        height = keyFrame.h

        if @canvasKeyFrame.width isnt width or @canvasKeyFrame.height isnt height
          @canvasKeyFrame.width = width
          @canvasKeyFrame.height = height

      image = new Image()
      image.src = keyFrame.d
      image.onload = =>
        @contextKeyFrame.drawImage image, 0, 0, keyFrame.w, keyFrame.h

    drawDiff = (frame) =>
      image = new Image()
      image.src = frame.d
      image.onload = =>
        @contextKeyFrame.drawImage image, frame.x*256, frame.y*256, 256, 256