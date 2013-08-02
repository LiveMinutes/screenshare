class window.DemoReceive extends Base
	_start = null
	_stop = null
	_openHandler = null
	
	constructor: (serverUrl, canvas) ->
		@maxRooms = 100
		@maxReceivers = 5
		@roomId = 1
		@canvas = canvas

		@latences = []

		_firstKeyframeHandler = =>
			@canvas.style.display = "block";

		_endHandler = =>
			clearInterval @_processLatence

		_transmitterLeftHandler = ->
			console.log 'Transmitter has left'

		_transmitterJoinHandler = ->
			console.log 'Transmitter has joined'

		_createReceiver = (room, canvas) ->
			receiver = new ScreenSharingReceiver serverUrl, room, canvas
			receiver.on 'firstKeyframe', _firstKeyframeHandler
			receiver.on 'transmitterLeft', _transmitterLeftHandler
			receiver.on 'transmitterJoin', _transmitterJoinHandler
			receiver.on 'error', _endHandler
			receiver.on 'close', _endHandler

			return receiver

		_storeLatence = (latence) =>
			@latences.push latence

		@_processLatence = =>
			unless @latences.length
				@_processLatenceInterval = setTimeout @_processLatence, 1000
				return
			
			sum = @latences.reduce (t, s) -> t + s
			@avgLatence = sum/@latences.length

			#console.log 'Avg:', @avgLatence
			@latenceShow.textContent = @avgLatence

		_addReceivers = =>
			return if @roomId >= @maxRooms

			@_processLatence()
			@latences.length = 0
			@avgLatence = 0
			
			limit = @roomId + 5
			while @roomId <= limit
				receiverCount = 0
				console.debug "Add", @maxReceivers ,"receivers in room", @roomId		
				while receiverCount < @maxReceivers
					receiver = _createReceiver(@roomId, @canvas)
					receiver.on 'stats', _storeLatence
					receiver.start()
					@receivers.push receiver
					receiverCount++
				@roomId++

			setTimeout _addReceivers, 60 * 1000

		_start= =>	
			@latenceShow = document.createElement 'p'
			document.body.appendChild @latenceShow

			@receivers = []

			roomId = 1

			setTimeout _addReceivers, 0

		_stop= =>
			_endHandler()

			for receiver in @receivers
				receiver.stop()
				receiver = null

			@receiver = null

		_start()