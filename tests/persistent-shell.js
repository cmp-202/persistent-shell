var host = {
  server: {     
    host:         "192.168.0.117",
    port:         "22",
    userName:     "user",
    password:     "jaed1ygd"
  },
  debug:          false,
  verbose:        false
};

host.command = ""
//var SSH2Shell = require ('ssh2shell');
var SSH2Shell = require ('../lib/persistent-shell');

//run the commands in the shell session
var SSH = new SSH2Shell(host),
    callback = function( sessionText ){
          console.log ( "-----Callback session text:\n" + sessionText);
          console.log ( "-----Callback end" );
      }

SSH.connect(callback)