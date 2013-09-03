screenshare = (exports? and @) or (@screenshare? and @screenshare or @screenshare = {})

class screenshare.Base
  @TILE_SIZE: 256

  @SIGNALS:
    SERVER_FRAME_RECEIVED: 0
    TRANSMITTER_LEFT: 1
    TRANSMITTER_JOIN: 2
    RECEIVER_SCREENSHOT_REQUEST: 3

  defaults: {}

  constructor: (options) ->
    @setOptions options

  setOptions: (options) ->
    @options = merge {}, @defaults, options
    this

  on: (event, handler) ->
    @_events ?= {}
    (@_events[event] ?= []).push handler
    this

  off: (event, handler) ->
    return this unless @_events? and @_events[event]?
    for suspect, index in @_events[event] when suspect is handler
      @_events[event].splice index, 1
    this

  trigger: (event, args...) ->
    return this unless @_events? and @_events[event]?
    handler.apply this, args for handler in @_events[event]
    this

  @include = (objects...) ->
    merge @prototype, objects...
    this

  ##
  # private helper
  merge =  (target, extensions...) ->
    for extension in extensions
      for own property of extension
        target[property] = extension[property]
    target