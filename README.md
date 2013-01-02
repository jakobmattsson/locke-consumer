locke-consumer
==============

[![Build Status](https://secure.travis-ci.org/jakobmattsson/locke-consumer.png)](http://travis-ci.org/jakobmattsson/locke-consumer)

A toolkit for unifying user creation/deletion for apps using locke for authentication.



Installation
------------

`npm install locke-consumer`



Example
-------

This example assumes there is a locke-reference called `locke` and some kind of sql-interface called `sql`. Also, Bobby Tables disproves of the simplistic practices used here.

    var consumer = require('locke-consumer');

    var users = consumer.construct({

      // Give the consumer a reference to a locke-api
      locke: locke,

      // This function should create a user with the given username and meta data and then invoke the callback.
      // The callback doesn't take any arguments, except for an error (if there is one).
      // Note: there is no need to check if the username if available; it has already been ensured.
      createUser: function(username, userdata, callback) {
        sql.query('INSERT INTO users(name, account, admin) VALUES ("' + username + '", ' + userdata.acount + ', ' + userdata.admin + ')', function(err) {
          callback(err);
        });
      },

      // must be stateless.........................................................
      existsUser: function(username, callback) {
        sql.query('SELECT COUNT(*) FROM users WHERE users.name = ' + username, function(err, result) {
          callback(err, result > 0);
        });
      },

      // This function should delete the given user and then invoke the callback.
      // The callback doesn't take any arguments, except for an error (if there is one).
      // Note: attempting to delete a non-existing user should NOT be an error.
      deleteUser: function(username, callback) {
        sql.query('DELETE users WHERE users.name = ' + username, function(err) {
          callback(err);
        });
      }
    });

    users.create('myapp', 'jakob@leanmachine.se', 'foobar', { meta: 'data', anything: 'goes' }, function(err) {
      // User was created if err is undefined
    });

    users.del('myapp', 'rick@astley', 'foobar', function(err) {
      // User was deleted if err is undefined
    });



ToDo
----
* Invoking `authPassword` should not generate a token; it should just check if the password is correct.
