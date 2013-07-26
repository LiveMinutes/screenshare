class window.DemoReceive extends Base
	_start = null
	_stop = null
	_openHandler = null
	
	constructor: (serverUrl, room, button, canvas) ->
		@receiver = new ScreenSharingReceiver serverUrl, room, canvas
		@button = button
		@canvas = canvas
		@canvas.style.display = "none";

		_firstKeyframeHandler = =>
			@canvas.style.display = "block";

		_start= =>	
			@button.textContent = 'Leave session'
			@button.removeEventListener 'click', _start
			@button.addEventListener 'click', _stop

			@receiver.on 'firstKeyframe', _firstKeyframeHandler
			@receiver.start()

		_stop= =>
			@button.removeEventListener 'click', _stop
			@button.addEventListener 'click', _start
			@button.textContent = 'Join session'

			@canvas.style.display = "none";

			@receiver.off 'firstKeyframe', _firstKeyframeHandler
			@receiver.stop()

		@button.addEventListener 'click', _start