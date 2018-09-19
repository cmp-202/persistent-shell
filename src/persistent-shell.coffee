#================================
#  SSH2Shel
#================================
# Description
# SSH2 wrapper for persistant connections.
typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'
EventEmitter = require('events').EventEmitter

class SSH2Shell extends EventEmitter
   sshObj:           {}
   command:          ""
   _stream:          {}
   _data:            ""
   _buffer:          ""
   asciiFilter:      ""
   textColorFilter:  ""
   onEnd:              =>
   pipe:  (destination)=>
      @_pipes.push(destination)
      return @    
   unpipe:             =>
   
   _processData: ( data )=>
      #add host response data to buffer
      @_buffer += data
          
      #remove test coloring from responses like [32m[31m
      unless @.sshObj.disableColorFilter        
         @emit 'msg', "#{@sshObj.server.host}: text formatting filter: "+@sshObj.textColorFilter+", response is ok: "+@textColorFilter.test(@_buffer) if @sshObj.verbose
         @_buffer = @_buffer.replace(@textColorFilter, "")
        
      #remove non-standard ascii from terminal responses
      unless @.sshObj.disableASCIIFilter
         @emit 'msg', "#{@sshObj.server.host}: ASCII filter: "+@sshObj.asciiFilter+", response is ok: "+@asciiFilter.test(@_buffer) if @sshObj.verbose
         @_buffer = @_buffer.replace(@asciiFilter, "")
           
      if @command.length > 0 and @standardPromt.test(@_buffer.replace(@command.substr(0, @_buffer.length), ""))
         @emit 'msg', "#{@sshObj.server.host}: Normal prompt detected" if @sshObj.debug
         @_commandComplete() 
      #check for no command but first prompt detected
      else if @command.length < 1 and @standardPromt.test(@_buffer)
         @emit 'msg', "#{@sshObj.server.host}: First prompt detected" if @sshObj.debug
         if @sshObj.showBanner
            @sshObj.sessionText += @_buffer
            @_buffer = ""
         else
            @_buffer = ""
       
   _commandComplete: =>    
      response = @_buffer.replace(@command, "")

      @.emit 'msg', "#{@sshObj.server.host}: Command complete:\nCommand:\n #{@command}\nResponse: #{response}" if @sshObj.verbose
      #load the full buffer into sessionText and raise a commandComplete event

      @sshObj.sessionText += response
      @_buffer = ""
      @.emit 'msg', "#{@sshObj.server.host}: Raising commandComplete event" if @sshObj.debug
      @.emit 'commandComplete', @command, response 
         
   runCommand: (@command) =>
      @.emit 'msg', "#{@sshObj.server.host}: running: #{@command}" if @sshObj.verbose
      @_stream.write "#{@command}#{@sshObj.enter}"
   
   exit: =>
      @.emit 'msg', "#{@sshObj.server.host}: Exit command: Stream: close" if @sshObj.debug
      @_stream.close() #"exit#{@sshObj.enter}"
      
   _loadDefaults: =>
      @sshObj.msg = { send: ( message ) =>
         console.log message
      } unless @sshObj.msg
      @sshObj.connectedMessage  = "Connected" unless @sshObj.connectedMessage
      @sshObj.readyMessage      = "Ready" unless @sshObj.readyMessage
      @sshObj.closedMessage     = "Closed" unless @sshObj.closedMessage
      @sshObj.showBanner        = false unless @sshObj.showBanner
      @sshObj.verbose           = false unless @sshObj.verbose
      @sshObj.debug             = false unless @sshObj.debug
      @sshObj.standardPrompt    = ">$%#" unless @sshObj.standardPrompt
      @sshObj.enter             = "\n" unless @sshObj.enter #windows = "\r\n", Linux = "\n", Mac = "\r"
      @sshObj.asciiFilter       = "[^\r\n\x20-\x7e]" unless @sshObj.asciiFilter
      @sshObj.disableColorFilter = false unless @sshObj.disableColorFilter is true
      @sshObj.disableASCIIFilter = false unless @sshObj.disableASCIIFilter is true
      @sshObj.textColorFilter   = "(\[{1}[0-9;]+m{1})" unless @sshObj.textColorFilter
      @sshObj.sessionText       = "" unless @sshObj.sessionText
      @sshObj.streamEncoding    = @sshObj.streamEncoding ? "utf8"
      @sshObj.window            = true unless @sshObj.window
      @sshObj.pty               = true unless @sshObj.pty
      @asciiFilter              = new RegExp(@sshObj.asciiFilter,"g") unless @asciiFilter
      @textColorFilter          = new RegExp(@sshObj.textColorFilter,"g") unless @textColorFilter
      @standardPromt            = new RegExp("[" + @sshObj.standardPrompt + "]\\s?$") unless @standardPromt
      @_callback                = @sshObj.callback if @sshObj.callback
      @_pipes                   = []

      @onCommandComplete        = @sshObj.onCommandComplete ? ( command, response ) =>
         @.emit 'msg', "#{@sshObj.server.host}: Class.commandComplete" if @sshObj.debug

      @onEnd                    = @sshObj.onEnd ? ( sessionText, sshObj ) =>
         @.emit 'msg', "#{@sshObj.server.host}: Class.end" if @sshObj.debug

      @.on "commandComplete", @onCommandComplete  
      @.on "end", @onEnd
    
   constructor: (host) ->
      @sshObj = host
      @connection = new require('ssh2')()    
    
   _initiate: =>
      @.emit 'msg', "#{@sshObj.server.host}: initiate" if @sshObj.debug
      @_loadDefaults()    
      #event handlers        
      @.on "keyboard-interactive", ( name, instructions, instructionsLang, prompts, finish ) =>
         @.emit 'msg', "#{@sshObj.server.host}: Class.keyboard-interactive" if @sshObj.debug
         @.emit 'msg', "#{@sshObj.server.host}: Keyboard-interactive: finish([response, array]) not called in class event handler." if @sshObj.debug
         if @sshObj.verbose
            @.emit 'msg', "name: " + name
            @.emit 'msg', "instructions: " + instructions
            str = JSON.stringify(prompts, null, 4)
            @.emit 'msg', "Prompts object: " + str
      @sshObj.onKeyboardInteractive name, instructions, instructionsLang, prompts, finish if @sshObj.onKeyboardInteractive

      @.on "msg", @sshObj.msg.send ? ( message ) =>
         console.log message

      @.on "error", @sshObj.onError ? (err, type, close = false, callback) =>
         @.emit 'msg', "#{@sshObj.server.host}: Class.error" if @sshObj.debug
         if ( err instanceof Error )
            @.emit 'msg', "Error: " + err.message + ", Level: " + err.level
         else
            @.emit 'msg', "#{type} error: " + err
            callback(err, type) if callback
            @connection.end() if close

      @.on "pipe", @sshObj.onPipe ? (source) =>
         @.emit 'msg', "#{@sshObj.server.host}: Class.pipe" if @sshObj.debug

      @.on "unpipe", @sshObj.onUnpipe ? (source) =>
         @.emit 'msg', "#{@sshObj.server.host}: Class.unpipe" if @sshObj.debug 

      @.on "data", @sshObj.onData ? (data) =>
         @.emit 'msg', "#{@sshObj.server.host}: data event"  if @sshObj.debug

      @.on "stderrData", @sshObj.onStderrData ? (data) =>
         console.error data
        
   connect: (callback)=>
      @_callback = callback if callback
      @_initiate()
      @_connect()
    
   _connect: =>
      @connection.on "keyboard-interactive", (name, instructions, instructionsLang, prompts, finish) =>
         @.emit 'msg', "#{@sshObj.server.host}: Connection.keyboard-interactive" if @sshObj.debug
         @.emit "keyboard-interactive", name, instructions, instructionsLang, prompts, finish
       
      @connection.on "connect", =>
         @.emit 'msg', "#{@sshObj.server.host}: Connection.connect" if @sshObj.debug
         @.emit 'msg', @sshObj.connectedMessage

      @connection.on "ready", =>
         @.emit 'msg', "#{@sshObj.server.host}: Connection.ready" if @sshObj.debug
         @.emit 'msg', @sshObj.readyMessage

      #open a shell
      @connection.shell @sshObj.window, { pty: @sshObj.pty }, (err, @_stream) =>
         if err then @.emit 'error', err, "Shell", true
         @.emit 'msg', "#{@sshObj.server.host}: Connection.shell" if @sshObj.debug
         @sshObj.sessionText = "Connected to #{@sshObj.server.host}#{@sshObj.enter}"
         @_stream.setEncoding(@sshObj.streamEncoding);
          
         @_stream.pipe pipe for pipe in @_pipes
         @.unpipe = @_stream.unpipe
         
         @_stream.on "error", (err) =>
            @.emit 'msg', "#{@sshObj.server.host}: Stream.error" if @sshObj.debug
            @.emit 'error', err, "Stream"

         @_stream.stderr.on 'data', (data) =>              
            @.emit 'msg', "#{@sshObj.server.host}: Stream.stderr.data" if @sshObj.debug
            @.emit 'stderrData', data
        
         @_stream.on "data", (data)=>
            try
               @.emit 'data', data
               @_processData( data )
            catch e
               err = new Error("#{e} #{e.stack}")
               err.level = "Data handling"
               @.emit 'error', err, "Stream.read", true
             
         @_stream.on "pipe", (source)=>
            @.emit 'pipe', source
         
         @_stream.on "unpipe", (source)=>
            @.emit 'unpipe', source
           
         @_stream.on "finish", =>
            @.emit 'msg', "#{@sshObj.server.host}: Stream.finish" if @sshObj.debug
            @.emit 'end', @sshObj.sessionText, @sshObj
            @_callback @sshObj.sessionText if @_callback
           
         @_stream.on "close", (code, signal) =>                          
            @.emit 'msg', "#{@sshObj.server.host}: Stream.close" if @sshObj.debug
            @connection.end()
       
      @connection.on "error", (err) =>
         @.emit 'msg', "#{@sshObj.server.host}: Connection.error" if @sshObj.debug
         @.emit "error", err, "Connection"
       
      @connection.on "close", (had_error) =>
         @.emit 'msg', "#{@sshObj.server.host}: Connection.close" if @sshObj.debug
         clearTimeout @sshObj.idleTimer if @sshObj.idleTimer
         if had_error
            @.emit "error", had_error, "Connection close"
         else
            @.emit 'msg', @sshObj.closedMessage
         if @hosts.length > 0
            @_nextPrimaryHost()
         
      if @sshObj.server
         try
            @connection.connect
               host:             @sshObj.server.host
               port:             @sshObj.server.port
               forceIPv4:        @sshObj.server.forceIPv4
               forceIPv6:        @sshObj.server.forceIPv6
               hostHash:         @sshObj.server.hashMethod
               hostVerifier:     @sshObj.server.hostVerifier
               username:         @sshObj.server.userName
               password:         @sshObj.server.password
               agent:            @sshObj.server.agent
               agentForward:     @sshObj.server.agentForward
               privateKey:       @sshObj.server.privateKey
               passphrase:       @sshObj.server.passPhrase
               localHostname:    @sshObj.server.localHostname
               localUsername:    @sshObj.server.localUsername
               tryKeyboard:      @sshObj.server.tryKeyboard
               keepaliveInterval:@sshObj.server.keepaliveInterval
               keepaliveCountMax:@sshObj.server.keepaliveCountMax
               readyTimeout:     @sshObj.server.readyTimeout
               sock:             @sshObj.server.sock
               strictVendor:     @sshObj.server.strictVendor
               algorithms:       @sshObj.server.algorithms
               compress:         @sshObj.server.compress
               debug:            @sshObj.server.debug
         catch e
            @.emit 'error', "#{e} #{e.stack}", "Connection.connect", true        
      else
         @.emit 'error', "Missing connection parameters", "Parameters", false, ( err, type, close ) ->
            @.emit 'msg', @sshObj.server
            
      return @_stream

  
module.exports = SSH2Shell
