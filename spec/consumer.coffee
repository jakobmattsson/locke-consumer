_ = require 'underscore'
should = require 'should'
assert = require 'assert'
sinon = require 'sinon'
lockeApi = require 'locke-api'
mem = require 'locke-store-mem'
consumer = require('./setup').requireSource('consumer')


sass = sinon.assert
stub = sinon.stub


db = mem.factory()
lockeProxy = lockeApi.constructApi
  db: db
  emailClient: {}



noErr = (callback) ->
  (err, args...) ->
    assert(!err, "Expected no error, but got #{err}")
    callback(args...) if callback

withErr = (callback) ->
  (err, args...) ->
    assert(err, 'Expected an error, but got none')
    callback(args...) if callback


spyApi = (api) ->
  _.object _.pairs(api).map ([name, func]) ->
    [name, sinon.spy(func)]



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
# * You can't demand the user to be created fully from just an email and a password. It's possible that it should belong to a particular account or similar.

describe "consumer", ->

  beforeEach(db.clean)


  it "should have the right methods", ->
    api = consumer.construct
      locke: lockeProxy
      createUser: stub().yields()
      existsUser: stub().yields()
      deleteUser: stub().yields()
    api.should.have.keys ['create', 'del', 'createLocal', 'delLocal']


  [true, false].forEach (uStatus) ->
    it "should allow creation of a user (with userStatus #{uStatus})", (done) ->
      app =
        createUser: stub().yields()
        existsUser: stub().yields(null, uStatus)
        deleteUser: stub().yields()

      proxy = spyApi(lockeProxy)
      api = consumer.construct(_.extend({ locke: proxy }, app))

      api.create 'locke', 'user@name.com', 'apqqwerty', { account: 2 }, noErr ->
        sass.calledWith app.createUser, 'user@name.com', { account: 2 }
        sass.calledWith proxy.createUser, 'locke', 'user@name.com', 'apqqwerty'
        done()


  [true, false].forEach (uStatus) ->
    it "should not create a locke user if the local creation fails (with userStatus #{uStatus})", (done) ->
      app =
        createUser: stub().yields(new Error("failure"))
        existsUser: stub().yields(null, uStatus)
        deleteUser: stub().yields()

      proxy = spyApi(lockeProxy)
      api = consumer.construct(_.extend({ locke: proxy }, app))

      api.create 'locke', 'user@name.com', 'apqqwerty', { account: 2 }, withErr ->
        sass.calledWith app.createUser, 'user@name.com', { account: 2 }
        sass.notCalled proxy.createUser
        done()


  # This case exists because the user can have been created at locke.com
  # It should still be possible to sign up on the app, even though this is the case.
  [true, false].forEach (uStatus) ->
    it "should not even attempt to create the user locally if the user already exists and the password is wrong (with userStatus #{uStatus})", (done) ->

      lockeProxy.createUser 'locke', 'already@user.com', 'foobar', noErr ->
        app =
          createUser: stub().yields()
          existsUser: stub().yields(null, uStatus)
          deleteUser: stub().yields()

        proxy = spyApi(lockeProxy)
        api = consumer.construct(_.extend({ locke: proxy }, app))

        api.create 'locke', 'already@user.com', 'apqqwerty', { account: 2 }, (err) ->
          assert.equal err?.message, 'Incorrect password'
          sass.notCalled proxy.createUser
          sass.notCalled app.createUser
          done()


  it "should create a new user if only locke contains the given one and the password is correct", (done) ->

    lockeProxy.createUser 'locke', 'already@user.com', 'foobar', noErr ->

      app =
        createUser: stub().yields()
        existsUser: stub().yields(null, false)
        deleteUser: stub().yields()

      proxy = spyApi(lockeProxy)
      api = consumer.construct(_.extend({ locke: proxy }, app))

      api.create 'locke', 'already@user.com', 'foobar', { account: 2 }, noErr ->
        sass.notCalled proxy.createUser
        sass.calledWith app.createUser, 'already@user.com', { account: 2 }
        done()


  it "should not override an existing user by creating a new one", (done) ->

    lockeProxy.createUser 'locke', 'already@user.com', 'foobar', noErr ->

      app =
        createUser: stub().yields()
        existsUser: stub().yields(null, true)
        deleteUser: stub().yields()

      proxy = spyApi(lockeProxy)
      api = consumer.construct(_.extend({ locke: proxy }, app))

      api.create 'locke', 'already@user.com', 'foobar', { account: 2 }, (err) ->
        assert.equal err?.message, 'User already exists'
        sass.notCalled proxy.createUser
        sass.notCalled app.createUser
        done()


  [true, false].forEach (uStatus) ->
    it "should raise an error if a non-existing user is deleted (with userStatus #{uStatus})", (done) ->

      app =
        createUser: stub().yields()
        existsUser: stub().yields(null, uStatus)
        deleteUser: stub().yields()

      proxy = spyApi(lockeProxy)
      api = consumer.construct(_.extend({ locke: proxy }, app))

      api.del 'locke', 'myname@user.com', 'foobar', (err) ->
        assert.equal err?.message, "There is no user with the email 'myname@user.com' for the app 'locke'"
        sass.calledWith proxy.deleteUser, 'locke', 'myname@user.com', 'foobar'
        sass.notCalled app.deleteUser
        done()


  [true, false].forEach (uStatus) ->
    it "should delete the locke-user if there is one (with userStatus #{uStatus})", (done) ->

      lockeProxy.createUser 'locke', 'name@user.com', 'foobar', noErr ->

        app =
          createUser: stub().yields()
          existsUser: stub().yields(null, uStatus)
          deleteUser: stub().yields()

        proxy = spyApi(lockeProxy)
        api = consumer.construct(_.extend({ locke: proxy }, app))

        api.del 'locke', 'name@user.com', 'foobar', noErr ->
          sass.calledWith proxy.deleteUser, 'locke', 'name@user.com', 'foobar'
          sass.calledWith app.deleteUser, 'name@user.com'
          done()


  it "should not delete the user from the app, if the locke-deletion fails", (done) ->

    lockeProxy.createUser 'locke', 'name@user.com', 'foobar', noErr ->

      app =
        createUser: stub().yields()
        existsUser: stub().yields(null, true)
        deleteUser: stub().yields()

      proxy = spyApi(lockeProxy)
      proxy.deleteUser = stub().yields(new Error("epic fail"))
      api = consumer.construct(_.extend({ locke: proxy }, app))

      api.del 'locke', 'name@user.com', 'foobar', (err) ->
        assert.equal err?.message, 'epic fail'
        sass.calledWith proxy.deleteUser, 'locke', 'name@user.com', 'foobar'
        sass.notCalled app.deleteUser
        done()


  it "should halt on transport errors in the locke api", (done) ->

    proxy = spyApi(lockeProxy)
    proxy.authPassword = stub().yields(new Error('Some transport error'))

    api = consumer.construct
      locke: proxy
      createUser: stub().yields()
      existsUser: stub().yields(null, true)
      deleteUser: stub().yields()

    api.create 'locke', 'name@user.com', 'foobar', {}, (err) ->
      assert.equal err?.message, 'Some transport error'
      sass.notCalled proxy.createUser
      done()


  it "should halt on incorrect passwords in the locke api", (done) ->

    app =
      createUser: stub().yields()
      existsUser: stub().yields(null, true)
      deleteUser: stub().yields()

    proxy = spyApi(lockeProxy)
    proxy.authPassword = stub().yields(new Error('Incorrect password'))

    api = consumer.construct(_.extend({ locke: proxy }, app))

    api.create 'locke', 'name@user.com', 'foobar', {}, (err) ->
      assert.equal err?.message, 'Incorrect password'
      sass.notCalled proxy.createUser
      sass.notCalled app.createUser
      done()



