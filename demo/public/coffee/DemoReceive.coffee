class window.DemoReceive extends Base
  constructor: (serverUrl, room, canvasKeyFrame) ->
    @receiver = new ScreenSharingReceiver serverUrl, room, canvasKeyFrame
    @receiver.start()