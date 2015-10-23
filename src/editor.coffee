###*
# Base editor (interface). To be extended, not used directly
#
# @param {Object} options
# @param {String} [options.id]         Editor ID
# @param {Model} [options.model]       Use instead of value, and use commit()
# @param {String} [options.key]        The model attribute key. Required when using 'model'
# @param {Mixed} [options.value]       When not using a model. If neither provided, defaultValue will be used
# @param {Object} [options.schema]     Field schema; may be required by some editors
# @param {Object} [options.validators] Validators; falls back to those stored on schema
# @param {Object} [options.form]       The form
###

Form.Editor = Form.editors.Base = Backbone.View.extend(
  defaultValue: null
  hasFocus: false
  initialize: (options) ->
    `var options`
    options = options or {}
    #Set initial value
    if options.model
      if !options.key
        throw new Error('Missing option: \'key\'')
      @model = options.model
      @value = @model.get(options.key)
    else if options.value != undefined
      @value = options.value
    if @value == undefined
      @value = @defaultValue
    #Store important data
    _.extend this, _.pick(options, 'key', 'form')
    schema = @schema = options.schema or {}
    @validators = options.validators or schema.validators
    #Main attributes
    @$el.attr 'id', @id
    @$el.attr 'name', @getName()
    if schema.editorClass
      @$el.addClass schema.editorClass
    if schema.editorAttrs
      @$el.attr schema.editorAttrs
    return
  getName: ->
    key = @key or ''
    #Replace periods with underscores (e.g. for when using paths)
    key.replace /\./g, '_'
  getValue: ->
    @value
  setValue: (value) ->
    @value = value
    return
  focus: ->
    throw new Error('Not implemented')
    return
  blur: ->
    throw new Error('Not implemented')
    return
  commit: (options) ->
    error = @validate()
    if error
      return error
    @listenTo @model, 'invalid', (model, e) ->
      error = e
      return
    @model.set @key, @getValue(), options
    if error
      return error
    return
  validate: ->
    $el = @$el
    error = null
    value = @getValue()
    formValues = if @form then @form.getValue() else {}
    validators = @validators
    getValidator = @getValidator
    if validators
      #Run through validators until an error is found
      _.every validators, (validator) ->
        error = getValidator(validator)(value, formValues)
        if error then false else true
    error
  trigger: (event) ->
    if event == 'focus'
      @hasFocus = true
    else if event == 'blur'
      @hasFocus = false
    Backbone.View::trigger.apply this, arguments
  getValidator: (validator) ->
    validators = Form.validators
    #Convert regular expressions to validators
    if _.isRegExp(validator)
      return validators.regexp(regexp: validator)
    #Use a built-in validator if given a string
    if _.isString(validator)
      if !validators[validator]
        throw new Error('Validator "' + validator + '" not found')
      return validators[validator]()
    #Functions can be used directly
    if _.isFunction(validator)
      return validator
    #Use a customised built-in validator if given an object
    if _.isObject(validator) and validator.type
      config = validator
      return validators[config.type](config)
    #Unkown validator type
    throw new Error('Invalid validator: ' + validator)
    return
)
