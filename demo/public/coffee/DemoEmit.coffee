screenshare = @screenshare? and @screenshare or @screenshare = {}

class screenshare.DemoEmit
  _start = null
  _stop = null
  _socketOpenHandler = null
  _socketCloseHandler = null
  _showErrorMsg = null

  constructor: (serverUrl, room, buttonCapture, buttonScreenshotWindow, buttonScreenshotNotification, container, error) ->
    _showErrorMsg = (msg) =>
      @error.textContent = msg
      @error.classList.add 'show'

    _socketOpenHandler = =>
      @buttonCapture.textContent = 'Stop'
      @buttonCapture.removeEventListener 'click', _start
      @buttonCapture.addEventListener 'click', _stop

      @buttonScreenshotWindow.style.display = 'block'
      @buttonScreenshotNotification.style.display = 'block'

      @buttonScreenshotWindow.addEventListener 'click', _openScreenshotWindow
      @buttonScreenshotNotification.addEventListener 'click', _openScreenshotNotification

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
      form = new FormData()
      request = new XMLHttpRequest()
      form.append "blob", new Blob([@transmitter._dataURItoBlob(screenshot)], { type: 'image/jpeg' })
      request.open "POST", "/screenshot/" + room, true
      request.onreadystatechange = ->
        return if request.readyState isnt 4
        serverResponse = JSON.parse(request.responseText)
        window.open(['/images', room, serverResponse.fileName].join('/')) if serverResponse.fileName
      request.send(form)   

    _openScreenshotWindow = =>
      #@transmitter.trigger('screenshot')
      window.open '/screenshot/' + room, '', 'width=200,height=100'

    _openScreenshotNotification = =>
      return if @notification
      havePermission = window.webkitNotifications.checkPermission()
      if havePermission is 0
        # 0 is PERMISSION_ALLOWED
        @notification = window.webkitNotifications.createNotification("", window.document.title, "Take screenshot")
        
        @notification.onclick = =>
          @transmitter.trigger 'screenshot'
          @notification.cancel()

        @notification.onclose = =>
          @notification = null
          _openScreenshotNotification() if @started

        @notification.show()
      else
        window.webkitNotifications.requestPermission(_openScreenshotNotification)

    _start= =>
      return if @started
      @started = true 

      @transmitter.on 'open', _socketOpenHandler
      @transmitter.on 'close', _socketCloseHandler
      @transmitter.on 'error', _socketCloseHandler
      @transmitter.on 'getUserMediaError', _getUserMediaErrorHandler
      @transmitter.on 'screenshot-result', _screenshotResult
      @transmitter.start()

    _stop= =>
      return if not @started
      @started = false

      @buttonCapture.removeEventListener 'click', _stop
      @buttonCapture.addEventListener 'click', _start
      @buttonCapture.textContent = 'Capture your screen'

      @buttonScreenshotWindow.style.display = 'none'
      @buttonScreenshotNotification.style.display = 'none'

      @buttonScreenshotWindow.removeEventListener 'click', _openScreenshotWindow
      @buttonScreenshotNotification.removeEventListener 'click', _openScreenshotNotification

      if @notification?
        @notification.cancel()
        @notification = null

      @transmitter.off 'open', _socketOpenHandler
      @transmitter.off 'close', _socketCloseHandler
      @transmitter.off 'error', _socketCloseHandler
      @transmitter.off 'screenshot-result', _screenshotResult
      @transmitter.stop()

    @transmitter = new screenshare.ScreenSharingTransmitter serverUrl, room
    @buttonCapture = buttonCapture
    @buttonScreenshotWindow = buttonScreenshotWindow
    @buttonScreenshotNotification = buttonScreenshotNotification
    @container = container
    @error = error
    @buttonCapture.addEventListener 'click', _start
