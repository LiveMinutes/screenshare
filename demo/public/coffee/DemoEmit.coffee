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

    _socketCloseHandler = =>
      _stop()

    _getUserMediaErrorHandler = =>
      @error.textContent = 'Please enable required flag '

      flagLink = document.createElement 'a'
      flagLink.textContent = 'here'
      flagLink.href = 'chrome://flags/#enable-usermedia-screen-capture'
      flagLink.target = '_blank'

      @error.appendChild flagLink

      @error.classList.add 'show'

    _start= =>
      @transmitter.on 'open', _socketOpenHandler
      @transmitter.on 'close', _socketCloseHandler
      @transmitter.on 'error', _socketCloseHandler
      @transmitter.on 'canplay', => @container.appendChild(@transmitter.video)
      @transmitter.on 'getUserMediaError', _getUserMediaErrorHandler
      @transmitter.start()

    _stop= =>
      @button.removeEventListener 'click', _stop
      @button.addEventListener 'click', _start
      @button.textContent = 'Capture your screen'
      @transmitter.off 'open', _socketOpenHandler
      @transmitter.off 'close', _socketCloseHandler
      @transmitter.on 'error', _socketCloseHandler
      @transmitter.stop()

    @transmitter = new ScreenSharingTransmitter serverUrl, room
    @button = button
    @container = container
    @error = error
    @button.addEventListener 'click', _start
