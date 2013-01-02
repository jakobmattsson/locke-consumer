_ = require 'underscore'
should = require 'should'
sinon = require 'sinon'
lockeApi = require 'locke-api'
mem = require 'locke-store-mem'
consumer = require('./setup').requireSource('consumer')


db = mem.factory()
lockeProxy = lockeApi.constructApi
  db: db
  emailClient: {}



deletionCallbackOK = (username, callback) -> callback()
deletionCallbackFail = (username, callback) -> callback(new Error("failure"))
creationCallbackOK = (username, userdata, callback) -> callback()
creationCallbackFail = (username, userdata, callback) -> callback(new Error("failure"))
userStatus = (status) -> (username, callback) -> callback((if status instanceof Error then status), status)



noErr = (cb) ->
  (err, args...) ->
    should.not.exist err
    cb(args...) if cb

spyApi = (api) -> _.object _.pairs(api).map ([name, func]) -> [name, sinon.spy(func)]


describe "consumer", ->

  beforeEach(db.clean)


  it "should have the right methods", ->
    api = consumer.create({ locke: lockeProxy, createOrReplaceUser: creationCallbackOK, deleteUser: deletionCallbackOK })
    api.should.have.keys ['create', 'del']


  [true, false].forEach (uStatus) ->
    it "should allow creation of a user (with userStatus #{uStatus})", (done) ->
      creation = sinon.spy(creationCallbackOK)
      proxy = spyApi(lockeProxy)
      api = consumer.create
        locke: proxy
        createOrReplaceUser: creation
        existsUser: userStatus(uStatus)
        deleteUser: deletionCallbackOK

      api.create 'locke', 'user@name.com', 'apqqwerty', { account: 2 }, noErr ->
        should creation.calledWith('user@name.com', { account: 2 })
        should proxy.createUser.calledWith('locke', 'user@name.com', 'apqqwerty'), 'hejsan'
        done()


  [true, false].forEach (uStatus) ->
    it "should not create a locke user if the local creation fails (with userStatus #{uStatus})", (done) ->
      creation = sinon.spy(creationCallbackFail)
      proxy = spyApi(lockeProxy)
      api = consumer.create
        locke: proxy
        createOrReplaceUser: creation
        existsUser: userStatus(uStatus)
        deleteUser: deletionCallbackOK

      api.create 'locke', 'user@name.com', 'apqqwerty', { account: 2 }, (err) ->
        should.exist err
        should creation.calledWith('user@name.com', { account: 2 })
        proxy.createUser.callCount.should.eql 0
        done()


  # This case exists because the user can have been created at locke.com
  # It should still be possible to sign up on the app, even though this is the case.
  [true, false].forEach (uStatus) ->
    it "should not even attempt to create the user locally if the user already exists and the password is wrong (with userStatus #{uStatus})", (done) ->

      lockeProxy.createUser 'locke', 'already@user.com', 'foobar', noErr ->

        creation = sinon.spy(creationCallbackOK)
        proxy = spyApi(lockeProxy)
        api = consumer.create
          locke: proxy
          createOrReplaceUser: creation
          existsUser: userStatus(uStatus)
          deleteUser: deletionCallbackOK

        api.create 'locke', 'already@user.com', 'apqqwerty', { account: 2 }, (err) ->
          err.message.should.eql 'Incorrect password'
          proxy.createUser.callCount.should.eql 0
          creation.callCount.should.eql 0
          done()


  it "should create a new user if only locke contains the given one and the password is correct", (done) ->

    lockeProxy.createUser 'locke', 'already@user.com', 'foobar', noErr ->

      creation = sinon.spy(creationCallbackOK)
      proxy = spyApi(lockeProxy)
      api = consumer.create
        locke: proxy
        createOrReplaceUser: creation
        existsUser: userStatus(false)
        deleteUser: deletionCallbackOK

      api.create 'locke', 'already@user.com', 'foobar', { account: 2 }, noErr ->
        proxy.createUser.callCount.should.eql 0
        creation.callCount.should.eql 1
        done()


  it "should not override an existing user by creating a new one", (done) ->

    lockeProxy.createUser 'locke', 'already@user.com', 'foobar', noErr ->

      creation = sinon.spy(creationCallbackOK)
      proxy = spyApi(lockeProxy)
      api = consumer.create
        locke: proxy
        createOrReplaceUser: creation
        existsUser: userStatus(true)
        deleteUser: deletionCallbackOK

      api.create 'locke', 'already@user.com', 'foobar', { account: 2 }, (err) ->
        err.message.should.eql 'User already exists'
        proxy.createUser.callCount.should.eql 0
        creation.callCount.should.eql 0
        done()


  [true, false].forEach (uStatus) ->
    it "should raise an error if a non-existing user is deleted (with userStatus #{uStatus})", (done) ->

      deletion = sinon.spy(deletionCallbackOK)
      proxy = spyApi(lockeProxy)
      api = consumer.create
        locke: proxy
        createOrReplaceUser: creationCallbackOK
        existsUser: userStatus(uStatus)
        deleteUser: deletion

      api.del 'locke', 'myname@user.com', 'foobar', (err) ->
        err.message.should.eql "There is no user with the email 'myname@user.com' for the app 'locke'"
        proxy.deleteUser.callCount.should.eql 1
        deletion.callCount.should.eql 0
        done()


  [true, false].forEach (uStatus) ->
    it "should delete the locke-user if there is one (with userStatus #{uStatus})", (done) ->

      lockeProxy.createUser 'locke', 'name@user.com', 'foobar', noErr ->

        deletion = sinon.spy(deletionCallbackOK)
        proxy = spyApi(lockeProxy)
        api = consumer.create
          locke: proxy
          createOrReplaceUser: creationCallbackOK
          existsUser: userStatus(uStatus)
          deleteUser: deletion

        api.del 'locke', 'name@user.com', 'foobar', noErr ->
          proxy.deleteUser.callCount.should.eql 1
          deletion.callCount.should.eql 1
          done()


  it "should not delete the user from the app, if the locke-deletion fails", (done) ->

    lockeProxy.createUser 'locke', 'name@user.com', 'foobar', noErr ->

      deletion = sinon.spy(deletionCallbackOK)
      proxy = spyApi(_.extend({}, lockeProxy, { deleteUser: (app, username, password, callback) -> callback(new Error("epic fail")) }))
      api = consumer.create
        locke: proxy
        createOrReplaceUser: creationCallbackOK
        existsUser: userStatus(true)
        deleteUser: deletion

      api.del 'locke', 'name@user.com', 'foobar', (err) ->
        err.message.should.eql 'epic fail'
        proxy.deleteUser.callCount.should.eql 1
        deletion.callCount.should.eql 0
        done()









# Creation:
# * The user doesn't exist at all: Start by creating it in the app, then in Locke.
# * The user exists in Locke: Create the user as usual, but the password must be the same as the one in Locke.
# * The user exists in the app: Act as if the user doesn't exist at all. Delete the exising user and create a new one.
# * The user exists in both: User already exists, can't be created.

# Deletion:
# * The user doesn't exist at all: There i no user. Can't delete.
# * The user exists in Locke: Remove the user from Locke.
# * The user exists in the app: Act as if the user doesn't exist at all. (could use the moment to purge the user from the app)
# * The user exists in both: First delete it from Locke (because that is what indicates its existance). Then delete it from the app, if possible.

# Notes etc:
# * Could create a "purge" function, deleting all users in the app that no longer exists in Locke.
# * You can't demand the user to be created fully from just an email and a password. It's possible that it should belong to a particular account or similar.
