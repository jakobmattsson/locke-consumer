propagate = (callback, f) ->
  (err, rest...) ->
    return callback(err) if err?
    f(rest...)



exports.create = ({ locke, createOrReplaceUser, existsUser, deleteUser }) ->

  create: (app, username, password, data, callback) ->
    locke.authPassword app, username, password, 1, (err) -> # would be even better if no token was generated
      if err?
        return callback(err) if err.message != "There is no user with the email '#{username}' for the app '#{app}'"
        createOrReplaceUser username, data, propagate callback, ->
          locke.createUser(app, username, password, callback)
      else
        existsUser username, propagate callback, (exist) ->
          return callback(new Error('User already exists')) if exist
          createOrReplaceUser(username, data, callback)

  del: (app, username, password, callback) ->
    locke.deleteUser app, username, password, propagate callback, ->
      deleteUser(username, callback)
