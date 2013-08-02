class window.ScreenSharingTransmitterMock extends ScreenSharingTransmitter
  getRandomInt: (min, max) ->
      return Math.floor(Math.random() * (max - min + 1) + min)

  drawOnCanvas: ->
    #console.log 'Draw on Canvas of transmitter room', @room
    # Each shape should be made up of between three and six curves
    @ctx.clearRect(@pos.x , @pos.y , @cvs.width , @cvs.height ) if @pos?

    @pos = {
        x : @getRandomInt(0, @cvs.width)
        y : @getRandomInt(0, @cvs.height)
    }

    @ctx.beginPath();
    @ctx.rect(@pos.x, @pos.y, 200, 100);
    @ctx.fillStyle = 'yellow';
    @ctx.fill();
    @ctx.lineWidth = 7;
    @ctx.strokeStyle = 'black';
    @ctx.stroke();

  getUserMedia: ->
    @_canPlayHandler()
    return

class window.DemoEmit
  _start = null
  _stop = null
  _socketOpenHandler = null
  _socketCloseHandler = null
  _showErrorMsg = null

  constructor: (serverUrl, room, button, container, error) ->
    _showErrorMsg = (msg) =>
      @error.textContent = msg
      @error.classList.add 'show'

    _socketOpenHandler = =>
      @button.textContent = 'Stop'
      @button.removeEventListener 'click', _start
      @button.addEventListener 'click', _stop
      @container.innerHTML = ''

    _socketCloseHandler = =>
      _stop()

    _createTransmitter = (roomId) ->
      transmitter = new ScreenSharingTransmitterMock(serverUrl, roomId)
      transmitter.on 'open', _socketOpenHandler
      transmitter.on 'close', _socketCloseHandler
      transmitter.on 'error', _socketCloseHandler
      
      return transmitter

    _addTransmitters = =>
      return if @roomId >= @maxRooms

      limit = @roomId + 5
      while @roomId <= limit
        transmitter = _createTransmitter(@roomId)
        transmitter.start()
        @transmitters.push transmitter
        @roomId++

      setTimeout _addTransmitters, 60 * 1000

    _start= ->
      setTimeout _addTransmitters, 0

    _stop= =>
      @button.removeEventListener 'click', _stop
      @button.addEventListener 'click', _start
      @button.textContent = 'Capture your screen'

      for transmitter in @transmitters
        transmitter.off 'open', _socketOpenHandler
        transmitter.off 'close', _socketCloseHandler
        transmitter.on 'error', _socketCloseHandler
        transmitter.stop()

      @transmitters = null

    @roomId = 1
    @transmitters = []
    @maxRooms = 100

    @button = button
    @container = container
    @error = error
    @button.addEventListener 'click', _start
