#================================
#  SSH2Shel
#================================
# Description
# SSH2 wrapper for persistant connections.
typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'
EventEmitter = require('events').EventEmitter

class SSH2Shell extends EventEmitter
   host:           {}
   command:          ""
   _stream:          {}
   _data:            ""
   _buffer:          ""
   _firstPrompt:      true
   asciiFilter:      ""
   textColorFilter:  ""
   onEnd:              =>
   pipe:  (destination)=>
      @_pipes.push(destination)
      return @
   unpipe:             =>
   
   _processData: ( data )=>
      #remove test coloring from responses like [32m[31m
      unless @.host.disableColorFilter        
         @emit 'info', "#{@host.server.host}: text formatting filter: 
            "+@host.textColorFilter+", response is ok: "+@textColorFilter.test(data) if @host.verbose
         data = data.replace(@textColorFilter, "")
        
      #remove non-standard ascii from terminal responses
      unless @.host.disableASCIIFilter
         @emit 'info', "#{@host.server.host}: ASCII filter: "+@host.asciiFilter+", response is ok: 
            "+@asciiFilter.test(data) if @host.verbose
         data = data.replace(@asciiFilter, "")
      
      @emit 'msg', data
      #add host response data to buffer
      @_buffer += data
      
      if not @_firstPrompt and @standardPromt.test(@_buffer.replace(@command.substr(0, @_buffer.length), ""))
         @emit 'info', "#{@host.server.host}: Normal prompt detected" if @host.debug
         @_commandComplete() 
      #check for no command but first prompt detected
      else if @_firstPrompt and @standardPromt.test(@_buffer)
         @emit 'info', "#{@host.server.host}: First prompt detected" if @host.debug
         @_firstPrompt = false;
         @host.sessionText += @_buffer if @host.showBanner
         @_buffer = ""
         
   _commandComplete: =>
      response = @_buffer.replace(@command, "")

      @.emit 'info', "#{@host.server.host}: Command complete:\nCommand:\n #{@command}\nResponse: #{response}" if @host.verbose
      #load the full buffer into sessionText and raise a commandComplete event
      @host.sessionText += response
      @_buffer = ""
      @.emit 'info', "#{@host.server.host}: Raising commandComplete event" if @host.debug
      @.emit 'commandComplete', @command, response
         
   runCommand: (@command) =>
      @.emit 'info', "#{@host.server.host}: running: #{@command}" if @host.verbose
      @_stream.write "#{@command}#{@host.enter}"
      if @command == "exit"
         @exit()
   
   exit: =>
      @.emit 'info', "#{@host.server.host}: Exit command: Stream: close" if @host.debug
      @_stream.close() #"exit#{@host.enter}"
      
   _loadDefaults: =>
      
      
      @host.connectedMessage  = "Connected" unless @host.connectedMessage
      @host.readyMessage      = "Ready" unless @host.readyMessage
      @host.closedMessage     = "Closed" unless @host.closedMessage
      @host.showBanner        = false unless @host.showBanner
      @host.verbose           = false unless @host.verbose
      @host.debug             = false unless @host.debug
      @host.standardPrompt    = ">$%#" unless @host.standardPrompt
      @host.enter             = "\n" unless @host.enter #windows = "\r\n", Linux = "\n", Mac = "\r"
      @host.asciiFilter       = "[^\r\n\x20-\x7e]" unless @host.asciiFilter
      @host.disableColorFilter = false unless @host.disableColorFilter is true
      @host.disableASCIIFilter = false unless @host.disableASCIIFilter is true
      @host.textColorFilter   = "(\[{1}[0-9;]+m{1})" unless @host.textColorFilter
      @host.sessionText       = "" unless @host.sessionText
      @host.streamEncoding    = @host.streamEncoding ? "utf8"
      @host.window            = true unless @host.window
      @host.pty               = true unless @host.pty
      @asciiFilter              = new RegExp(@host.asciiFilter,"g") unless @asciiFilter
      @textColorFilter          = new RegExp(@host.textColorFilter,"g") unless @textColorFilter
      @standardPromt            = new RegExp("[" + @host.standardPrompt + "]\\s?$") unless @standardPromt
      @_callback                = @host.callback if @host.callback
      @_pipes                   = []

      @onCommandComplete        = @host.onCommandComplete ? ( response ) =>
         @.emit 'info', "#{@host.server.host}: ClasscommandComplete" if @host.debug

      @onEnd                    = @host.onEnd ? ( sessionText, host ) =>
         @.emit 'info', "#{@host.server.host}: Class.end" if @host.debug

      @.on "commandComplete", @onCommandComplete
      @.on "end", @onEnd
      
      
    
   constructor: (host) ->
      @host = host
      @connection = new require('ssh2')()
    
   _initiate: =>
      @.emit 'info', "#{@host.server.host}: initiate" if @host.debug
      @_loadDefaults()
      #event handlers
      @.on "keyboard-interactive", ( name, instructions, instructionsLang, prompts, finish ) =>
         @.emit 'info', "#{@host.server.host}: Class.keyboard-interactive" if @host.debug
         @.emit 'info', "#{@host.server.host}: Keyboard-interactive: 
            finish([response, array]) not called in class event handler." if @host.debug
         if @host.verbose
            @.emit 'info', "name: " + name
            @.emit 'info', "instructions: " + instructions
            str = JSON.stringify(prompts, null, 4)
            @.emit 'info', "Prompts object: " + str
      @host.onKeyboardInteractive name, instructions, instructionsLang, prompts, finish if @host.onKeyboardInteractive

      #terminal output doesn't want a `\n` but process info messages do.
      @.on "msg", @host.msg  ?  ( message ) =>
         process.stdout.write  message
         
      @.on "info", @host.info ?  ( message ) =>
         process.stdout.write  message + @host.enter
         
      @.on "error", @host.onError ? (err, type, close = false, callback) =>
         @.emit 'info', "#{@host.server.host}: Class.error" if @host.debug
         if ( err instanceof Error )
            @.emit 'info', "Error: " + err.message + ", Level: " + err.level
         else
            @.emit 'info', "#{type} error: " + err
            callback(err, type) if callback
            if close 
               @connection.end()

      @.on "pipe", @host.onPipe ? (source) =>
         @.emit 'info', "#{@host.server.host}: Class.pipe" if @host.debug

      @.on "unpipe", @host.onUnpipe ? (source) =>
         @.emit 'info', "#{@host.server.host}: Class.unpipe" if @host.debug 

      @.on "data", @host.onData ? (data) =>
         @.emit 'info', "#{@host.server.host}: data event"  if @host.debug

      @.on "stderrData", @host.onStderrData ? (data) =>
         console.error data

   connect: (callback)=>
      @_callback = callback if callback
      @_initiate()
      @_connect()
    
   _connect: =>
      @connection.on "keyboard-interactive", (name, instructions, instructionsLang, prompts, finish) =>
         @.emit 'info', "#{@host.server.host}: Connection.keyboard-interactive" if @host.debug
         @.emit "keyboard-interactive", name, instructions, instructionsLang, prompts, finish
       
      @connection.on "connect", =>
         @.emit 'info', "#{@host.server.host}: Connection.connect" if @host.debug
         @.emit 'info', @host.connectedMessage

      @connection.on "ready", =>
         @.emit 'info', "#{@host.server.host}: Connection.ready" if @host.debug
         @.emit 'info', @host.readyMessage

         #open a shell
         @connection.shell @host.window, { pty: @host.pty }, (err, @_stream) =>
            if err then @.emit 'error', err, "Shell", true
            @.emit 'info', "#{@host.server.host}: Connection.shell" if @host.debug
            @host.sessionText = "Connected to #{@host.server.host}#{@host.enter}"
            @_stream.setEncoding(@host.streamEncoding);
             
            @_stream.pipe pipe for pipe in @_pipes
            @.unpipe = @_stream.unpipe
         
            @_stream.on "error", (err) =>
               @.emit 'info', "#{@host.server.host}: Stream.error" if @host.debug
               @.emit 'error', err, "Stream"

            @_stream.stderr.on 'data', (data) =>
               @.emit 'info', "#{@host.server.host}: Stream.stderr.data" if @host.debug
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
               @.emit 'info', "#{@host.server.host}: Stream.finish" if @host.debug
               @.emit 'end', @host.sessionText, @host
               @_callback @host.sessionText if @_callback
              
            @_stream.on "close", (code, signal) =>
               @.emit 'info', "#{@host.server.host}: Stream.close" if @host.debug
               @connection.end()
       
      @connection.on "error", (err) =>
         @.emit 'info', "#{@host.server.host}: Connection.error" if @host.debug
         @.emit "error", err, "Connection"
       
      @connection.on "close", (had_error) =>
         @.emit 'info', "#{@host.server.host}: Connection.close" if @host.debug
         if had_error
            @.emit "error", had_error, "Connection close"
         else
            @.emit 'info', @host.closedMessage
         
      if @host.server
         try
            @connection.connect
               host:             @host.server.host
               port:             @host.server.port
               forceIPv4:        @host.server.forceIPv4
               forceIPv6:        @host.server.forceIPv6
               hostHash:         @host.server.hashMethod
               hostVerifier:     @host.server.hostVerifier
               username:         @host.server.userName
               password:         @host.server.password
               agent:            @host.server.agent
               agentForward:     @host.server.agentForward
               privateKey:       @host.server.privateKey
               passphrase:       @host.server.passPhrase
               localHostname:    @host.server.localHostname
               localUsername:    @host.server.localUsername
               tryKeyboard:      @host.server.tryKeyboard
               keepaliveInterval:@host.server.keepaliveInterval
               keepaliveCountMax:@host.server.keepaliveCountMax
               readyTimeout:     @host.server.readyTimeout
               sock:             @host.server.sock
               strictVendor:     @host.server.strictVendor
               algorithms:       @host.server.algorithms
               compress:         @host.server.compress
               debug:            @host.server.debug
         catch e
            @.emit 'error', "#{e} #{e.stack}", "Connection.connect", true
      else
         @.emit 'error', "Missing connection parameters", "Parameters", false, ( err, type, close ) ->
            @.emit 'info', @host.server
            
      return @_stream

  
module.exports = SSH2Shell
