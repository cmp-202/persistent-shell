//Terminal persistent shell connection automated.

var dotenv = require('dotenv');
dotenv.load();

var persistentShell = require ('../lib/persistent-shell'),
   host = {
      server:             {     
         host:         process.env.HOST,
         port:         process.env.PORT,
         userName:     process.env.USER_NAME,
         password:     process.env.PASSWORD
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
   },
   session = new persistentShell(host),
   callback = function( sessionText ){
         this.emit("info", "-----Callback\nSession text:\n\n" + sessionText);
         this.emit("info", "\n\n-----Callback end" );
   }

//Make connection
session.connect(callback)