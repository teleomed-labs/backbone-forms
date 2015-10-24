Backbone.Form.prototype.greeting = -> 'Hello World!'

describe 'the Form object', ->
  it 'should say hello', ->
    f = new Backbone.Form()
    f.greeting().should.equal 'Hello World!'

describe 'a failing test', ->
  it 'should fail', ->
    (true).should.equal false
