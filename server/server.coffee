BinaryServer = require('binaryjs').BinaryServer

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
        console.error 'Write in', stream.screenshareId
        stream.write data
        return true
      else
        console.error 'Stream', stream.screenshareId, 'not writable'
        return false

    ###
    * Close a room when no transmitter / receivers
    * @param {roomId} The room to close
    ###
    _closeRoom = (roomId) =>
      room = @rooms[roomId]
      console.log 'Close room?', roomId
      if Object.keys(room.receivers).length is 0 and room.transmitter is null
        console.log 'Closing room', roomId
        room = null

    ###*
    * Handler when transmitter emit data
    * @param {room} The room
    * @param {transmitter} The transmitter
    * @param {data} The data emitted
    ###
    _onTransmitterDataHandler = (roomId, transmitter, data) =>
      room = @rooms[roomId]

      if room.processFrames
          console.log 'Dropped frames'
          return

      if data         
        room.processFrames = true
        if data.k
          console.log 'Store keyframe', data
          room.keyFrame = data
          _write transmitter, 1

          for id, client of room.receivers
            _write client, room.keyFrame
        else
          updatedFrames = {}
          okFrames = 0
          for frame in data
            key = frame.x.toString() + frame.y.toString()
            console.log 'Store frame', key, frame
            
            # Server timestamp
            frame.ts = new Date().getTime().toString()

            # Looking for clients' pending requests
            for id, client of room.receivers
              console.log 'Client', id, 'last timestamp', client.lastTimestamp
              if frame.t > client.lastTimestamp
                console.log 'Frame updated for pending request of client', id
                if not updatedFrames[id]
                  updatedFrames[id] = []
                console.log 'Updated frame', frame.x, frame.y
                setTimeout (=> client.write frame), 0

            room.frames[key] = frame
            okFrames++

          console.error 'Corrupted frames from transmitter in room', room if okFrames < data.length
          _write transmitter, okFrames

          for client of updatedFrames
            console.log 'Sending updated frames to client', client
            client.lastTimestamp = null
            # if _write room.receivers[client], updatedFrames[client]
            #   client.lastTimestamp = null
        
        room.processFrames = false

    ###*
    * Handler when transmitter leave
    * @param {roomId} Room ID
    ###
    _onTransmitterCloseHandler = (roomId) =>
      console.log 'Transmitter closed of room', roomId

      @rooms[roomId].transmitter = null
      _closeRoom(roomId)

    ###
    * Set a room transmitter
    * @param {roomId} Room ID
    * @param {transmitter} Stream transmitter
    ###
    _setTransmitter = (roomId, transmitter) =>
      room = @rooms[roomId]
      console.log 'Set transmitter', transmitter.id, 'of room', roomId

      transmitter.on 'close', -> _onTransmitterCloseHandler(roomId)
      transmitter.on 'data', (data) -> _onTransmitterDataHandler(roomId, transmitter, data)
      transmitter.on 'error', _onError

      room.transmitter = transmitter
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
      
      timestamp = parseInt(data)
      console.log 'Frames timestamp', timestamp
      updatedFrames = []
      hasSent = false
      for own key, frame of room.frames
        if frame.t > timestamp
          hasSent = true
          _write receiver, frame
      
      if hasSent
        console.log 'Sending updated frames since', timestamp
        #_write receiver, updatedFrames
      else
        console.log 'Frame not modified since', data, 'storing timestamp'
        if room.receivers[receiver.screenshareId] 
          room.receivers[receiver.screenshareId].lastTimestamp = data

    ###*
    * Handler when receiver leave
    * @param {roomId} Room ID
    * @param {receiver} the receiver who left
    ###
    _onReceiverCloseHandler = (roomId, receiver) => 
      console.log 'Receiver', receiver.screenshareId, 'closed in room', roomId

      room = @rooms[roomId]
      if receiver and receiver.screenshareId
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

      receiver.screenshareId = room.nextId
      room.receivers[receiver.screenshareId] = receiver
      room.nextId++

      return receiver.screenshareId
          

    _onStream = (stream, meta) =>
      if meta.type
        if meta.room
          console.log 'Create new room', meta.room
          if not @rooms[meta.room]
            @rooms[meta.room] =
              nextId: 0,
              keyFrame: null,
              frames: {},
              transmitter: null,
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

  run: ->
    @binaryServer = new BinaryServer({port:@port})
    @rooms = {}

    @binaryServer.on 'connection', (client) ->
      client.on 'error', _onError
      client.on 'stream', _onStream

    return @binaryServer

exports.ScreenSharingServer = ScreenSharingServer

if require.main == module
  process.on 'uncaughtException', (err) ->
    console.error((new Date).toUTCString() + ' uncaughtException:', err.message)
    console.error(err.stack)
    process.exit(1)

  new ScreenSharingServer().run()

