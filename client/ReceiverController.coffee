class window.ScreenSharingReceiver extends Base
  constructor: (serverUrl, room) ->
    _arrayBufferToBase64 = (buffer) ->
      binary = ""
      bytes = new Uint8Array(buffer)
      len = bytes.byteLength
      i = 0

      while i < len
        binary += String.fromCharCode(bytes[i])
        i++

      window.btoa binary

    client = new BinaryClient(serverUrl)

    client.on "open", =>
      stream = client.createStream(
        room: room
        type: "read"
      )
      stream.on "data", (data) =>
        console.log data
        data.d = "data:image/jpeg;base64," + _arrayBufferToBase64(data.d)
        @trigger "snap", {data:data}

    client.on "error", (e) =>
      console.log "error", e
      @trigger "error"
