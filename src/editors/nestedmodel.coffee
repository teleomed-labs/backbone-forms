###*
# NestedModel editor
#
# Creates a child form. For editing nested Backbone models
#
# Special options:
#   schema.model:   Embedded model constructor
###

Form.editors.NestedModel = Form.editors.Object.extend(
  initialize: (options) ->
    Form.editors.Base::initialize.call this, options
    if !@form
      throw new Error('Missing required option "form"')
    if !options.schema.model
      throw new Error('Missing required "schema.model" option for NestedModel editor')
    return
  render: ->
    #Get the constructor for creating the nested form; i.e. the same constructor as used by the parent form
    NestedForm = @form.constructor
    data = @value or {}
    key = @key
    nestedModel = @schema.model
    #Wrap the data in a model if it isn't already a model instance
    modelInstance = if data.constructor == nestedModel then data else new nestedModel(data)
    @nestedForm = new NestedForm(
      model: modelInstance
      idPrefix: @id + '_'
      fieldTemplate: 'nestedField')
    @_observeFormEvents()
    #Render form
    @$el.html @nestedForm.render().el
    if @hasFocus
      @trigger 'blur', this
    this
  commit: ->
    error = @nestedForm.commit()
    if error
      @$el.addClass 'error'
      return error
    Form.editors.Object::commit.call this
)
