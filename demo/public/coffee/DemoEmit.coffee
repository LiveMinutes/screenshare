class window.DemoEmit
  _start = null
  _stop = null
  _socketOpenHandler = null
  _socketCloseHandler = null
  _showErrorMsg = null

  constructor: (serverUrl, room, buttonCapture, buttonScreenshotWindow, container, error) ->
    _showErrorMsg = (msg) =>
      @error.textContent = msg
      @error.classList.add 'show'

    _socketOpenHandler = =>
      @buttonCapture.textContent = 'Stop'
      @buttonCapture.removeEventListener 'click', _start
      @buttonCapture.addEventListener 'click', _stop

      @buttonScreenshotWindow.addEventListener 'click', _openScreenshotWindow

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
    
    _screenshotResult = (screenshot) =>
      window.open(screenshot)      

    _openScreenshotWindow = =>
      #@transmitter.trigger('screenshot')
      window.open '/screenshot/' + room, '', 'width=200,height=100'

    _start= =>
      @transmitter.on 'open', _socketOpenHandler
      @transmitter.on 'close', _socketCloseHandler
      @transmitter.on 'error', _socketCloseHandler
      @transmitter.on 'getUserMediaError', _getUserMediaErrorHandler
      @transmitter.on 'screenshot-result', _screenshotResult
      @transmitter.start()

    _stop= =>
      @buttonCapture.removeEventListener 'click', _stop
      @buttonCapture.addEventListener 'click', _start
      @buttonCapture.textContent = 'Capture your screen'

      @buttonScreenshotWindow.removeEventListener 'click', _openScreenshotWindow

      @transmitter.off 'open', _socketOpenHandler
      @transmitter.off 'close', _socketCloseHandler
      @transmitter.off 'error', _socketCloseHandler
      @transmitter.off 'screenshot-result', _screenshotResult
      @transmitter.stop()

    @transmitter = new ScreenSharingTransmitter serverUrl, room
    @buttonCapture = buttonCapture
    @buttonScreenshotWindow = buttonScreenshotWindow
    @container = container
    @error = error
    @buttonCapture.addEventListener 'click', _start
