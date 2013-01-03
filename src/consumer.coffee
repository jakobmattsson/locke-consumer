propagate = (callback, f) ->
  (err, rest...) ->
    return callback(err) if err?
    f(rest...)



exports.construct = ({ locke, createUser, existsUser, deleteUser }) ->

  lockeUserExists = (app, username, callback) ->
    locke.authPassword app, username, 'foobar', 1, (err) -> # would be even better if no token was generated
      return callback(null, false) if err? && err.message == "There is no user with the email '#{username}' for the app '#{app}'"
      return callback(err) if err? && err.message != 'Incorrect password'
      callback(null, true)

  lockeTestPassword = (app, username, password, callback) ->
    locke.authPassword(app, username, password, 1, callback)  # would be even better if no token was generated



  create: (app, username, password, data, callback) ->
    create = -> createUser username, data, propagate callback, ->
      locke.createUser(app, username, password, callback)

    lockeUserExists app, username, propagate callback, (existsLocke) ->
      existsUser username, propagate callback, (existLocally) ->
        if !existsLocke
          return deleteUser(username, propagate callback, create) if existLocally
          create()
        else
          lockeTestPassword app, username, password, propagate callback, ->
            return callback(new Error('User already exists')) if existLocally
            createUser(username, data, callback)

  del: (app, username, password, callback) ->
    locke.deleteUser app, username, password, propagate callback, ->
      deleteUser(username, callback)

  createLocal: (app, username, token, data, callback) ->
    locke.authToken app, username, token, propagate callback, ->
      existsUser username, propagate callback, (existLocally) ->
        return callback(new Error('User already exists')) if existLocally
        createUser(username, data, callback)

  delLocal: (app, username, callback) ->
    lockeUserExists app, username, propagate callback, (existsLocke) ->
      return callback(new Error('User has not been deleted in locke')) if existsLocke
      deleteUser(username, callback)
