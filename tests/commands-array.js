//Terminal persistent shell connection.

var dotenv = require('dotenv');
dotenv.load();

var persistentShell = require ('../lib/persistent-shell'),
   commands = ["cd /home", "la", "cd user", "la", "ifconfig"],
   host = {
      server: {     
         host:         process.env.HOST,
         port:         process.env.PORT,
         userName:     process.env.USER_NAME,
         password:     process.env.PASSWORD
      },
      //Commands can be set here or when using .runCommand(command/s).
      commands:       commands,
      
      //First prompt detected and the stream is ready.
      onFirstPrompt:    function(){
         this.stdin = process.openStdin();
         //Receive stdin data
         var self = this;
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

//Make connection
session.connect();