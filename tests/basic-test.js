//Terminal persistent shell connection.

var dotenv = require('dotenv'),
    fs = require('fs');
dotenv.load();

var persistentShell = require ('../lib/persistent-shell'),
   host = {
      server:             {     
         host:         process.env.HOST,
         port:         process.env.PORT,
         userName:     process.env.USER_NAME,
         password:     process.env.PASSWORD
      },
      debug:          false,
      verbose:        false,
      stdin:          process.openStdin()
   },
   session = new persistentShell(host),
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

