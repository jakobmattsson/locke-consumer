locke-consumer
==============




# createOrReplaceUser:
# * använd userdata för att avgöra var i databasen den nya usern ska in
# * ta bort befintlig data också, om det finns någon

# existsUser:
# * måste vara stateless

# deleteUser:
# * om usern inte finns så ska metoden också lyckas


    var consumer = require('locke-consumer');
    var locke = require('locke-api');



    consumer.create(locke, )

    exports.create = (locke, createOrReplaceUser, existsUser, deleteUser) ->

      create: (app, username, password, data, callback) ->

      del: (app, username, password, callback) ->
