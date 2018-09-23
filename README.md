Persistent-shell
=========

Wrapper class for [ssh2](https://www.npmjs.org/package/ssh2) client.shell command.
 
 
Installation:
------------
```
npm install persistent-shell
```


Minimal Example:
------------
```javascript
//host configuration with connection settings and commands
var host = {
   server:        {     
      host:         "127.0.0.1",
      userName:     "test",
      password:     "1234",
 }
};

var persistent-shell = require ('persistent-shell'),
  //Create a new instance passing in the host object
  shell = new persistent-shell(host),
  
  //Use a callback function to process the full session text
  callback = function(sessionText){
    process.stdout.write(sessionText)
  }

//Start the process
shell.connect(callback);
``` 

persistent-shell API
-------------
persistent-shell extends events.EventEmitter


*Methods*

* .connect(callback(sessionText)) Is the main function to establish the connection. 
   It take in an optional callback function that receives the full session text as its parameter.

* .runCommand ("command") self explanertry.

* .exit() used to close the session.

* .emit("eventName", function, parms,... ). Raises the event based on the name in the first string and takes input
  parameters based on the handler function definition.
  
* .pipe(destination) binds a writable stream to the output of the read stream but only after the connection is established.

* .unpipe(destination) removes piped streams but can only be called after a connection has been made.

*Variables*

* .host is the host object as defined above along with some instance variables.

Host Configuration:
------------

persistent-shell expects an object with the following structure to be passed to its constructor:
```javascript
//Host object
host = {
  server:              { 
    //required connection settings
    host:         "IP Address",
    port:         "external port number",
    userName:     "user name",
    //optional or required settings subject to authentication method used
    password:     "user password",
    passPhrase:   "privateKeyPassphrase",
    privateKey:   require('fs').readFileSync('/path/to/private/key/id_rsa'),
    //Optional: ssh2.connect config parameters
    //See https://github.com/mscdex/ssh2#client-methods
    //ssh2.connect parameters are only valid for the first host connection.
    //Other host connections use the ssh command/s to connect not ssh2.
  },
  //Optional: Characters used in prompt detection
  standardPrompt:     ">$%#",
  passwordPrompt:     ":",
  passphrasePrompt:   ":",
  
  //Optional: exclude or include host banner after connection and window size 
  showBanner:         false,
  window:             false, //https://github.com/mscdex/ssh2#pseudo-tty-settings use {cols:200}
  
  //Optional: Enter key character for end of line.
  enter:              "\n",
  
  //Optional: stream encoding
  streamEncoding:     "utf8",
  
  //Optional: Regular expressions to filter output text
  asciiFilter:        "[^\r\n\x20-\x7e]", //removes non-standard ASCII
  disableColorFilter:  false, //turns colour filtering on and off
  textColorFilter:    "(\[{1}[0-9;]+m{1})", //removes colour formatting codes
  
  //Optional: Used by this.emit("msg", "message") or this.emit("info", "message")
  msg:                function( message ) { process.stdout.write(message)}, 
  info:               function( message ) { process.stdout.write(message + this.host.enter)},
  
  //Optional: Trouble shooting options
  verbose:             false,  //outputs all received content
  debug:               false,  //outputs information about each process step
  
  //Optional: Messages returned on each connection event.
  connectedMessage:    "Connected",
  readyMessage:        "Ready",
  closedMessage:       "Closed",
  
  //Host event handlers 
  
  //Optional: Keyboard interactive authentication event handler
      //This event is only used for the first host connecting through ssh2.connect
      //Required if the first host.server.tryKeyboard is set to true. 
  onKeyboardInteractive: function(name, instructions, instructionsLang, prompts, finish){
    //See https://github.com/mscdex/ssh2#client-events
    //name, instructions, instructionsLang don't seem to be of interest for authenticating
    //prompts is an object of expected prompts and if they are to be shown to the user
    //finish is the function to be called with an array of responses in the same order as 
    //the prompts parameter defined them.
    //See [Client events](https://github.com/mscdex/ssh2#client-events) for more information
    //if a non-standard prompt results from a successful connection then handle its 
  },
  
  //Optional: data is triggered on every stream data event providing the raw stream output 
  onData: function( data ) {
    //data is the string received.
  },
  
  //Optional: The pipe event is raised when readStream.pipe() adds a writeable stream to 
  //receive output
  onPipe: function( source ) {
    //source is the read stream the write stream will receive output from
  }
  
  //Optional: The unpipe event is raised when readStream.unpipe() removes a writeable stream 
  //so it no longer receives output
  onUnpipe: function( source ) {
    //source is the read stream to remove from being able to write its output.
  },
  
  //Optional: Command complete is raised when a standard prompt is detected after a command is sent.
  onCommandComplete:   function( command, response ) {
   //response is the full string from the last command up to the command prompt.
   //host is the host object.
  },
  
  //Optional: The end event is raised when the stream.on ("finish") event is triggered as the 
  //connection is closed. This is where you handle the full session text from the connection.
  onEnd:               function( sessionText ) {
   //SessionText is the full text for this hosts session   
   //host is this host object
  },
    
  //Optional: Run when an error event is raised be it connection or otherwise.
  onError:            function( err, type, close = false, callback ) {
   //err is either an Error object or a string containing the error message
   //type is a string containing the error type
   //close is a Boolean value indicating if the connection should be closed or not
   //callback is the function to run with handling the error in the form of function(err,type)
   //if overwriting the default definition remember to handle closing the connection based on close
   //To close the connection us this.connection.close()
  },
  
  //Optional: callback function definition called when the stream closes
  callback:           function( sessionText ){
    //sessionText is the full session response filtered and notifications added
    //Is overridden by persistent-shell.connect(callback)
  }  
};
```
* Host.server will accept current [SSH2.client.connect parameters](https://github.com/mscdex/ssh2#client-methods).
* Optional host properties or event handlers do not need to be included if you are not changing them.
* Host event handlers completely replace the default event handler definitions in the class when defined.
* The `this` keyword is available within host event handlers to give access to persistent-shell functions and properties.
* `this.host` or host variable passed into a function provides access to all the host config, some instance
  variables.

Usage:
======

```javascript
//Terminal persistent shell connection.

var persistentShell = require('persistent-shell'),
    host = {
      server: {     
        host:         "192.168.0.117",
        port:         "22",
        userName:     "user",
        password:     "jaed1ygd"
      },
      debug:          false,
      verbose:        false,
      stdin:          process.openStdin()
   };

//Create new instance
var session = new persistentShell(host),
   callback = function( sessionText ){
         this.emit("info", "-----Callback\nSession text:\n\n" + sessionText);
         this.emit("info", "\n\n-----Callback end" );
   }
      
//Start console data event handler
session.host.stdin.addListener("data", function(input){
      var command = input.toString().trim();
      if (command == "exit"){
         session.host.stdin.end();
         session.exit();
      }else {
         session.runCommand(command);
      }
})

//Make connection
session.connect(callback);
```

Trouble shooting:
-----------------

* `Error: Unable to parse private key while generating public key (expected sequence)` is caused by the pass phrase
  being incorrect. This confused me because it doesn't indicate the pass phrase was the problem but it does indicate
  that it could not decrypt the private key. 
* Recheck your pass phrase for typos or missing chars.
* Try connecting manually to the host using the exact pass phrase used by the code to confirm it works.
* I did read of people having problems with the pass phrase or password having an \n added when used from an
  external file causing it to fail. They had to add .trim() when setting it.
* If your password is incorrect the connection will return an error.
* There is an optional debug setting in the host object that will output process information when set to true. `host.debug = true`


Verbose and Debug:
------------------
* When host.verbose is set to true each command complete raises a msg event outputting the command response text.
* When host.debug is set to true each process step raises a msg event to help identify what the internal process of
  each step was.

  
Authentication:
---------------
* When using key authentication you may require a valid pass phrase if your key was created with one.
* When using fingerprint validation both host.server.hashMethod property and host.server.hostVerifier function must be
  set.
* When using keyboard-interactive authentication both host.server.tryKeyboard and instance.on ("keayboard-interactive",
  function...) or host.onKeyboardInteractive() must be defined.
* Set the default cyphers and keys.


Default Cyphers:
---------------
Default Cyphers and Keys used in the initial ssh connection can be redefined by setting the ssh2.connect.algorithms through the host.server.algorithms option. 
As with this property all ssh2.connect properties are set in the host.server object.

*Example:*
```javascript
var host = {
    server:        {  
            host:           "<host IP>",
            port:           "22",
            userName:       "<username>",
            password:       "<password>",
            hashMethod:     "md5", //optional "md5" or "sha1" default is "md5"
            //other ssh2.connect options
            algorithms: {
                kex: [
                    'diffie-hellman-group1-sha1',
                    'ecdh-sha2-nistp256',
                    'ecdh-sha2-nistp384',
                    'ecdh-sha2-nistp521',
                    'diffie-hellman-group-exchange-sha256',
                    'diffie-hellman-group14-sha1'],
                cipher: [
                    'aes128-ctr',
                    'aes192-ctr',
                    'aes256-ctr',
                    'aes128-gcm',
                    'aes128-gcm@openssh.com',
                    'aes256-gcm',
                    'aes256-gcm@openssh.com',
                    'aes256-cbc'
                ]
            }

        },
    ......
}
```

Fingerprint Validation:
---------------
At connection time the hash of the server’s public key can be compared with the hash the client had previously recorded
for that server. This stops "man in the middle" attacks where you are redirected to a different server as you connect
to the server you expected to. This hash only changes with a reinstall of SSH, a key change on the server or a load
balancer is now in place. 

__*Note:*
 Fingerprint check doesn't work the same way for tunnelling. The first host will validate using this method but the
 subsequent connections would have to be handled by your commands. Only the first host uses the SSH2 connection method
 that does the validation.__

To use fingerprint validation you first need the server hash string which can be obtained using persistent-shell as follows:
 * Set host.verbose to true then set host.server.hashKey to any non-empty string (say "1234"). 
 * Validation will be checked and fail causing the connection to terminate. 
 * A verbose message will return both the server hash and client hash values that failed comparison. 
 * This is also what will happen if your hash fails the comparison with the server in the normal verification process.
 * Turn on verbose in the host object, run your script with hashKey unset and check the very start of the text returned
     for the servers hash value. 
 * The servers hash value can be saved to a variable outside the host or class so you can access it without having to
   parse response text.

*Example:*
```javascript
//Define the hostValidation function in the host.server config.
//hashKey needs to be defined at the top level if you want to access the server hash at run time
var serverHash, host;

//don't set expectedHash if you want to know the server hash
var expectedHash
expectedHash = "85:19:8a:fb:60:4b:94:13:5c:ea:fe:3b:99:c7:a5:4e";

host = {
    server: {
        //other normal connection params,
        hashMethod:   "md5", //"md5" or "sha1"
        //hostVerifier function must be defined and return true for match of false for failure.
        hostVerifier: function(hashedKey) {
            var recievedHash;
            
            expectedHash = expectedHash + "".replace(/[:]/g, "").toLowerCase();
            recievedHash = hashedKey + "".replace(/[:]/g, "").toLowerCase();
            if (expectedHash === "") {
              //No expected hash so save save what was received from the host (hashedKey)
              //serverHash needs to be defined before host object
              serverHash = hashedKey; 
              console.log("Server hash: " + serverHash);
              return true;
            } else if (recievedHash === expectedHash) {
              console.log("Hash values matched");
              return true;
            }
            //Output the failed comparison to the console if you want to see what went wrong
            console.log("Hash values: Server = " + recievedHash + " <> Client = " + expectedHash);
            return false;
          },
    },
    //Other settings
};

var persistent-shell = require ('persistent-shell'),
    session = new persistent-shell(host);
    
session.connect();
```
__*Note:* 
host.server.hashMethod only supports md5 or sha1 according to the current SSH2 documentation anything else may produce
undesired results.__


Keyboard-interactive
----------------------
Keyboard-interactive authentication is available when both host.server.tryKeyboard is set to true and the event handler
keyboard-interactive is defined as below. The keyboard-interactive event handler can only be used on the first connection.

Also see [test/keyboard-interactivetest.js](https://github.com/cmp-202/persistent-shell/blob/master/test/keyboard-interactivetest.js) for the full example 

*Defining the event handler:*
```javascript
//this is required
host.server.tryKeyboard = true;

var persistent-shell = require ('../lib/persistent-shell');
var session = new persistent-shell(host);
  
//Add the keyboard-interactive handler
//The event function must call finish() with an array of responses in the same order as prompts received
// in the prompts array
session.on ('keyboard-interactive', function(name, instructions, instructionsLang, prompts, finish){
     if (this.host.debug) {this.emit('msg', this.host.server.host + ": Keyboard-interactive");}
     if (this.host.verbose){
       this.emit('msg', "name: " + name);
       this.emit('msg', "instructions: " + instructions);
       var str = JSON.stringify(prompts, null, 4);
       this.emit('msg', "Prompts object: " + str);
     }
     //The example presumes only the password is required
     finish([this.host.server.password] );
  });
  
session.connect();
```

Or

```javascript
host = {
    ...,
    onKeyboardInteractive: function(name, instructions, instructionsLang, prompts, finish){
      if (this.host.debug) {this.emit('msg', this.host.server.host + ": Keyboard-interactive");}
      if (this.host.verbose){
      this.emit('msg', "name: " + name);
      this.emit('msg', "instructions: " + instructions);
      var str = JSON.stringify(prompts, null, 4);
      this.emit('msg', "Prompts object: " + str);
      }
      //The example presumes only the password is required
      finish([this.host.server.password] );
    },
    ...
}
```

