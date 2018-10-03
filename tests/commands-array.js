//Persistent shell connection with automated commands and terminal.

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

//Handle ctrl-c to terminate the running command on the host
process.on('SIGINT', function() {session.runCommand('\x03')});

//Make connection
session.connect(); 