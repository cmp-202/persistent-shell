persistent-shell
=========

_Wrapper class for [ssh2](https://www.npmjs.org/package/ssh2) client.shell command._

The package allows for user/program/interface to run commands without disconnecting each time.

 
Installation:
------------
```
npm install persistent-shell
```

API
---

#### Properties:

__`this.host`__ Is the host object passed to the constructor.

__`this.commands`__ (Optional) is array of commands.

Commands are set using `host.commands = [commands]` or `this.runCommand([commands])`.


#### Functions:

__`Instance = new persistent-shell(host)`__ requires the host object defined above.

__`this.connect(callback)`__ Connects using host.server properties running the callback when finished. Callback is optional.

__`this.runCommand(command/s)`__ takes a command or an array of commands. Runs command or first command in array.

__`callback = function(sessionText){}`__ Runs after everything has closed allowing you to process the full session.


#### Event Handlers: (All optional)

__`this.on("pipe",function(writeStream){})`__ Allows you to bind a write stream to the shell stream.

__`this.on("unpipe", function(writeStream){})`__ Runs when a pipe is removed.

__`this.on("data", function(data){})`__ Runs every time data is received from the host.

__`this.on("commandProcessing", function(response){})`__ Runs with each data event before a prompt is detected.

__`this.on("commandComplete", function(response){})`__ Runs when a prompt is detected after a command.

__`this.on("lastCommand", function(message){})`__ Indicates there are no commands in the commands array.

__`this.on("end", function (sessionText){})`__ Runs when the stream/connection is being closed.

__`this.on("msg", function(message){})`__ Output a message but with no carrage return.

__`this.on("info", function(message){})`__ Emits msg with carrage return. `Host.onInfo` is not available modify msg instead.

__`this.on("error", function(err, type, close = false, callback){})`__ Runs when an error occures.

__`this.on("keyboard-interactive", function(name, instructions, instructionsLang, prompts, finish){})`__ 
Keyboard-interactive authentication requires host.server.tryKeyboard to be set.


Host Configuration:
------------

Persistent-shell expects an object with the following structure to be passed to its constructor:

__*Note:* Any property or event handler with a default value does not need to be added
to your host object unless you want to change it.__


```javascript

host = {
   server:              {
      host:         "IP Address",
      port:         "external port number",
      userName:     "user name",
      password:     "user password",
      passPhrase:   "privateKeyPassphrase",
      privateKey:   require('fs').readFileSync('/path/to/private/key/id_rsa')    
      //Optional: ssh2.connect config parameters
      //See https://github.com/mscdex/ssh2#client-methods
   },   
   commands:            [],
   standardPrompt:      ">$%#",
   passwordPrompt:      ":",
   passphrasePrompt:    ":",
   showBanner:          false,
   window:              false, //https://github.com/mscdex/ssh2#pseudo-tty-settings use {cols:200}
   enter:               "\n",
   streamEncoding:      "utf8",
   asciiFilter:         "[^\r\n\x20-\x7e]", 
   disableColorFilter:  false, 
   textColorFilter:     "(\[{1}[0-9;]+m{1})", 
   msg:                 function( message ) { process.stdout.write(message)},
   verbose:             false,  
   debug:               false,  
   connectedMessage:    "Connected",
   readyMessage:        "Ready",
   closedMessage:       "Closed",
   callback:            function( sessionText ){},
   onFirstPrompt:       function() {},
   onData:              function( data ) {},
   onPipe:              function( writable ){},
   onUnpipe:            function( writable ) {},
   onCommandProcessing: function( response ) {},
   onCommandComplete:   function( response ) {},
   onLastCommand:       function( command ) {},
   onEnd:               function( sessionText ) {},
   onError:             function( err, type, close = false, callback ) {},
   onKeyboardInteractive: function(name, instructions, instructionsLang, prompts, finish){}
    
};
```
* Host.server will accept current [SSH2.client.connect parameters](https://github.com/mscdex/ssh2#client-methods).
* Optional host properties or event handlers do not need to be included if you are not changing them.
* Host event handlers completely replace the default event handler definitions in the class when defined.
* The `this` keyword is available within host event handlers to give access to persistent-shell functions and properties.
* `this.host` or host variable passed into a function provides access to all the host config, some instance
  variables.
  
Example:
--------
__Persistent connection using both batch commands on connection and user input via the terminal__

```javascript
var persistent-shell = require (persistent-shell),
   commands = ["cd /home", "la", "cd user", "la", "ifconfig"],
   host = {
      server: {     
         host:         "192.168.0.1",
         port:         "22",
         userName:     "user",
         password:     "password"
      },      
      //Commands can be set here or when using .runCommand(command/s).
      commands:       commands,
      
      //First prompt detected and the stream is ready.
      onFirstPrompt:    function(){
         this.stdin = process.openStdin();         
         var self = this;
         
         //Receive stdin data
         this.stdin.addListener("data", function(data){
            var command = data.toString().trim();
            if (command == "exit"){
               self.stdin.end();
               self.exit();
            }else {
               self.runCommand(command);
            }
         })
      }
   },
   session = new persistentShell(host);

//Handle ctrl-c to terminate the running command on the host
process.on('SIGINT', function() {session.runCommand('\x03')});

//Make connection
session.connect();
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
* There is an optional debug setting in the host object that will output process information when set to true.
  - `host.debug = true`


Verbose and Debug:
------------------
* When `host.verbose = true` outputs each commands response.
* When `host.debug = true` outputs each process step.

  
Authentication:
---------------
* When using key authentication you may require a valid pass phrase if your key was created with one.
* When using fingerprint validation both host.server.hashMethod property and host.server.hostVerifier function must be
  set.
* When using keyboard-interactive authentication both `host.server.tryKeyboard` and `instance.on ("keayboard-interactive",
  function...)` or `host.onKeyboardInteractive()` must be defined.
* Set the default cyphers and keys.


Default Cyphers:
---------------
Default Cyphers and Keys used in the initial ssh connection can be redefined by setting the ssh2.connect.algorithms through the host.server.algorithms option. 

As with this property all `ssh2.connect properties` are set in the `host.server` object.

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
        //hostVerifier function must be defined and return true for match or false for failure.
        hostVerifier: function(hashedKey) {
            var recievedHash,            
               expectedHash = expectedHash + "".replace(/[:]/g, "").toLowerCase(),
               recievedHash = hashedKey + "".replace(/[:]/g, "").toLowerCase();
            
            if (expectedHash === "") {
              //No expected hash so save what was received from the host (hashedKey)
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
keyboard-interactive is defined as below. 

The keyboard-interactive event handler can only be used on the first connection.

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

