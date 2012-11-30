consumer = require('./setup').requireSource('consumer')

it "should have the right methods", ->
  api = consumer.create()
  api.should.have.keys [
    'create'
    'del'
  ]