describe 'Local variations', ->

  beforeEach(db.clean)


  it "should fail to create a local user if the user does not exist in locke", (done) ->

    app =
      createUser: stub().yields()
      existsUser: stub().yields(null, false)
      deleteUser: stub().yields()

    proxy = spyApi(lockeProxy)
    api = consumer.construct(_.extend({ locke: proxy }, app))

    api.createLocal 'locke', 'name@user.com', 'invalid-token', {}, (err) ->
      assert.equal err?.message, "There is no user with the email 'name@user.com' for the app 'locke'"
      sass.notCalled proxy.createUser
      sass.notCalled app.createUser
      done()


  it "should fail to create a local user if existsUser yields an error", (done) ->

    app =
      createUser: stub().yields()
      existsUser: stub().yields(new Error("doh"))
      deleteUser: stub().yields()

    proxy = spyApi(lockeProxy)
    api = consumer.construct(_.extend({ locke: proxy }, app))

    lockeProxy.createUser 'locke', 'name@user.com', 'foobar', noErr ->
      lockeProxy.authPassword 'locke', 'name@user.com', 'foobar', 1000, noErr (data) ->
        api.createLocal 'locke', 'name@user.com', data.token, {}, (err) ->
          assert.equal err?.message, 'doh'
          sass.notCalled proxy.createUser
          sass.notCalled app.createUser
          done()


  it "should fail to create a local user if existsUser yields true", (done) ->

    app =
      createUser: stub().yields()
      existsUser: stub().yields(null, true)
      deleteUser: stub().yields()

    proxy = spyApi(lockeProxy)
    api = consumer.construct(_.extend({ locke: proxy }, app))

    lockeProxy.createUser 'locke', 'name@user.com', 'foobar', noErr ->
      lockeProxy.authPassword 'locke', 'name@user.com', 'foobar', 1000, noErr (data) ->
        api.createLocal 'locke', 'name@user.com', data.token, {}, (err) ->
          assert.equal err?.message, 'User already exists'
          sass.notCalled proxy.createUser
          sass.notCalled app.createUser
          done()


  it "should succeed if existsUser yields false", (done) ->

    app =
      createUser: stub().yields()
      existsUser: stub().yields(null, false)
      deleteUser: stub().yields()

    proxy = spyApi(lockeProxy)
    api = consumer.construct(_.extend({ locke: proxy }, app))

    lockeProxy.createUser 'locke', 'name@user.com', 'foobar', noErr ->
      lockeProxy.authPassword 'locke', 'name@user.com', 'foobar', 1000, noErr (data) ->
        api.createLocal 'locke', 'name@user.com', data.token, { info: 1 }, noErr ->
          sass.notCalled proxy.createUser
          sass.calledWith app.createUser, 'name@user.com', { info: 1 }
          done()



  it "should not be possible to remote delete a user if it exists in locke", (done) ->

    app =
      createUser: stub().yields()
      existsUser: stub().yields(null, false)
      deleteUser: stub().yields()

    proxy = spyApi(lockeProxy)
    api = consumer.construct(_.extend({ locke: proxy }, app))

    lockeProxy.createUser 'locke', 'name@user.com', 'foobar', noErr ->
      api.delLocal 'locke', 'name@user.com', (err) ->
        assert.equal err?.message, 'User has not been deleted in locke'
        sass.notCalled proxy.deleteUser
        done()


  it "should be possible to remote delete a user if it does not exist in locke", (done) ->

    app =
      createUser: stub().yields()
      existsUser: stub().yields(null, true)
      deleteUser: stub().yields()

    proxy = spyApi(lockeProxy)
    api = consumer.construct(_.extend({ locke: proxy }, app))

    api.delLocal 'locke', 'name@user.com', noErr ->
      sass.calledWith app.deleteUser, 'name@user.com'
      done()
