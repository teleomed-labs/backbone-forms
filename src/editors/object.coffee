###*
# Object editor
#
# Creates a child form. For editing Javascript objects
#
# @param {Object} options
# @param {Form} options.form                 The form this editor belongs to; used to determine the constructor for the nested form
# @param {Object} options.schema             The schema for the object
# @param {Object} options.schema.subSchema   The schema for the nested form
###

Form.editors.Object = Form.editors.Base.extend(
  hasNestedForm: true
  initialize: (options) ->
    #Set default value for the instance so it's not a shared object
    @value = {}
    #Init
    Form.editors.Base::initialize.call this, options
    #Check required options
    if !@form
      throw new Error('Missing required option "form"')
    if !@schema.subSchema
      throw new Error('Missing required \'schema.subSchema\' option for Object editor')
    return
  render: ->
    #Get the constructor for creating the nested form; i.e. the same constructor as used by the parent form
    NestedForm = @form.constructor
    #Create the nested form
    @nestedForm = new NestedForm(
      schema: @schema.subSchema
      data: @value
      idPrefix: @id + '_'
      Field: NestedForm.NestedField)
    @_observeFormEvents()
    @$el.html @nestedForm.render().el
    if @hasFocus
      @trigger 'blur', this
    this
  getValue: ->
    if @nestedForm
      return @nestedForm.getValue()
    @value
  setValue: (value) ->
    @value = value
    @render()
    return
  focus: ->
    if @hasFocus
      return
    @nestedForm.focus()
    return
  blur: ->
    if !@hasFocus
      return
    @nestedForm.blur()
    return
  remove: ->
    @nestedForm.remove()
    Backbone.View::remove.call this
    return
  validate: ->
    errors = _.extend({}, Form.editors.Base::validate.call(this), @nestedForm.validate())
    if _.isEmpty(errors) then false else errors
  _observeFormEvents: ->
    if !@nestedForm
      return
    @nestedForm.on 'all', (->
      # args = ["key:change", form, fieldEditor]
      args = _.toArray(arguments)
      args[1] = this
      # args = ["key:change", this=objectEditor, fieldEditor]
      @trigger.apply this, args
      return
    ), this
    return
)
