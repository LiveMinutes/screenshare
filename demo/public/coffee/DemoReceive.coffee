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

		_endHandler = =>
			@button.removeEventListener 'click', _stop
			@button.addEventListener 'click', _start
			@button.textContent = 'Join session'

			@canvas.style.display = "none";

			@receiver.off 'firstKeyframe', _firstKeyframeHandler

		_transmitterLeftHandler = ->
			console.log 'Transmitter has left'

		_transmitterJoinHandler = ->
			console.log 'Transmitter has joined'

		_start= =>	
			@button.textContent = 'Leave session'
			@button.removeEventListener 'click', _start
			@button.addEventListener 'click', _stop

			@receiver.on 'firstKeyframe', _firstKeyframeHandler
			@receiver.on 'transmitterLeft', _transmitterLeftHandler
			@receiver.on 'transmitterJoin', _transmitterJoinHandler
			@receiver.on 'error', _endHandler
			@receiver.on 'close', _endHandler
			@receiver.start()

		_stop= =>
			_endHandler()
			@receiver.stop()

		@button.addEventListener 'click', _start