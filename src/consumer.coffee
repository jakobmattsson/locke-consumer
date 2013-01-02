propagate = (callback, f) ->
  (err, rest...) ->
    return callback(err) if err?
    f(rest...)



exports.construct = ({ locke, createUser, existsUser, deleteUser }) ->

  create: (app, username, password, data, callback) ->
    locke.authPassword app, username, password, 1, (err) -> # would be even better if no token was generated
      return callback(err) if err? && err.message != "There is no user with the email '#{username}' for the app '#{app}'"

      create = -> createUser username, data, propagate callback, ->
        locke.createUser(app, username, password, callback)

      existsUser username, propagate callback, (exist) ->
        if err?
          if exist
            deleteUser(username, propagate callback, create)
          else
            create()
        else
          return callback(new Error('User already exists')) if exist
          createUser(username, data, callback)

  del: (app, username, password, callback) ->
    locke.deleteUser app, username, password, propagate callback, ->
      deleteUser(username, callback)
