screenshare = @screenshare? and @screenshare or @screenshare = {}

class screenshare.DemoReceive
	_start = null
	_stop = null
	_openHandler = null
	
	constructor: (serverUrl, room, startButton, screenshotButton, canvas) ->
		@receiver = new screenshare.ScreenSharingReceiver serverUrl, room, canvas
		@startButton = startButton
		@screenshotButton = screenshotButton
		@canvas = canvas
		@canvas.style.display = "none";

		_firstKeyframeHandler = =>
			@canvas.style.display = "block";

		_requestScreenshot = =>
			@receiver.trigger 'screenshot'

		_endHandler = =>
			@startButton.removeEventListener 'click', _stop
			@startButton.addEventListener 'click', _start
			@startButton.textContent = 'Join session'

			@screenshotButton.removeEventListener 'click', _requestScreenshot

			@canvas.style.display = "none";

			@receiver.off 'firstKeyframe', _firstKeyframeHandler

		_transmitterLeftHandler = ->
			console.log 'Transmitter has left'

		_transmitterJoinHandler = ->
			console.log 'Transmitter has joined'

		_start= =>	
			@startButton.textContent = 'Leave session'
			@startButton.removeEventListener 'click', _start
			@startButton.addEventListener 'click', _stop

			@screenshotButton.addEventListener 'click', _requestScreenshot

			@receiver.on 'firstKeyframe', _firstKeyframeHandler
			@receiver.on 'transmitterLeft', _transmitterLeftHandler
			@receiver.on 'transmitterJoin', _transmitterJoinHandler
			@receiver.on 'error', _endHandler
			@receiver.on 'close', _endHandler
			@receiver.start()

		_stop= =>
			_endHandler()
			@receiver.stop()

		@startButton.addEventListener 'click', _start