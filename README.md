locke-consumer [![Build Status](https://secure.travis-ci.org/jakobmattsson/locke-consumer.png)](http://travis-ci.org/jakobmattsson/locke-consumer)
==============

A toolkit for unifying user creation/deletion for apps using locke for authentication.



Installation
------------

`npm install locke-consumer`



Constructing the locke consumer
-------------------------------

This example assumes there is a locke-reference called `locke` and some kind of sql-interface called `sql`. Also, Bobby Tables disproves of the simplistic practices used here.

```javascript

var consumer = require('locke-consumer');

var users = consumer.construct({

  // Give the consumer a reference to a locke-api
  locke: locke,

  // This function should create a user with the given username and meta data and then invoke the callback.
  // The callback doesn't take any arguments, except for an error (if there is one).
  // Note: there is no need to check if the username if available; it has already been ensured.
  createUser: function(username, userdata, callback) {
    var values = ["'" + username + "'", userdata.accountId, userdata.isAdmin].join(', ');
    sql.query('INSERT INTO users(name, account, admin) VALUES (' + values + ')', function(err) {
      callback(err);
    });
  },

  // This function should yield a boolean stating whether or not the given user exists.
  // The function should not manipulate any state.
  existsUser: function(username, callback) {
    sql.query("SELECT COUNT(*) FROM users WHERE users.name = '" + username + "'", function(err, result) {
      callback(err, result > 0);
    });
  },

  // This function should delete the given user and then invoke the callback.
  // The callback doesn't take any arguments, except for an error (if there is one).
  // Note: attempting to delete a non-existing user should NOT be an error.
  deleteUser: function(username, callback) {
    sql.query("DELETE users WHERE users.name = '" + username + "'", function(err) {
      callback(err);
    });
  }
});

```



Creating and deleting users
---------------------------

```javascript

users.create('myapp', 'jakob@leanmachine.se', 'foobar', { meta: 'data', anything: 'goes' }, function(err) {
  // User was created if err is undefined
});

users.del('myapp', 'rick@astley', 'foobar', function(err) {
  // User was deleted if err is undefined
});

```



Creating and deleting users locally
-----------------------------------

This way of creating/deleting users prevent this particular interface from ever accessing the plain text password.

Typical usage would be to have a client-side script create/delete the locke-user and then invoke these methods server-side.

Note that the function `createLocal` requires a token as arguments, which can be produced by calling `locke.authPassword` (on the client, or similar).

```javascript

users.createLocal('myapp', 'jakob@leanmachine.se', 'TOKEN', { meta: 'data', anything: 'goes' }, function(err) {
  // User was created if err is undefined
});

users.delLocal('myapp', 'rick@astley', function(err) {
  // User was deleted if err is undefined
});

```



ToDo
----
* Invoking `authPassword` should not generate a token; it should just check if the password is correct.
* When using the "local" functions, should they be complemented by some client-side functions for the locke-interaction?
* Should there also be utility functions for creating indirect users (with other user ids than emails)
