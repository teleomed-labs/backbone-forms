#==================================================================================================
#FIELDSET
#==================================================================================================
Form.Fieldset = Backbone.View.extend({
  initialize: (options) ->
    options = options or {}
    #Create the full fieldset schema, merging defaults etc.
    schema = @schema = @createSchema(options.schema)
    #Store the fields for this fieldset
    @fields = _.pick(options.fields, schema.fields)
    #Override defaults
    @template = options.template or schema.template or @template or @constructor.template
    return
  createSchema: (schema) ->
    #Normalise to object
    if _.isArray(schema)
      schema = fields: schema
    #Add null legend to prevent template error
    schema.legend = schema.legend or null
    schema
  getFieldAt: (index) ->
    key = @schema.fields[index]
    @fields[key]
  templateData: ->
    @schema
  render: ->
    schema = @schema
    fields = @fields
    $ = Backbone.$
    #Render fieldset
    $fieldset = $($.trim(@template(_.result(this, 'templateData'))))
    #Render fields
    $fieldset.find('[data-fields]').add($fieldset).each (i, el) ->
      $container = $(el)
      selection = $container.attr('data-fields')
      if _.isUndefined(selection)
        return
      _.each fields, (field) ->
        $container.append field.render().el
        return
      return
    @setElement $fieldset
    this
  remove: ->
    _.each @fields, (field) ->
      field.remove()
      return
    Backbone.View::remove.call this
    return

}, template: _.template('    <fieldset data-fields>      <% if (legend) { %>        <legend><%= legend %></legend>      <% } %>    </fieldset>  ', null, Form.templateSettings))
