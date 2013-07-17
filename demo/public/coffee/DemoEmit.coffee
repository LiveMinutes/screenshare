class window.DemoEmit
  start = null
  stop = null
  showErrorMsg = null

  constructor: (serverUrl, room, button, container, error) ->
    showErrorMsg = (msg) =>
      @error.textContent = msg
      @error.classList.add "show"

    canPlayHandler = =>
      @container.appendChild @transmitter.cvs

    start= =>
      @button.textContent = "Stop"
      @button.removeEventListener "click", start
      @button.addEventListener "click", stop
      @container.innerHTML = ""

#      @transmitter.on "canplay", canPlayHandler

      @transmitter.start()

    stop= =>
      @button.removeEventListener "click", stop
      @button.addEventListener "click", start
      @button.textContent = "Capture your screen"
      @transmitter.off "canplay", canPlayHandler
      @transmitter.stop()

    @transmitter = new ScreenSharingTransmitter serverUrl, room
    @button = button
    @container = container
    @error = error
    @button.addEventListener "click", start
