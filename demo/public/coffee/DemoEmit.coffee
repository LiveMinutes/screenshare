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
      stop()

    _start= =>
      @transmitter.on 'socketOpen', _socketOpenHandler
      @transmitter.on 'socketClose', _socketCloseHandler
      @transmitter.start()

    _stop= =>
      @button.removeEventListener 'click', _stop
      @button.addEventListener 'click', _start
      @button.textContent = 'Capture your screen'
      @transmitter.off 'socketOpen', _socketOpenHandler
      @transmitter.off 'socketClose', _socketCloseHandler
      @transmitter.stop()

    @transmitter = new ScreenSharingTransmitter serverUrl, room
    @button = button
    @container = container
    @error = error
    @button.addEventListener 'click', _start
