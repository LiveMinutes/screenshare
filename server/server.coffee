BinaryServer = require('binaryjs').BinaryServer
EventEmitter = require('events').EventEmitter
fs = require 'fs'
https = require 'https'
express = require 'express'
path = require 'path'

class ScreenSharingServer
  defaultPort = 9001
  maxClients = 5

  _onError = null
  _onStream = null
  _closeRoom = null
  _setTransmitter = null
  _addReceiver = null

  constructor: (port) ->
    @port = port or defaultPort
    
    ###*
    * Handler error
    * @param {error} The error object
    ###
    _onError = (e) ->
      console.log e.stack, e.message

    _write = (stream, data) ->
      if stream.writable
        #console.log 'Write in', stream.screenshareId
        stream.write data
        return true
      else
        #console.error 'Stream', stream.screenshareId, 'not writable'
        return false

    ###
    * Close a room when no transmitter / receivers
    * @param {roomId} The room to close
    ###
    _closeRoom = (roomId) =>
      room = @rooms[roomId]
      console.log 'Close room?', roomId

      if room
        countReceivers = Object.keys(room.receivers).length
        leftTransmitter = room.transmitter is null
        console.log 'Left transmitter?', leftTransmitter
        console.log 'Left receivers: ', countReceivers

        if countReceivers is 0 and leftTransmitter
          console.log 'Closing room', roomId
          delete @rooms[roomId]
          return true
        else
          return false
      else
        console.error 'Room', roomId, 'does not exist'

    ###*
    * Handler when transmitter emit data
    * @param {room} The room
    * @param {transmitter} The transmitter
    * @param {data} The data emitted
    ###
    _onTransmitterDataHandler = (roomId, transmitter, frame) =>
      room = @rooms[roomId]

      if room.processFrames
          console.log 'Dropped frames'
          return

      if frame         
        room.processFrames = true

        if frame.k
          console.log 'Store keyframe', frame
          room.keyFrame = frame
          room.frames = null
          room.transmitterEE.emit 'keyframe', frame
        else
          key = frame.x.toString() + frame.y.toString()
          #console.log 'Store frame', key
          if room.frames is null
            room.frames = {}
          room.frames[key] = frame
          room.transmitterEE.emit 'frame', frame

        _write transmitter, 1

        room.processFrames = false

    ###*
    * Handler when transmitter leave
    * @param {roomId} Room ID
    ###
    _onTransmitterCloseHandler = (roomId) =>
      console.log 'Transmitter closed of room', roomId

      room = @rooms[roomId]

      room.transmitter = null
      if not _closeRoom(roomId)
        room.transmitterEE.emit 'left'

    ###
    * Set a room transmitter
    * @param {roomId} Room ID
    * @param {transmitter} Stream transmitter
    ###
    _setTransmitter = (roomId, transmitter) =>
      room = @rooms[roomId]

      transmitter.screenshareId = 'transmitter'
      console.log 'Set transmitter', transmitter.screenshareId, 'of room', roomId

      transmitter.on 'close', -> _onTransmitterCloseHandler(roomId)
      transmitter.on 'data', (data) -> _onTransmitterDataHandler(roomId, transmitter, data)
      transmitter.on 'error', _onError

      room.transmitter = transmitter

      room.transmitterEE.emit 'join'
      return true

    ###*
    * Handler when receiver emit data
    * @param {room} The room
    * @param {receiver} The receiver
    * @param {data} The data emitted
    ###
    _onReceiverDataHandler = (roomId, receiver, data) =>
      console.log 'Client data', data, 'in room', roomId
      room = @rooms[roomId]
      
      if room
        key = data.key
        timestamp = parseInt(data.t)

        console.log 'Storing client', receiver.screenshareId, 'timestamp', timestamp, 'for key', key
        if not receiver.lastTimestamp
          receiver.lastTimestamp = {}
        receiver.lastTimestamp[key] = timestamp

    ###*
    * Handler when receiver leave
    * @param {roomId} Room ID
    * @param {receiver} the receiver who left
    ###
    _onReceiverCloseHandler = (roomId, receiver) => 
      console.log 'Receiver', receiver.screenshareId, 'closed in room', roomId

      room = @rooms[roomId]
      if receiver and receiver.screenshareId?
        console.log 'Remove receiver', receiver.screenshareId, 'in room', roomId
        delete room.receivers[receiver.screenshareId]
        _closeRoom(roomId)

    ###
    * Add a room receiver
    * @param {roomId} Room ID
    * @param {receiver} Stream receiver to add
    ###
    _addReceiver = (roomId, receiver) =>
      room = @rooms[roomId]

      console.log 'Add receiver', room.nextId, 'in room', roomId

      if room.keyFrame
        console.log 'Sending keyframe', room.keyFrame
        _write receiver, room.keyFrame

      receiver.on 'close', (-> _onReceiverCloseHandler roomId, receiver)
      receiver.on 'data', ((data) -> _onReceiverDataHandler roomId, receiver, data)
      receiver.on 'error', _onError

      receiver._sendFrame = _sendFrame.bind(receiver)
      receiver._sendKeyFrame = _sendKeyFrame.bind(receiver)
      receiver._sendLeft = _sendLeft.bind(receiver)
      receiver._sendJoin = _sendJoin.bind(receiver)

      room.transmitterEE.on 'keyframe', receiver._sendKeyFrame
      room.transmitterEE.on 'frame', receiver._sendFrame
      room.transmitterEE.on 'left', receiver._sendLeft
      room.transmitterEE.on 'join', receiver._sendJoin

      receiver.screenshareId = room.nextId
      room.receivers[receiver.screenshareId] = receiver
      room.nextId++

      return receiver.screenshareId

    ###
    * Send a key frame to a receiver
    * @param {keyFrame} Key frame to send
    ###
    _sendKeyFrame = (keyFrame) ->
      console.log 'Dispatch keyframe to client', this.screenshareId
      if _write this, keyFrame
        this.lastTimestamp = null

    ###
    * Send a frame to a receiver
    * @param {frame} Frame to send
    ###
    _sendFrame = (frame) ->     
      key = frame.x.toString() + frame.y.toString()
      console.log 'Dispatch keyframe', key, 'to client', this.screenshareId
      if this.lastTimestamp? and key of this.lastTimestamp and this.lastTimestamp[key]? and parseInt(frame.t) > this.lastTimestamp[key]
        if _write this, frame
          console.log 'Frame', key ,'updated for pending request of receiver', this.screenshareId
          this.lastTimestamp[key] = null    

    ###
    * Send a transmitter left signal to a receiver
    ###
    _sendLeft = ->
      # Signal to each client that transmitter has left
      console.log 'Sending transmitter left signal to', this.screenshareId
      _write this, 0

    ###
    * Send a transmitter left signal to a receiver
    ###
    _sendJoin = ->
      # Signal to each client that transmitter has left
      console.log 'Sending transmitter join signal to', this.screenshareId
      _write this, 1



    _onStream = (stream, meta) =>
      if meta.type
        if meta.room
          if not @rooms[meta.room]
            console.log 'Create new room', meta.room
            @rooms[meta.room] =
              nextId: 0,
              keyFrame: null,
              frames: {},
              transmitter: null,
              transmitterEE: new EventEmitter(),
              receivers: {}
        else
          console.error 'Room is mandatory'
          return

        # New transmitter, only one per room
        if meta.type is 'write'
          if not @rooms[meta.room].transmitter
            _setTransmitter(meta.room, stream)
            return
          else
            console.error 'Transmitter already registered'
            return

        # New receivers, only maxClients per room
        else if meta.type is 'read'
          if Object.keys(@rooms[meta.room].receivers).length < maxClients
            _addReceiver(meta.room, stream)
            return
          else
            console.error 'Room full'
            return
      else
        console.error 'Type is mandatory'
        return

  run: (server) ->
    @binaryServer = new BinaryServer({server:server})
    @binaryServer.on 'connection', (client) ->
      client.on 'error', _onError
      client.on 'stream', _onStream

    @rooms = {}
    return @binaryServer

exports.ScreenSharingServer = ScreenSharingServer

if require.main == module
  process.on 'uncaughtException', (err) ->
    console.error((new Date).toUTCString() + ' uncaughtException:', err.message)
    console.error(err.stack)
    process.exit(1)

  app = express()
  console.log "Env", app.settings.env
  app.use express.static(path.join(__dirname, "public"))

  privateKey = fs.readFileSync('cert/' + app.settings.env + '/privatekey.key').toString()
  certificate = fs.readFileSync('cert/' + app.settings.env + '/certificate.crt').toString()
  isCa = fs.existsSync 'cert/' + app.settings.env + '/ca.crt' 
  if isCa
    ca = fs.readFileSync('cert/' + app.settings.env + '/ca.crt').toString()

  options =
    key : privateKey
    cert : certificate
    ca: ca

  server = https.createServer(options,app)

  screensharingServer = new ScreenSharingServer()
  screensharingServer.run server

  console.log 'Listen on port', screensharingServer.port
  server.listen screensharingServer.port

