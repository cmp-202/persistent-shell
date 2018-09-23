//Terminal persistent shell connection.

var persistentShell = require ('../lib/persistent-shell'),
    host = {
      server: {     
        host:         "192.168.0.117",
        port:         "22",
        userName:     "user",
        password:     "jaed1ygd"
      },
      debug:          false,
      verbose:        false,
      stdin:          process.openStdin(),
      onCommandComplete: function(command, response){
         if (command == "echo hi"){
            this.host.commands = ["cd /home", "ifconfig","la"];
            this._nextCommand();
         }
      }
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
session.connect(callback)

