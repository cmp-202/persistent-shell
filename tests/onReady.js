//Terminal persistent shell connection.

var persistentShell = require ('../lib/persistent-shell'),
   host = {
      server: {     
         host:         "192.168.0.117",
         port:         "22",
         userName:     "user",
         password:     "jaed1ygd"
      },
      onCommandComplete: function(response){
         if(this.command.indexOf("la") >-1){
            this.exit();
            //and anything else needing to close
         }
      },
      onFirstPrompt: function(){
         this.runCommand("la");
      }
    }

//Create new instance
var session = new persistentShell(host)  

var callback = function( sessionText ){
         this.emit("info", "-----Callback\nSession text:\n\n" + sessionText);
         this.emit("info", "\n\n-----Callback end" );
   }

//Make connection
session.connect(callback)