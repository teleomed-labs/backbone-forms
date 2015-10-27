describe 'the Form object', ->

  it 'should prefer options.schema to model.schema', ->

    from_model   = { foo_field: 'Text' }
    from_options = { bar_field: 'Text' }

    m = new (Backbone.Model.extend(schema: from_model))
    f = new Backbone.Form( model: m, schema: from_options)

    f.schema.should.deep.equal from_options


  it 'should allow a schema function', ->

    le_schema = { foo_field: 'Text' }
    fn = -> le_schema

    f = new Backbone.Form(schema: fn)

    f.schema.should.deep.equal fn()


  it 'uses schema from model if provided', ->

    from_model = { foo_field: 'Text' }

    m = new (Backbone.Model.extend(schema: from_model))
    f = new Backbone.Form( model: m)

    f.schema.should.deep.equal from_model

  it 'uses fieldsets from model if provided', ->

    from_model = { foo_field: 'Text' }
    from_fieldsets = [
      { legend: 'foo', fields: ['bar'] }
    ]

    m = new (Backbone.Model.extend(schema: from_model, fieldsets: from_fieldsets))
    f = new Backbone.Form( model: m )

    f.fieldsets[0].schema.should.deep.equal m.fieldsets[0]

  it 'should save important values from options', ->

    options =
      model: new Backbone.Model()
      data: { foo: 1 }
      idPrefix: 'foo'
      templateData: { bar: 2 }

    form = new Backbone.Form(options)

    form.model.should.deep.equal options.model
    form.data.should.deep.equal options.data
    form.idPrefix.should.equal options.idPrefix
    form.templateData.should.deep.equal options.templateData
